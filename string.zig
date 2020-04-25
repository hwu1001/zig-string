const std = @import("std");
const mem = std.mem;
const ascii = std.ascii;
const Allocator = mem.Allocator;
const Buffer = std.ArrayListSentineled;
const ArrayList = std.ArrayList;
const testing = std.testing;

pub const String = struct {
    buffer: Buffer(u8, 0),

    const Self = String;

    pub const Searcher = enum {
        KnuthMorrisPratt, BoyerMooreHorspool
    };

    pub fn init(allocator: *Allocator, m: []const u8) !String {
        return String{ .buffer = try Buffer(u8, 0).init(allocator, m) };
    }

    pub fn deinit(self: *String) void {
        self.buffer.deinit();
    }

    pub fn startsWith(self: *const String, m: []const u8) bool {
        return self.buffer.startsWith(m);
    }

    pub fn endsWith(self: *const String, m: []const u8) bool {
        return self.buffer.endsWith(m);
    }

    pub fn isEmpty(self: *const String) bool {
        // Can't use Buffer.isNull because Buffer maintains a null byte at the
        // end. (e.g., string of "" in a Buffer is not null)
        return self.buffer.len() == 0;
    }

    pub fn len(self: *const String) usize {
        return self.buffer.len();
    }

    pub fn append(self: *String, m: []const u8) !void {
        try self.buffer.appendSlice(m);
    }

    pub fn eql(self: *const String, m: []const u8) bool {
        return self.buffer.eql(m);
    }

    pub fn reverse(self: *String) void {
        if (self.len() <= 1) {
            return;
        }
        var i: usize = 0;
        var j: usize = self.len() - 1;
        while (i < j) {
            var temp = self.at(i);
            self.buffer.list.items[i] = self.buffer.list.items[j];
            self.buffer.list.items[j] = temp;
            i += 1;
            j -= 1;
        }
    }

    pub fn at(self: *const String, i: usize) u8 {
        return self.buffer.list.items[i];
    }

    /// Caller owns the returned memory
    fn computeLongestPrefixSuffixArray(self: *const String, allocator: *Allocator, pattern: []const u8) ![]usize {
        var m = pattern.len;
        var lps = ArrayList(usize).init(allocator);
        defer lps.deinit();
        var size: usize = 0;
        while (size < m) : (size += 1) {
            try lps.append(0);
        }
        // Left and right positions going through the pattern
        var left: usize = 0;
        var right: usize = 1;
        while (right < m) {
            if (pattern[right] == pattern[left]) {
                lps.items[right] = left + 1;
                left += 1;
                right += 1;
            } else {
                if (left != 0) {
                    left = lps.items[left - 1];
                } else {
                    lps.items[right] = 0;
                    right += 1;
                }
            }
        }
        return lps.toOwnedSlice();
    }

    fn preprocessBcTable(table: []isize, needle: []const u8) !void {
        var j: isize = 0;
        while (j < needle.len) : (j += 1) {
            const a = @intCast(usize, needle[@intCast(usize, j)]);
            table[a] = j;
        }
    }

    fn preprocessGsTable(allocator: *Allocator, table: []usize, haystack: []const u8, needle: []const u8) !void {
        var tmp = try allocator.alloc(usize, needle.len + 1);
        defer allocator.free(tmp);
        {
            var i = needle.len;
            var j = needle.len + 1;
            tmp[i] = j;
            while (i > 0) {
                while (j <= needle.len and (needle[i - 1] != needle[j - 1])) : (j = tmp[j]) {
                    if (table[j] == 0) {
                        table[j] = j - 1;
                    }
                }

                i -= 1;
                j -= 1;
                tmp[i] = j;
            }
        }

        {
            var i: usize = 0;
            var j = tmp[0];

            while (i <= needle.len) : (i += 1) {
                if (table[i] == 0) {
                    table[i] = j;
                }

                if (i == j) {
                    j = tmp[j];
                }
            }
        }
    }

    /// Caller owns the returned memory.
    fn findSubstringIndicesBmh(self: *const String, allocator: *Allocator, needle: []const u8) ![]usize {
        var indices = ArrayList(usize).init(allocator);
        const haystack = self.buffer.list.items[0..self.len()];

        var gs_table = try allocator.alloc(usize, needle.len + 1);
        defer allocator.free(gs_table);
        {
            var i: usize = 0;
            while (i < needle.len + 1) : (i += 1) {
                gs_table[i] = 0;
            }
        }

        var bc_table = [_]isize{-1} ** 256;

        try preprocessBcTable(&bc_table, needle);
        try preprocessGsTable(allocator, gs_table, haystack, needle);

        var i: usize = 0;
        while (i <= haystack.len - needle.len) {
            var j = needle.len - 1;
            var skip: bool = false;
            while (j >= 0 and (needle[j] == haystack[i + j])) : (j -= 1) {
                if (j == 0) {
                    try indices.append(i);
                    i += gs_table[0];
                    skip = true;
                    break;
                }
            }

            if (!skip)
                i += std.math.max(gs_table[j + 1], @intCast(usize, @intCast(isize, j) - bc_table[@intCast(usize, haystack[i + j])]));
        }

        return indices.toOwnedSlice();
    }

    /// Return an array of indices containing substring matches for a given pattern
    /// Uses Knuth-Morris-Pratt Algorithm for string searching
    /// https://en.wikipedia.org/wiki/Knuth–Morris–Pratt_algorithm
    /// Caller owns the returned memory
    fn findSubstringIndicesKmp(self: *const String, allocator: *Allocator, pattern: []const u8) ![]usize {
        var indices = ArrayList(usize).init(allocator);
        defer indices.deinit();
        if (self.isEmpty() or pattern.len < 1 or pattern.len > self.len()) {
            return indices.items;
        }

        var lps = try self.computeLongestPrefixSuffixArray(allocator, pattern);
        defer allocator.free(lps);

        var str_index: usize = 0;
        var pat_index: usize = 0;
        while (str_index < self.len() and pat_index < pattern.len) {
            if (self.at(str_index) == pattern[pat_index]) {
                str_index += 1;
                pat_index += 1;
            } else {
                if (pat_index != 0) {
                    pat_index = lps[pat_index - 1];
                } else {
                    str_index += 1;
                }
            }
            if (pat_index == pattern.len) {
                try indices.append(str_index - pattern.len);
                pat_index = 0;
            }
        }
        return indices.toOwnedSlice();
    }

    pub fn findSubstringIndices(self: *const String, allocator: *Allocator, pattern: []const u8, comptime searcher: Self.Searcher) ![]usize {
        switch (searcher) {
            Self.Searcher.BoyerMooreHorspool => return self.findSubstringIndicesBmh(allocator, pattern),
            Self.Searcher.KnuthMorrisPratt => return self.findSubstringIndicesKmp(allocator, pattern),
        }
    }

    pub fn contains(self: *const String, allocator: *Allocator, pattern: []const u8) !bool {
        var matches = try self.findSubstringIndices(allocator, pattern, Self.Searcher.BoyerMooreHorspool);
        defer allocator.free(matches);
        return matches.len > 0;
    }

    pub fn toSlice(self: *const String) [:0]u8 {
        const _len = self.buffer.list.items.len;
        return self.buffer.list.items[0 .. _len - 1 :0];
    }

    pub fn toSliceConst(self: *const String) [:0]const u8 {
        const _len = self.buffer.list.items.len;
        return @as([:0]const u8, self.buffer.list.items[0 .. _len - 1 :0]);
    }

    pub fn trim(self: *String, trim_pattern: []const u8) !void {
        var trimmed_str = mem.trim(u8, self.toSliceConst(), trim_pattern);
        try self.setTrimmedStr(trimmed_str);
    }

    pub fn trimLeft(self: *String, trim_pattern: []const u8) !void {
        const trimmed_str = mem.trimLeft(u8, self.toSliceConst(), trim_pattern);
        try self.setTrimmedStr(trimmed_str);
    }

    pub fn trimRight(self: *String, trim_pattern: []const u8) !void {
        const trimmed_str = mem.trimRight(u8, self.toSliceConst(), trim_pattern);
        try self.setTrimmedStr(trimmed_str);
    }

    fn setTrimmedStr(self: *String, trimmed_str: []const u8) !void {
        const m = trimmed_str.len;
        std.debug.assert(self.len() >= m); // this should always be true
        for (trimmed_str) |v, i| {
            self.buffer.list.items[i] = v;
        }
        try self.buffer.resize(m);
    }

    pub fn split(self: *const String, delimiter: []const u8) mem.SplitIterator {
        return mem.split(self.toSliceConst(), delimiter);
    }

    /// Replaces all occurrences of substring `old` replaced with `new` in place
    pub fn replace(self: *String, allocator: *Allocator, old: []const u8, new: []const u8) !void {
        if (self.len() < 1 or old.len < 1) {
            return;
        }

        var matches = try self.findSubstringIndices(allocator, old, Self.Searcher.BoyerMooreHorspool);
        defer allocator.free(matches);
        if (matches.len < 1) {
            return;
        }
        var new_contents = ArrayList(u8).init(allocator);
        defer new_contents.deinit();

        var orig_index: usize = 0;
        for (matches) |match_index| {
            while (orig_index < match_index) {
                try new_contents.append(self.at(orig_index));
                orig_index += 1;
            }
            orig_index = match_index + old.len;
            for (new) |val| {
                try new_contents.append(val);
            }
        }
        // Append end of string if match does not end original string
        while (orig_index < self.len()) {
            try new_contents.append(self.at(orig_index));
            orig_index += 1;
        }
        try self.buffer.replaceContents(@as([]const u8, new_contents.items));
    }

    pub fn count(self: *const String, allocator: *Allocator, pattern: []const u8) !usize {
        var matches = try self.findSubstringIndices(allocator, pattern, String.Searcher.BoyerMooreHorspool);
        return matches.len;
    }

    /// Only makes ASCII characters lowercase
    pub fn toLower(self: *String) void {
        for (self.toSlice()) |*c| {
            c.* = ascii.toLower(c.*);
        }
    }

    /// Only makes ASCII characters uppercase
    pub fn toUpper(self: *String) void {
        for (self.toSlice()) |*c| {
            c.* = ascii.toUpper(c.*);
        }
    }

    pub fn ptr(self: *const String) [*:0]u8 {
        return self.buffer.span().ptr;
    }
};

