const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;
const Buffer = std.Buffer;
const ArrayList = std.ArrayList;
const testing = std.testing;

pub const String = struct {
    buffer: Buffer,

    pub fn init(allocator: *Allocator, m: []const u8) !String {
        return String{ .buffer = try Buffer.init(allocator, m) };
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
        try self.buffer.append(m);
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
            self.buffer.list.set(i, self.buffer.list.at(j));
            self.buffer.list.set(j, temp);
            i += 1;
            j -= 1;
        }
    }

    pub fn at(self: *const String, i: usize) u8 {
        return self.buffer.list.at(i);
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
                lps.set(right, left + 1);
                left += 1;
                right += 1;
            } else {
                if (left != 0) {
                    left = lps.at(left - 1);
                } else {
                    lps.set(right, 0);
                    right += 1;
                }
            }
        }
        return lps.toOwnedSlice();
    }

    /// Return an array of indices containing substring matches for a given pattern
    /// Uses Knuth-Morris-Pratt Algorithm for string searching
    /// https://en.wikipedia.org/wiki/Knuth–Morris–Pratt_algorithm
    /// Caller owns the returned memory
    pub fn findSubstringIndices(self: *const String, allocator: *Allocator, pattern: []const u8) ![]usize {
        var indices = ArrayList(usize).init(allocator);
        defer indices.deinit();
        if (self.isEmpty() or pattern.len < 1 or pattern.len > self.len()) {
            return indices.toSlice();
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

    pub fn contains(self: *const String, allocator: *Allocator, pattern: []const u8) !bool {
        var matches = try self.findSubstringIndices(allocator, pattern);
        defer allocator.free(matches);
        return matches.len > 0;
    }

    pub fn toSlice(self: *const String) []u8 {
        return self.buffer.toSlice();
    }

    pub fn toSliceConst(self: *const String) []const u8 {
        return self.buffer.toSliceConst();
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
            self.buffer.list.set(i, v);
        }
        try self.buffer.resize(m);
    }

    pub fn split(self: *const String, delimiter: []const u8) mem.SplitIterator {
        return mem.separate(self.toSliceConst(), delimiter);
    }

    /// Replaces all occurrences of substring `old` replaced with `new` in place
    pub fn replace(self: *String, allocator: *Allocator, old: []const u8, new: []const u8) !void {
        if (self.len() < 1 or old.len < 1) {
            return;
        }

        var matches = try self.findSubstringIndices(allocator, old);
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
        try self.buffer.replaceContents(new_contents.toSliceConst());
    }

    // [X] Substring search (find all occurrences)
    // [X] Replace with substring
    // [X] Some sort of contains method
    // [X] IsEmpty
    // [X] length
    // [X] toSlice
    // [X] toSliceConst
    // [X] append string
    // [X] equal (to a given string)
    // [ ] ptr for c strings
    // [X] reverse
    // [X] strip
    // [ ] lower
    // [ ] upper
    // [X] left strip
    // [X] right strip
    // [X] split
    // [ ] count occurrences of substring
};

test ".startsWith" {
    var s = try String.init(std.debug.global_allocator, "hello world");
    defer s.deinit();

    testing.expect(s.startsWith("hel"));
}

test ".endsWith" {
    var s = try String.init(std.debug.global_allocator, "hello world");
    defer s.deinit();

    testing.expect(s.endsWith("orld"));
}

test ".isEmpty" {
    var s = try String.init(std.debug.global_allocator, "");
    defer s.deinit();

    testing.expect(s.isEmpty());
    try s.append("hello");
    std.testing.expect(!s.isEmpty());
}

test ".len" {
    var s = try String.init(std.debug.global_allocator, "");
    defer s.deinit();

    testing.expect(s.len() == 0);
    try s.append("hello");
    std.testing.expect(s.len() == 5);
}

test ".eql" {
    var s = try String.init(std.debug.global_allocator, "hello world");
    defer s.deinit();

    testing.expect(s.eql("hello world"));
}

test ".reverse" {
    var s = try String.init(std.debug.global_allocator, "");
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

test ".findSubstringIndices" {
    var s = try String.init(std.debug.global_allocator, "Mississippi");
    defer s.deinit();

    const m1 = try s.findSubstringIndices(std.debug.global_allocator, "i");
    testing.expect(mem.eql(usize, m1, [_]usize{ 1, 4, 7, 10 }));

    const m2 = try s.findSubstringIndices(std.debug.global_allocator, "iss");
    testing.expect(mem.eql(usize, m2, [_]usize{ 1, 4 }));

    const m3 = try s.findSubstringIndices(std.debug.global_allocator, "z");
    testing.expect(mem.eql(usize, m3, [_]usize{}));

    const m4 = try s.findSubstringIndices(std.debug.global_allocator, "Mississippi");
    testing.expect(mem.eql(usize, m4, [_]usize{0}));

    var s2 = try String.init(std.debug.global_allocator, "的中对不起我的中文不好");
    defer s2.deinit();
    const m5 = try s2.findSubstringIndices(std.debug.global_allocator, "的中");
    testing.expect(mem.eql(usize, m5, [_]usize{ 0, 18 }));
}

test ".contains" {
    var s = try String.init(std.debug.global_allocator, "Mississippi");
    defer s.deinit();

    const m1 = try s.contains(std.debug.global_allocator, "i");
    testing.expect(m1 == true);

    const m2 = try s.contains(std.debug.global_allocator, "iss");
    testing.expect(m2 == true);

    const m3 = try s.contains(std.debug.global_allocator, "z");
    testing.expect(m3 == false);

    const m4 = try s.contains(std.debug.global_allocator, "Mississippi");
    testing.expect(m4 == true);
}

test ".toSlice" {
    var s = try String.init(std.debug.global_allocator, "hello world");
    defer s.deinit();
    testing.expect(mem.eql(u8, "hello world", s.toSlice()));
}

test ".toSliceConst" {
    var s = try String.init(std.debug.global_allocator, "hello world");
    defer s.deinit();
    testing.expect(mem.eql(u8, "hello world", s.toSliceConst()));
}

test ".trim" {
    var s = try String.init(std.debug.global_allocator, " foo\n ");
    defer s.deinit();
    try s.trim(" \n");
    testing.expectEqualSlices(u8, "foo", s.toSliceConst());
    testing.expect(3 == s.len());
    try s.trim(" \n");
    testing.expectEqualSlices(u8, "foo", s.toSliceConst());
}

test ".trimLeft" {
    var s = try String.init(std.debug.global_allocator, " foo\n ");
    defer s.deinit();
    try s.trimLeft(" \n");
    testing.expectEqualSlices(u8, "foo\n ", s.toSliceConst());
}

test ".trimRight" {
    var s = try String.init(std.debug.global_allocator, " foo\n ");
    defer s.deinit();
    try s.trimRight(" \n");
    testing.expectEqualSlices(u8, " foo", s.toSliceConst());
}

test ".split" {
    var s = try String.init(std.debug.global_allocator, "abc|def||ghi");
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
    var s = try String.init(std.debug.global_allocator, "Mississippi");
    defer s.deinit();
    try s.replace(std.debug.global_allocator, "iss", "e");
    testing.expectEqualSlices(u8, "Meeippi", s.toSliceConst());

    try s.buffer.replaceContents("Mississippi");
    try s.replace(std.debug.global_allocator, "iss", "issi");
    testing.expectEqualSlices(u8, "Missiissiippi", s.toSliceConst());

    try s.buffer.replaceContents("Mississippi");
    try s.replace(std.debug.global_allocator, "i", "a");
    testing.expectEqualSlices(u8, "Massassappa", s.toSliceConst());
}
