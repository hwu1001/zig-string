const std = @import("std");
const mem = std.mem;
const ascii = std.ascii;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;

/// Alias for `buffer.len == 0`
pub fn isEmpty(buffer: []const u8) bool {
    // Can't use Buffer.isNull because Buffer maintains a null byte at the
    // end. (e.g., []u8 of "" in a Buffer is not null)
    return buffer.len == 0;
}

/// Computes an integer for each character in `pattern` representing how far
/// back in a haystack searching must resume after failure. Also known as the
/// failure function.
/// Caller owns the returned memory.
pub fn longestPrefixSuffix(
    allocator: *Allocator, pattern: []const u8
) error{OutOfMemory}![]usize {
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
pub fn findSubstring(
    allocator: *Allocator, buffer: []const u8, pattern: []const u8
) error{OutOfMemory}!?usize {
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

/// Return an array of indices containing substring matches for a given 
/// pattern. Uses Knuth-Morris-Pratt Algorithm for string searching.
/// https://en.wikipedia.org/wiki/Knuth–Morris–Pratt_algorithm
/// Caller owns the returned memory.
pub fn findSubstringIndices(
    allocator: *Allocator, buffer: []const u8, pattern: []const u8
) error{OutOfMemory}![]usize {
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

/// Checks that `pattern` occurs at least once in `buffer` as a substring.
pub fn contains(
    allocator: *Allocator, buffer: []const u8, pattern: []const u8
) error{OutOfMemory}!bool {
    return null != try findSubstring(allocator, buffer, pattern);
}

/// Counts occurrences of `pattern` in `buffer`, including those that overlap.
pub fn count(
    allocator: *Allocator, buffer: []const u8, pattern: []const u8
) !usize {
    var matches = try findSubstringIndices(allocator, buffer, pattern);
    defer allocator.free(matches);
    return matches.len;
}

// TODO: implement a version without an allocator when old and new have the
//  same length
/// Replaces all occurrences of substring `old` replaced with `new`,
/// returning a new array.
/// Caller owns the returned memory.
pub fn replace(
    allocator: *Allocator, buffer: []const u8, old: []const u8, new: []const u8
) error{OutOfMemory}![]const u8 {
    if (buffer.len < 1 or old.len < 1) {
        return mem.dupe(allocator, u8, buffer);
    }

    var matches = try findSubstringIndices(allocator, buffer, old);
    defer allocator.free(matches);
    if (matches.len < 1) {
        return mem.dupe(allocator, u8, buffer);
    }
    var new_contents = ArrayList(u8).init(allocator);
    defer new_contents.deinit();

    // Append end of string if match does not end original string
    var previous_match: usize = 0;
    if (new.len > old.len) {
        // for (matches) |match| {
            // try new_contents.appendSlice(new);
        // }

    } else {
        for (matches) |match| {
            try new_contents.appendSlice(buffer[previous_match..match - previous_match]);
            try new_contents.appendSlice(new);
            // Only need to handle old value being less than new,
            // as we are appending.
            previous_match = match;
        }
    }
    
    return new_contents.toOwnedSlice();
}

pub fn replaceInplace(
    allocator: *Allocator, buffer: []u8, old: []const u8, new: []const u8
) error{OutOfMemory}!void {
    comptime expect(old.len == new.len);
    if (buffer.len < 1 or old.len < 1) {
        return;
    }

    var matches = try findSubstringIndices(allocator, buffer, old);
    defer allocator.free(matches);
    if (matches.len < 1) {
        return;
    }

    var original: usize = 0;
    for (matches) |match| {
        while (original < match) {
            try new_contents.append(buffer[original]);
            original += 1;
        }
        original = match + old.len;
        for (new) |val| {
            try new_contents.append(val);
        }
    }
}


const testing = std.testing;
const expect = testing.expect;
const span = mem.span;

test "isEmpty" {
    var s = "hello";
    expect(!isEmpty(s));
    var s1 = "";
    expect(isEmpty(s1));
}

test "contains" {
    expect(try contains(testing.allocator, "Mississippi", "i"));
    expect(try contains(testing.allocator, "Mississippi", "iss"));
    expect(!try contains(testing.allocator, "Mississippi", "z"));
    expect(try contains(testing.allocator, "Mississippi", "Mississippi"));
}

test "count" {
    var string = "Mississippi";
    expect(4 == try count(testing.allocator, string, "i"));
    expect(1 == try count(testing.allocator, string, "M"));
    expect(0 == try count(testing.allocator, string, "abc"));
    expect(2 == try count(testing.allocator, string, "iss"));
    expect(2 == try count(testing.allocator, string, "issi"));
}

test "longestPrefixSuffix" {
    const lps = try longestPrefixSuffix(testing.allocator, "issi");
    defer testing.allocator.free(lps);
    expect(mem.eql(usize, lps, &[_]usize{ 0, 0, 0, 1 }));

    const lps2 = try longestPrefixSuffix(testing.allocator, "");
    defer testing.allocator.free(lps2);
    expect(mem.eql(usize, lps2, &[_]usize{ }));
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

fn testReplace(
    old: []const u8, new: []const u8, expected: []const u8
) error{OutOfMemory}!void {
    const new_string = try replace(testing.allocator, "Mississippi", old, new);
    std.debug.print("{}\n", .{ new_string });
    defer testing.allocator.free(new_string);
    expect(mem.eql(u8, expected, new_string));
}

test "replace" {
    try testReplace("is", "e", "Mesesippi");
    try testReplace("i", "a", "Massassappa");
    try testReplace("iss", "e", "Meeippi");
    try testReplace("iss", "issi", "Missiissiippi");
    try testReplace("iss", "", "Mippi");
    try testReplace("isss", "abc", "Mississippi");
}

fn testInplaceReplace(
    string: []u8, old: []const u8, new: []const u8, expected: []const u8
) error{OutOfMemory}!void {
    mem.copy(u8, string, "Mississippi");
    const new_string = try replace(testing.allocator, string, old, new);
    defer testing.allocator.free(new_string.*);
    expect(mem.eql(u8, expected, new_string.*));
}

test "inplaceReplace" {
    var string = try testing.allocator.alloc(u8, 11);
    defer testing.allocator.free(string);
}
