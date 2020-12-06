
Implements common string operations such as substring searching.

Note: Most of these functions are in std.mem.

Inspired by this repo: https://github.com/clownpriest/strings/

To test:
```bash
cd zig-string
zig test string.zig
```

Basic Usage:
```zig
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
```

This example can be run with:
```bash
cd zig-string
zig run readme.zig
```