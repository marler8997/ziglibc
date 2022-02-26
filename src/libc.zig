const builtin = @import("builtin");
const std = @import("std");

export var errno: c_int = 0;
export var stdin: c.FILE = .{
    .fd = std.os.STDIN_FILENO,
    .errno = undefined,
};
export var stdout: c.FILE = .{
    .fd = std.os.STDOUT_FILENO,
    .errno = undefined,
};
export var stderr: c.FILE = .{
    .fd = std.os.STDERR_FILENO,
    .errno = undefined,
};


const c = @cImport({
    @cInclude("../inc/stdio.h");
});

// NOTE: this is not apart of libc
export fn _fwrite_buf(ptr: [*]const u8, size: usize, stream: *c.FILE) usize {
    const written = std.os.system.write(stream.fd, ptr, size);
    switch (std.os.errno(written)) {
        .SUCCESS => {
            if (written != size) {
                stream.errno = @enumToInt(std.os.E.IO);
            }
            return written;
        },
        else => |e| {
            stream.errno = @enumToInt(e);
            return 0;
        },
    }
}

// TODO: can ptr be NULL?
// TODO: can stream be NULL (I don't think it can)
export fn fwrite(ptr: [*]const u8, size: usize, nmemb: usize, stream: *c.FILE) usize {
    const total = size * nmemb;
    const result = _fwrite_buf(ptr, total, stream);
    if (result == total) return nmemb;
    return result / size;
}

export fn fflush(stream: ?*c.FILE) c_int {
    _ = stream;
    return 0; // no-op since there's no buffering right now
}

export fn puts(s: [*:0]const u8) callconv(.C) c_int {
    // NOTE: this is inneficient
    //       Maybe I could do a writev?
    //       Or maybe I could make 2 write calls with a locking mechanism?
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
