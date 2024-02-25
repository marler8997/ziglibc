const std = @import("std");
const c = @cImport(@cInclude("/home/debian/ZigLibC/include/stdio.h"));
const print = @import("../utils.zig").print;
export fn putchar(char: [*:0]u8) callconv(.C) void {
    print("{c}", .{char});
}
