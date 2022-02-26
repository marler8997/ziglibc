const builtin = @import("builtin");
const std = @import("std");

const c = @cImport({
    @cInclude("../inc/stdio.h");
});

export var errno: c_int = 0;

var stdin_storage: c.FILE = .{
    .fd = std.os.STDIN_FILENO,
    .errno = undefined,
};
var stdout_storage: c.FILE = .{
    .fd = std.os.STDOUT_FILENO,
    .errno = undefined,
};
var stderr_storage: c.FILE = .{
    .fd = std.os.STDERR_FILENO,
    .errno = undefined,
};
export var stdin: *c.FILE = &stdin_storage;
export var stdout: *c.FILE = &stdout_storage;
export var stderr: *c.FILE = &stderr_storage;

export fn abort() callconv(.C) noreturn {
    @panic("abort");
}

export fn strlen(s: [*:0]const u8) callconv(.C) usize {
    return std.mem.len(s);
}

export fn strcmp(a: [*:0]const u8, b: [*:0]const u8) callconv(.C) c_int {
    var a_next = a;
    var b_next = b;
    while (a_next[0] == b_next[0] and a_next[0] != 0) {
        a_next += 1;
        b_next += 1;
    }
    return a_next[0] - b_next[0];
}

export fn strchr(s: [*:0]const u8, char: c_int) callconv(.C) ?[*:0]const u8 {
    var next = s;
    while (true) : (next += 1) {
        if (next[0] == char) return next;
        if (next[0] == 0) return null;
    }
}

// TODO: can name be null?
// TODO: should we detect and do something different if there is a '=' in name?
export fn getenv(name: [*:0]const u8) callconv(.C) ?[*:0]u8 {
    _ = name;
    return null; // not implemented
    //const name_len = std.mem.len(name);
    //var e: ?[*:0]u8 = environ;
}

export fn fputc(character: c_int, stream: *c.FILE) callconv(.C) c_int {
    const buf = [_]u8 { @intCast(u8, 0xff & character) };
    const written = std.os.system.write(stream.fd, &buf, 1);
    switch (std.os.errno(written)) {
        .SUCCESS => {
            if (written == 1) return character;
            stream.errno = @enumToInt(std.os.E.IO);
            return c.EOF;
        },
        else => |e| {
            stream.errno = @enumToInt(e);
            return c.EOF;
        },
    }
}

// NOTE: this is not apart of libc
export fn _fwrite_buf(ptr: [*]const u8, size: usize, stream: *c.FILE) callconv(.C) usize {
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
export fn fwrite(ptr: [*]const u8, size: usize, nmemb: usize, stream: *c.FILE) callconv(.C) usize {
    const total = size * nmemb;
    const result = _fwrite_buf(ptr, total, stream);
    if (result == total) return nmemb;
    return result / size;
}

export fn fflush(stream: ?*c.FILE) callconv(.C) c_int {
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
