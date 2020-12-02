const std = @import("std");
const mem = std.mem;
const ascii = std.ascii;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;


pub fn isEmpty(buffer: []const u8) bool {
    // Can't use Buffer.isNull because Buffer maintains a null byte at the
    // end. (e.g., []u8 of "" in a Buffer is not null)
    return buffer.len == 0;
}

/// Caller owns the returned memory
fn longestPrefixSuffix(allocator: *Allocator, buffer: []const u8, pattern: []const u8) ![]usize {
    var lps = try allocator.alloc(usize, pattern.len);    
    // Left and right positions going through the pattern
    var left: usize = 0;
    var right: usize = 1;
    while (right < pattern.len) {
        if (pattern[right] == pattern[left]) {
            lps[right] = left + 1;
            left += 1;
            right += 1;
        } else {
            if (left != 0) {
                left = lps[left - 1];
            } else {
                lps[right] = 0;
                right += 1;
            }
        }
    }
    return lps;
}

/// Return the index of the first match for a given pattern or null.
/// Uses `allocator` for table generation, allocating the length of `pattern`.
pub fn findSubString(allocator: *Allocator, buffer: []const u8, pattern: []const u8) !?usize {
    if (isEmpty(buffer) or pattern.len < 1 or pattern.len > buffer.len) {
        return null;
    }

    var lps = try longestPrefixSuffix(allocator, buffer, pattern);
    defer allocator.free(lps);

    var str_index: usize = 0;
    var pat_index: usize = 0;
    while (str_index < buffer.len and pat_index < pattern.len) {
        if (buffer[str_index] == pattern[pat_index]) {
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
            return str_index - pattern.len;
        }
    }
    return null;
}

