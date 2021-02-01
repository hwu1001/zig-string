const std = @import("std");
const print = std.debug.print;
const string = @import("string.zig");

pub fn main() !void {
    var buffer: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = &fba.allocator;
    
    var string_lit = "hello, world";
    var matches = try string.findSubstringIndices(allocator, string_lit, "world");
    defer allocator.free(matches);
    
    // Should print:
    // true
    // 7
    print("{}\n", .{ string.contains(allocator, string_lit, "hello") });
    for (matches) |val| {
        print("{}\n", .{ val });
    }
}