test ".startsWith" {
    var buf: [256]u8 = undefined;
    const allocator = &std.heap.FixedBufferAllocator.init(&buf).allocator;
    var s = try String.init(allocator, "hello world");
    defer s.deinit();

    testing.expect(s.startsWith("hel"));
}

test ".endsWith" {
    var buf: [256]u8 = undefined;
    const allocator = &std.heap.FixedBufferAllocator.init(&buf).allocator;
    var s = try String.init(allocator, "hello world");
    defer s.deinit();

    testing.expect(s.endsWith("orld"));
}

test ".isEmpty" {
    var buf: [256]u8 = undefined;
    const allocator = &std.heap.FixedBufferAllocator.init(&buf).allocator;
    var s = try String.init(allocator, "");
    defer s.deinit();

    testing.expect(s.isEmpty());
    try s.append("hello");
    std.testing.expect(!s.isEmpty());
}

test ".len" {
    var buf: [256]u8 = undefined;
    const allocator = &std.heap.FixedBufferAllocator.init(&buf).allocator;
    var s = try String.init(allocator, "");
    defer s.deinit();

    testing.expect(s.len() == 0);
    try s.append("hello");
    std.testing.expect(s.len() == 5);
}

test ".eql" {
    var buf: [256]u8 = undefined;
    const allocator = &std.heap.FixedBufferAllocator.init(&buf).allocator;
    var s = try String.init(allocator, "hello world");
    defer s.deinit();

    testing.expect(s.eql("hello world"));
}