/// Return an array of indices containing sub[]u8 matches for a given pattern
/// Uses Knuth-Morris-Pratt Algorithm for []u8 searching
/// https://en.wikipedia.org/wiki/Knuth–Morris–Pratt_algorithm
/// Caller owns the returned memory
pub fn findSubStringIndices(allocator: *Allocator, buffer: []const u8, pattern: []const u8) ![]usize {
    var indices = ArrayList(usize).init(allocator);
    defer indices.deinit();
    if (isEmpty(buffer) or pattern.len < 1 or pattern.len > buffer.len) {
        return indices.items;
    }

    var lps = try longestPrefixSuffix(allocator, buffer, pattern);
    defer allocator.free(lps);

    var str_index: usize = 0;
    var pat_index: usize = 0;
    while (str_index < buffer.len and pat_index < pattern.len) {
        if (buffer[str_index] == pattern[pat_index]) {
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

pub fn contains(allocator: *Allocator, buffer: []const u8, pattern: []const u8) !bool {
    return null != try findSubString(allocator, buffer, pattern);
}

pub fn toSlice(buffer: []const u8) []u8 {
    return buffer.toSlice();
}

pub fn toSliceConst(buffer: []const u8) []const u8 {
    return buffer.toSliceConst();
}

pub fn trim(buffer: *[]u8, trim_pattern: []const u8) !void {
    var trimmed_str = mem.trim(u8, buffer.toSliceConst(), trim_pattern);
    try buffer.setTrimmedStr(trimmed_str);
}

pub fn trimLeft(buffer: *[]u8, trim_pattern: []const u8) !void {
    const trimmed_str = mem.trimLeft(u8, buffer.toSliceConst(), trim_pattern);
    try buffer.setTrimmedStr(trimmed_str);
}

pub fn trimRight(buffer: *[]u8, trim_pattern: []const u8) !void {
    const trimmed_str = mem.trimRight(u8, buffer.toSliceConst(), trim_pattern);
    try buffer.setTrimmedStr(trimmed_str);
}

fn setTrimmedStr(buffer: *[]u8, trimmed_str: []const u8) !void {
    const m = trimmed_str.len;
    std.debug.assert(buffer.len >= m); // this should always be true
    for (trimmed_str) |v, i| {
        buffer.list.set(i, v);
    }
    try buffer.resize(m);
}

pub fn split(buffer: []const u8, delimiter: []const u8) mem.SplitIterator {
    return mem.separate(buffer.toSliceConst(), delimiter);
}

/// Replaces all occurrences of sub[]u8 `old` replaced with `new` in place
pub fn replace(buffer: *[]u8, allocator: *Allocator, old: []const u8, new: []const u8) !void {
    if (buffer.len < 1 or old.len < 1) {
        return;
    }

    var matches = try buffer.findSubStringIndices(allocator, old);
    defer allocator.free(matches);
    if (matches.len < 1) {
        return;
    }
    var new_contents = ArrayList(u8).init(allocator);
    defer new_contents.deinit();

    var orig_index: usize = 0;
    for (matches) |match_index| {
        while (orig_index < match_index) {
            try new_contents.append(buffer.at(orig_index));
            orig_index += 1;
        }
        orig_index = match_index + old.len;
        for (new) |val| {
            try new_contents.append(val);
        }
    }
    // Append end of []u8 if match does not end original []u8
    while (orig_index < buffer.len) {
        try new_contents.append(buffer.at(orig_index));
        orig_index += 1;
    }
    try buffer.replaceContents(new_contents.toSliceConst());
}

pub fn count(buffer: []const u8, allocator: *Allocator, pattern: []const u8) !usize {
    var matches = try buffer.findSubStringIndices(allocator, pattern);
    return matches.len;
}

/// Only makes ASCII characters lowercase
pub fn toLower(buffer: *[]u8) void {
    for (buffer.toSlice()) |*c| {
        c.* = ascii.toLower(c.*);
    }
}

/// Only makes ASCII characters uppercase
pub fn toUpper(buffer: *[]u8) void {
    for (buffer.toSlice()) |*c| {
        c.* = ascii.toUpper(c.*);
    }
}


const testing = std.testing;
const print = std.debug.print;

test "isEmpty" {
    var s = "hello";
    std.testing.expect(!isEmpty(s));
}

test "eql" {
    var buf: [256]u8 = undefined;
    const allocator = &std.heap.FixedBufferAllocator.init(&buf).allocator;
    var s = try allocator.alloc(u8, 11);
    defer allocator.free(s);
    
    mem.copy(u8, s, "hello world");

    testing.expect(mem.eql(u8, s, "hello world"));
}

test "findSubStringIndices" {
    var buf: [1024]u8 = undefined;
    const allocator = &std.heap.FixedBufferAllocator.init(&buf).allocator;
    const lit = "Mississippi";
    var s = try allocator.alloc(u8, lit.len);
    mem.copy(u8, s, lit);
    defer allocator.free(s);

    const m1 = try findSubStringIndices(testing.allocator, s, "i");
    defer testing.allocator.free(m1);
    print("{}\n", .{m1});
    testing.expect(mem.eql(usize, m1, &[_]usize{ 1, 4, 7, 10 }));

    // const m2 = try s.findSubStringIndices(allocator, "iss");
    // testing.expect(mem.eql(usize, m2, [_]usize{ 1, 4 }));

    // const m3 = try s.findSubStringIndices(allocator, "z");
    // testing.expect(mem.eql(usize, m3, [_]usize{}));

    // const m4 = try s.findSubStringIndices(allocator, "Mississippi");
    // testing.expect(mem.eql(usize, m4, [_]usize{0}));

    // var s2 = try []u8.init(allocator, "的中对不起我的中文不好");
    // defer s2.deinit();
    // const m5 = try s2.findSubStringIndices(allocator, "的中");
    // testing.expect(mem.eql(usize, m5, [_]usize{ 0, 18 }));
}

test ".contains" {
    const m1 = try contains(testing.allocator, "Mississippi", "i");
    testing.expect(m1);

    const m2 = try contains(testing.allocator, "Mississippi", "iss");
    testing.expect(m2);
    
    const m3 = try contains(testing.allocator, "Mississippi", "z");
    testing.expect(!m3);

    const m4 = try contains(testing.allocator, "Mississippi", "Mississippi");
    testing.expect(m4);
}

test ".toSlice" {
    var buf: [256]u8 = undefined;
    const allocator = &std.heap.FixedBufferAllocator.init(&buf).allocator;
    var s = try []u8.init(allocator, "hello world");
    defer s.deinit();
    testing.expect(mem.eql(u8, "hello world", s.toSlice()));
}

test ".toSliceConst" {
    var buf: [256]u8 = undefined;
    const allocator = &std.heap.FixedBufferAllocator.init(&buf).allocator;
    var s = try []u8.init(allocator, "hello world");
    defer s.deinit();
    testing.expect(mem.eql(u8, "hello world", s.toSliceConst()));
}

test ".trim" {
    var buf: [256]u8 = undefined;
    const allocator = &std.heap.FixedBufferAllocator.init(&buf).allocator;
    var s = try []u8.init(allocator, " foo\n ");
    defer s.deinit();
    try s.trim(" \n");
    testing.expectEqualSlices(u8, "foo", s.toSliceConst());
    testing.expect(3 == s.len);
    try s.trim(" \n");
    testing.expectEqualSlices(u8, "foo", s.toSliceConst());
}

test ".trimLeft" {
    var buf: [256]u8 = undefined;
    const allocator = &std.heap.FixedBufferAllocator.init(&buf).allocator;
    var s = try []u8.init(allocator, " foo\n ");
    defer s.deinit();
    try s.trimLeft(" \n");
    testing.expectEqualSlices(u8, "foo\n ", s.toSliceConst());
}

test ".trimRight" {
    var buf: [256]u8 = undefined;
    const allocator = &std.heap.FixedBufferAllocator.init(&buf).allocator;
    var s = try []u8.init(allocator, " foo\n ");
    defer s.deinit();
    try s.trimRight(" \n");
    testing.expectEqualSlices(u8, " foo", s.toSliceConst());
}

test ".split" {
    var buf: [256]u8 = undefined;
    const allocator = &std.heap.FixedBufferAllocator.init(&buf).allocator;
    var s = try []u8.init(allocator, "abc|def||ghi");
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
    var s = try []u8.init(allocator, "Mississippi");
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
    var s = try []u8.init(allocator, "Mississippi");
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
    var s = try []u8.init(allocator, "ABCDEF");
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
    var s = try []u8.init(allocator, "abcdef");
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
    var s = try []u8.init(allocator, "abcdef");
    defer s.deinit();
    testing.expect(mem.eql(u8, mem.toSliceConst(u8, s.ptr()), s.toSliceConst()));
}