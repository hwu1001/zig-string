const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;
const Buffer = std.Buffer;
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

    pub fn len(self: *String) usize {
        return self.buffer.len();
    }

    pub fn append(self: *String, m: []const u8) !void {
        try self.buffer.append(m);
    }

    pub fn eql(self: *String, m: []const u8) bool {
        return self.buffer.eql(m);
    }

    pub fn reverse(self: *String) void {
        if (self.len() <= 1) {
            return;
        }
        var i: usize = 0;
        var j: usize = self.len() - 1;
        while (i < j) {
            var temp = self.buffer.list.at(i);
            self.buffer.list.set(i, self.buffer.list.at(j));
            self.buffer.list.set(j, temp);
            i += 1;
            j -= 1;
        }
    }

    //pub fn dump(self: *String) void {
    //    std.debug.warn("{}", self.buffer.toSlice());
    //}
    // [ ] Substring search (find all occurrences)
    // [ ] Replace with substring
    // [ ] Some sort of contains method
    // [ ] IsNull
    // [X] length
    // [ ] toSlice
    // [ ] toSliceConst
    // [X] append string
    // [X] equal (to a given string)
    // [ ] ptr for c strings
    // [ ] reverse
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
