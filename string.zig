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
pub fn longestPrefixSuffix(allocator: *Allocator, pattern: []const u8) ![]usize {
    var lps = try allocator.alloc(usize, pattern.len);
    for (lps) |*i| {
        i.* = 0;
    }

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
pub fn findSubstring(allocator: *Allocator, buffer: []const u8, pattern: []const u8) !?usize {
    if (isEmpty(buffer) or pattern.len < 1 or pattern.len > buffer.len) {
        return null;
    }

    var lps = try longestPrefixSuffix(allocator, pattern);
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

/// Return an array of indices containing substring matches for a given pattern
/// Uses Knuth-Morris-Pratt Algorithm for string searching
/// https://en.wikipedia.org/wiki/Knuth–Morris–Pratt_algorithm
/// Caller owns the returned memory.
/// Currently doesn't find overlapping patterns.
pub fn findSubstringIndices(allocator: *Allocator, buffer: []const u8, pattern: []const u8) ![]usize {
    var indices = ArrayList(usize).init(allocator);
    defer indices.deinit();
    if (isEmpty(buffer) or pattern.len < 1 or pattern.len > buffer.len) {
        return indices.items;
    }

    var lps = try longestPrefixSuffix(allocator, pattern);
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
            try indices.append(str_index - pat_index);
            // Shift backwards to check overlapping substrings
            str_index -= lps[pat_index - 1];
            pat_index = 0;
        }
    }
    return indices.toOwnedSlice();
}

pub fn contains(allocator: *Allocator, buffer: []const u8, pattern: []const u8) !bool {
    return null != try findSubstring(allocator, buffer, pattern);
}

/// Replaces all occurrences of substring `old` replaced with `new` in place
pub fn replace(allocator: *Allocator, buffer: *[]u8, old: []const u8, new: []const u8) !void {
    // TODO: implement a version without allocator when old and new have the same length
    if (buffer.len < 1 or old.len < 1) {
        return;
    }

    var matches = try buffer.findSubstringIndices(allocator, old);
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
    // Append end of string if match does not end original string
    while (orig_index < buffer.len) {
        try new_contents.append(buffer.at(orig_index));
        orig_index += 1;
    }
    try buffer.replaceContents(new_contents.toSliceConst());
}

pub fn count(allocator: *Allocator, buffer: []const u8, pattern: []const u8) !usize {
    var matches = try findSubstringIndices(allocator, buffer, pattern);
    defer allocator.free(matches);
    return matches.len;
}


const testing = std.testing;
const expect = testing.expect;

test "isEmpty" {
    var s = "hello";
    expect(!isEmpty(s));
}

test "eql" {
    var s = try testing.allocator.alloc(u8, 11);
    defer testing.allocator.free(s);
    
    mem.copy(u8, s, "hello world");

    expect(mem.eql(u8, s, "hello world"));
}

test "longestPrefixSuffix" {
    const lps = try longestPrefixSuffix(testing.allocator, "issi");
    defer testing.allocator.free(lps);
}

test "findSubstringIndices" {
    const s = "Mississippi";

    const m1 = try findSubstringIndices(testing.allocator, s, "i");
    defer testing.allocator.free(m1);
    expect(mem.eql(usize, m1, &[_]usize{ 1, 4, 7, 10 }));

    const m2 = try findSubstringIndices(testing.allocator, s, "iss");
    defer testing.allocator.free(m2);
    expect(mem.eql(usize, m2, &[_]usize{ 1, 4 }));

    // TODO: make this pass
    const m3 = try findSubstringIndices(testing.allocator, s, "issi");
    defer testing.allocator.free(m3);
    expect(mem.eql(usize, m3, &[_]usize{ 1, 4 }));
    
    const m4 = try findSubstringIndices(testing.allocator, s, "z");
    defer testing.allocator.free(m4);
    expect(mem.eql(usize, m4, &[_]usize{ }));

    const m5 = try findSubstringIndices(testing.allocator, s, "Mississippi");
    defer testing.allocator.free(m5);
    expect(mem.eql(usize, m5, &[_]usize{ 0 }));

    var s2 = "的中对不起我的中文不好";
    const m6 = try findSubstringIndices(testing.allocator, s2, "的中");
    defer testing.allocator.free(m6);
    expect(mem.eql(usize, m6, &[_]usize{ 0, 18 }));
}

test "contains" {
    const m1 = try contains(testing.allocator, "Mississippi", "i");
    expect(m1);

    const m2 = try contains(testing.allocator, "Mississippi", "iss");
    expect(m2);
    
    const m3 = try contains(testing.allocator, "Mississippi", "z");
    expect(!m3);

    const m4 = try contains(testing.allocator, "Mississippi", "Mississippi");
    expect(m4);
}

test "replace" {
    var s = "Mississippi";

    try replace(testing.allocator, s, "iss", "e");
    expectEqualSlices(u8, "Meeippi", s.toSliceConst());

    try s.buffer.replaceContents("Mississippi");
    try s.replace(testing.allocator, "iss", "issi");
    expectEqualSlices(u8, "Missiissiippi", s.toSliceConst());

    try s.buffer.replaceContents("Mississippi");
    try s.replace(testing.allocator, "i", "a");
    expectEqualSlices(u8, "Massassappa", s.toSliceConst());

    try s.buffer.replaceContents("Mississippi");
    try s.replace(testing.allocator, "iss", "");
    expectEqualSlices(u8, "Mippi", s.toSliceConst());

    try s.buffer.replaceContents("Mississippi");
    try s.replace(testing.allocator, s.toSliceConst(), "Foo");
    expectEqualSlices(u8, "Foo", s.toSliceConst());
}

test "count" {
    var s = "Mississippi";
    const c1 = try count(testing.allocator, s, "i");
    expect(c1 == 4);

    const c2 = try count(testing.allocator, s, "M");
    expect(c2 == 1);

    const c3 = try count(testing.allocator, s, "abc");
    expect(c3 == 0);

    const c4 = try count(testing.allocator, s, "iss");
    expect(c4 == 2);

    const c5 = try count(testing.allocator, s, "issi");
    expect(c5 == 2);
}