test ".reverse" {
    var buf: [256]u8 = undefined;
    const allocator = &std.heap.FixedBufferAllocator.init(&buf).allocator;
    var s = try String.init(allocator, "");
    defer s.deinit();

    s.reverse();
    testing.expect(s.eql(""));

    try s.append("h");
    s.reverse();
    testing.expect(s.eql("h"));

    try s.append("e");
    s.reverse();
    testing.expect(s.eql("eh"));

    try s.buffer.replaceContents("hello");
    s.reverse();
    testing.expect(s.eql("olleh"));
}

test ".findSubstringIndicesBmh" {
    var buf: [1024]u8 = undefined;
    const allocator = &std.heap.FixedBufferAllocator.init(&buf).allocator;
    var s = try String.init(allocator, "Mississippi");
    defer s.deinit();

    const m1 = try s.findSubstringIndices(allocator, "i", String.Searcher.BoyerMooreHorspool);
    testing.expect(mem.eql(usize, m1, &[_]usize{ 1, 4, 7, 10 }));

    const m2 = try s.findSubstringIndices(allocator, "iss", String.Searcher.BoyerMooreHorspool);
    testing.expect(mem.eql(usize, m2, &[_]usize{ 1, 4 }));

    const m3 = try s.findSubstringIndices(allocator, "z", String.Searcher.BoyerMooreHorspool);
    testing.expect(mem.eql(usize, m3, &[_]usize{}));

    const m4 = try s.findSubstringIndices(allocator, "Mississippi", String.Searcher.BoyerMooreHorspool);
    testing.expect(mem.eql(usize, m4, &[_]usize{0}));

    var s2 = try String.init(allocator, "的中对不起我的中文不好");
    defer s2.deinit();
    const m5 = try s2.findSubstringIndices(allocator, "的中", String.Searcher.BoyerMooreHorspool);
    testing.expect(mem.eql(usize, m5, &[_]usize{ 0, 18 }));
}

