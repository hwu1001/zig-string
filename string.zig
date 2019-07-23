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
        return lps.toSlice();
    }

    /// Return an array of indices containing substring matches for a given pattern
    /// Uses Knuth-Morris-Pratt Algorithm for string searching
    /// https://en.wikipedia.org/wiki/Knuth–Morris–Pratt_algorithm
    pub fn findSubstringIndices(self: *const String, allocator: *Allocator, pattern: []const u8) ![]usize {
        var indices = ArrayList(usize).init(allocator);
        defer indices.deinit();
        if (self.isEmpty() or pattern.len < 1 or pattern.len > self.len()) {
            return indices.toSlice();
        }
        
        var lps = try self.computeLongestPrefixSuffixArray(allocator, pattern);
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
        return indices.toSlice();
    }

    //pub fn dump(self: *String) void {
    //    std.debug.warn("{}", self.buffer.toSlice());
    //}
    // [X] Substring search (find all occurrences)
    // [ ] Replace with substring
    // [ ] Some sort of contains method
    // [X] IsEmpty
    // [X] length
    // [ ] toSlice
    // [ ] toSliceConst
    // [X] append string
    // [X] equal (to a given string)
    // [ ] ptr for c strings
    // [X] reverse
    // [ ] strip
    // [ ] lower
    // [ ] upper
    // [ ] strip whitespace
    // [ ] left strip
    // [ ] right strip
    // [ ] split
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
    testing.expect(mem.eql(usize, m4, [_]usize{ 0 }));
}
