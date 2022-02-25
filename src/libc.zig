const builtin = @import("builtin");
const std = @import("std");

export var errno: c_int = 0;

const c = @cImport({
    @cInclude("../inc/stdio.h");
});

export fn puts(s: [*:0]const u8) callconv(.C) c_int {
    // NOTE: this is inneficient
    //       Maybe I could do a writev?
    //       I could make 2 write calls with a locking mechanism?
    const len = std.mem.len(s);
    // TODO: maybe use malloc?
    const mem = std.heap.page_allocator.alloc(u8, len + 1) catch |err| switch (err) {
        error.OutOfMemory => {
            // maybe fallback to 2 writes?
            @panic("here");
        },
    };
    defer std.heap.page_allocator.free(mem);
    @memcpy(mem.ptr, s, len);
    mem[len] = '\n';

    if (builtin.os.tag == .windows) {
        @panic("not impl");
        //std.os.windows.kernel32.WriteFile(
        //    std.os.windows.peb().ProcessParameters.hStdOutput,
        //    std.io.getStdOut().handle,
        //    s,
        //    std.mem.len(s),
//
        //return windows.WriteFile(fd, bytes, null, std.io.default_mode);
    }

    switch (std.os.errno(std.os.system.write(std.io.getStdOut().handle, mem.ptr, mem.len))) {
        .SUCCESS => return 1,
        else => |e| {
            errno = @enumToInt(e);
            return c.EOF;
        },
    }
}
//export fn printf(fmt: [*:0]u8, args: ...) callconv(.C) c_int {
//    return 0;
//}