test ".findSubstringIndicesKmp" {
    var buf: [1024]u8 = undefined;
    const allocator = &std.heap.FixedBufferAllocator.init(&buf).allocator;
    var s = try String.init(allocator, "Mississippi");
    defer s.deinit();

    const m1 = try s.findSubstringIndices(allocator, "i", String.Searcher.KnuthMorrisPratt);
    testing.expect(mem.eql(usize, m1, &[_]usize{ 1, 4, 7, 10 }));

    const m2 = try s.findSubstringIndices(allocator, "iss", String.Searcher.KnuthMorrisPratt);
    testing.expect(mem.eql(usize, m2, &[_]usize{ 1, 4 }));

    const m3 = try s.findSubstringIndices(allocator, "z", String.Searcher.KnuthMorrisPratt);
    testing.expect(mem.eql(usize, m3, &[_]usize{}));

    const m4 = try s.findSubstringIndices(allocator, "Mississippi", String.Searcher.KnuthMorrisPratt);
    testing.expect(mem.eql(usize, m4, &[_]usize{0}));

    var s2 = try String.init(allocator, "的中对不起我的中文不好");
    defer s2.deinit();
    const m5 = try s2.findSubstringIndices(allocator, "的中", String.Searcher.KnuthMorrisPratt);
    testing.expect(mem.eql(usize, m5, &[_]usize{ 0, 18 }));
}

test ".contains" {
    var buf: [1024]u8 = undefined;
    const allocator = &std.heap.FixedBufferAllocator.init(&buf).allocator;
    var s = try String.init(allocator, "Mississippi");
    defer s.deinit();

    const m1 = try s.contains(allocator, "i");
    testing.expect(m1 == true);

    const m2 = try s.contains(allocator, "iss");
    testing.expect(m2 == true);

    const m3 = try s.contains(allocator, "z");
    testing.expect(m3 == false);

    const m4 = try s.contains(allocator, "Mississippi");
    testing.expect(m4 == true);
}

test ".toSlice" {
    var buf: [256]u8 = undefined;
    const allocator = &std.heap.FixedBufferAllocator.init(&buf).allocator;
    var s = try String.init(allocator, "hello world");
    defer s.deinit();
    testing.expect(mem.eql(u8, "hello world", s.toSlice()));
}

test ".toSliceConst" {
    var buf: [256]u8 = undefined;
    const allocator = &std.heap.FixedBufferAllocator.init(&buf).allocator;
    var s = try String.init(allocator, "hello world");
    defer s.deinit();
    testing.expect(mem.eql(u8, "hello world", s.toSliceConst()));
}

test ".trim" {
    var buf: [256]u8 = undefined;
    const allocator = &std.heap.FixedBufferAllocator.init(&buf).allocator;
    var s = try String.init(allocator, " foo\n ");
    defer s.deinit();
    try s.trim(" \n");
    testing.expectEqualSlices(u8, "foo", s.toSliceConst());
    testing.expect(3 == s.len());
    try s.trim(" \n");
    testing.expectEqualSlices(u8, "foo", s.toSliceConst());
}

test ".trimLeft" {
    var buf: [256]u8 = undefined;
    const allocator = &std.heap.FixedBufferAllocator.init(&buf).allocator;
    var s = try String.init(allocator, " foo\n ");
    defer s.deinit();
    try s.trimLeft(" \n");
    testing.expectEqualSlices(u8, "foo\n ", s.toSliceConst());
}

test ".trimRight" {
    var buf: [256]u8 = undefined;
    const allocator = &std.heap.FixedBufferAllocator.init(&buf).allocator;
    var s = try String.init(allocator, " foo\n ");
    defer s.deinit();
    try s.trimRight(" \n");
    testing.expectEqualSlices(u8, " foo", s.toSliceConst());
}

