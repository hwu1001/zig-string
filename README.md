
A String struct made for Zig.

Inspired by this repo: https://github.com/clownpriest/strings/

To test:
```
$ cd zig-string/
$ zig test string.zig
```

Basic Usage:
```zig
const std = @import("std");
const String = @import("/some/path/string.zig").String;

pub fn main() !void {
    var buf: [1024]u8 = undefined;
    var fba = std.heap.ThreadSafeFixedBufferAllocator.init(buf[0..]);
    var s = try String.init(&fba.allocator, "hello, world");
    defer s.deinit();
    var matches = try s.findSubstringIndices(&fba.allocator, "hello");
    defer fba.allocator.free(matches);
    // Should print:
    // 0
    // hello, world
    for (matches) |val| {
        std.debug.warn("{}\n", val);
    }
    std.debug.warn("{}\n", s.toSliceConst());
}
```