test ".split" {
    var buf: [256]u8 = undefined;
    const allocator = &std.heap.FixedBufferAllocator.init(&buf).allocator;
    var s = try String.init(allocator, "abc|def||ghi");
    defer s.deinit();

    // All of these tests are from std/mem.zig
    var it = s.split("|");
    testing.expect(mem.eql(u8, it.next().?, "abc"));
    testing.expect(mem.eql(u8, it.next().?, "def"));
    testing.expect(mem.eql(u8, it.next().?, ""));
    testing.expect(mem.eql(u8, it.next().?, "ghi"));
    testing.expect(it.next() == null);

    try s.buffer.replaceContents("");
    it = s.split("|");
    testing.expect(mem.eql(u8, it.next().?, ""));
    testing.expect(it.next() == null);

    try s.buffer.replaceContents("|");
    it = s.split("|");
    testing.expect(mem.eql(u8, it.next().?, ""));
    testing.expect(mem.eql(u8, it.next().?, ""));
    testing.expect(it.next() == null);
}

test ".replace" {
    var buf: [1024]u8 = undefined;
    const allocator = &std.heap.FixedBufferAllocator.init(&buf).allocator;
    var s = try String.init(allocator, "Mississippi");
    defer s.deinit();
    try s.replace(allocator, "iss", "e");
    testing.expectEqualSlices(u8, "Meeippi", s.toSliceConst());

    try s.buffer.replaceContents("Mississippi");
    try s.replace(allocator, "iss", "issi");
    testing.expectEqualSlices(u8, "Missiissiippi", s.toSliceConst());

    try s.buffer.replaceContents("Mississippi");
    try s.replace(allocator, "i", "a");
    testing.expectEqualSlices(u8, "Massassappa", s.toSliceConst());

    try s.buffer.replaceContents("Mississippi");
    try s.replace(allocator, "iss", "");
    testing.expectEqualSlices(u8, "Mippi", s.toSliceConst());

    try s.buffer.replaceContents("Mississippi");
    try s.replace(allocator, s.toSliceConst(), "Foo");
    testing.expectEqualSlices(u8, "Foo", s.toSliceConst());
}

test ".count" {
    var buf: [1024]u8 = undefined;
    const allocator = &std.heap.FixedBufferAllocator.init(&buf).allocator;
    var s = try String.init(allocator, "Mississippi");
    defer s.deinit();
    const c1 = try s.count(allocator, "i");
    testing.expect(c1 == 4);

    const c2 = try s.count(allocator, "M");
    testing.expect(c2 == 1);

    const c3 = try s.count(allocator, "abc");
    testing.expect(c3 == 0);

    const c4 = try s.count(allocator, "iss");
    testing.expect(c4 == 2);
}

test ".toLower" {
    var buf: [256]u8 = undefined;
    const allocator = &std.heap.FixedBufferAllocator.init(&buf).allocator;
    var s = try String.init(allocator, "ABCDEF");
    defer s.deinit();
    s.toLower();
    testing.expectEqualSlices(u8, "abcdef", s.toSliceConst());

    try s.buffer.replaceContents("的ABcdEF中");
    s.toLower();
    testing.expectEqualSlices(u8, "的abcdef中", s.toSliceConst());

    try s.buffer.replaceContents("AB的cd中EF");
    s.toLower();
    testing.expectEqualSlices(u8, "ab的cd中ef", s.toSliceConst());
}

test ".toUpper" {
    var buf: [256]u8 = undefined;
    const allocator = &std.heap.FixedBufferAllocator.init(&buf).allocator;
    var s = try String.init(allocator, "abcdef");
    defer s.deinit();
    s.toUpper();
    testing.expectEqualSlices(u8, "ABCDEF", s.toSliceConst());

    try s.buffer.replaceContents("的abCDef中");
    s.toUpper();
    testing.expectEqualSlices(u8, "的ABCDEF中", s.toSliceConst());

    try s.buffer.replaceContents("ab的CD中ef");
    s.toUpper();
    testing.expectEqualSlices(u8, "AB的CD中EF", s.toSliceConst());
}

test ".ptr" {
    var buf: [256]u8 = undefined;
    const allocator = &std.heap.FixedBufferAllocator.init(&buf).allocator;
    var s = try String.init(allocator, "abcdef");
    defer s.deinit();
    testing.expect(mem.eql(u8, mem.spanZ(s.ptr()), s.toSliceConst()));
}
