const builtin = @import("builtin");
const std = @import("std");

const c = @cImport({
    @cInclude("stdio.h");
    @cInclude("setjmp.h");
    @cInclude("locale.h");
    @cInclude("time.h");
});

// __main appears to be a design inherited by LLVM from gcc.
// it's typically provided by libgcc and is used to call constructors
fn __main() callconv(.C) void {
    stdin_storage.fd = std.os.windows.peb().ProcessParameters.hStdInput;
    stdout_storage.fd = std.os.windows.peb().ProcessParameters.hStdOutput;
    stderr_storage.fd = std.os.windows.peb().ProcessParameters.hStdError;

    // TODO: call constructors
}
comptime { if (builtin.os.tag == .windows) @export(__main, .{ .name = "__main" }); }

const windows = struct {
    // always sets out_written, even if it returns an error
    fn writeAll(hFile: std.os.windows.HANDLE, buffer: []const u8, out_written: *usize) error{WriteFailed}!void {
        var written: usize = 0;
        while (written < buffer.len) {
            const next_write = std.math.cast(u32, buffer.len - written) catch std.math.maxInt(u32);
            var last_written : u32 = undefined;
            const result = std.os.windows.kernel32.WriteFile(hFile, buffer.ptr + written, next_write, &last_written, null);
            written += last_written; // WriteFile always sets last_written to 0 before doing anything
            if (result != 0) {
                out_written.* = written;
                return error.WriteFailed;
            }
        }
        out_written.* = written;
    }
};

// --------------------------------------------------------------------------------
// errno
// --------------------------------------------------------------------------------
export var errno: c_int = 0;

// --------------------------------------------------------------------------------
// stdlib
// --------------------------------------------------------------------------------
export fn abort() callconv(.C) noreturn {
    @panic("abort");
}

// TODO: can name be null?
// TODO: should we detect and do something different if there is a '=' in name?
export fn getenv(name: [*:0]const u8) callconv(.C) ?[*:0]u8 {
    _ = name;
    return null; // not implemented
    //const name_len = std.mem.len(name);
    //var e: ?[*:0]u8 = environ;
}

// --------------------------------------------------------------------------------
// string
// --------------------------------------------------------------------------------
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

export fn strcpy(s1: [*]u8, s2: [*:0]const u8) [*:0]u8 {
    @memcpy(s1, s2, std.mem.len(s2) + 1);
    return std.meta.assumeSentinel(s1, 0);
}

export fn strspn(s1: [*:0]const u8, s2: [*:0]const u8) callconv(.C) usize {
    _ = s1; _ = s2;
    @panic("strspn not implemented");
}

export fn strpbrk(s1: [*:0]const u8, s2: [*:0]const u8) callconv(.C) [*]const u8 {
    _ = s1; _ = s2;
    @panic("strpbrk not implemented");
}

export fn strtod(nptr: [*:0]const u8, endptr: [*][*:0]const u8) callconv(.C) f64 {
    _ = nptr; _ = endptr;
    @panic("strtod not implemented");
}

// --------------------------------------------------------------------------------
// signal
// --------------------------------------------------------------------------------
export fn signal(sig: c_int, func: fn(c_int) callconv(.C) void) void {
    _ = sig;
    _ = func;
    @panic("signal not implemented");
}

// --------------------------------------------------------------------------------
// stdio
// --------------------------------------------------------------------------------
var stdin_storage: c.FILE = .{
    .fd = if (builtin.os.tag == .windows) undefined else std.os.STDIN_FILENO,
    .errno = undefined,
};
var stdout_storage: c.FILE = .{
    .fd = if (builtin.os.tag == .windows) undefined else std.os.STDOUT_FILENO,
    .errno = undefined,
};
var stderr_storage: c.FILE = .{
    .fd = if (builtin.os.tag == .windows) undefined else std.os.STDERR_FILENO,
    .errno = undefined,
};
export const stdin: *c.FILE = &stdin_storage;
export const stdout: *c.FILE = &stdout_storage;
export const stderr: *c.FILE = &stderr_storage;


export fn fputc(character: c_int, stream: *c.FILE) callconv(.C) c_int {
    if (builtin.os.tag == .windows) {
        @panic("fputc not implemented");
    }
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
    if (builtin.os.tag == .windows) {
        var written: usize = undefined;
        windows.writeAll(stream.fd.?, ptr[0 .. size], &written) catch {
            stream.errno = @enumToInt(std.os.windows.kernel32.GetLastError());
        };
        return written;
    }
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
    return fputs(s, stdout);
}

export fn fputs(s: [*:0]const u8, stream: *c.FILE) callconv(.C) c_int {
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

    const written = _fwrite_buf(mem.ptr, mem.len, stream);
    return if (written == 0) c.EOF else 1;
}

export fn fgets(s: [*]u8, n: c_int, stream: *c.FILE) callconv(.C) [*]u8 {
    _ = s; _ = n; _ = stream;
    @panic("fgets not implemented");
}

// --------------------------------------------------------------------------------
// math
// --------------------------------------------------------------------------------
export fn frexp(value: f32, exp: *c_int) callconv(.C) f64 {
    _ = value; _ = exp;
    @panic("frexp not implemented");
}

export fn ldexp(x: f64, exp: c_int) callconv(.C) f64 {
    _ = x; _ = exp;
    @panic("ldexp not implemented");
}

export fn pow(x: f64, y: f64) callconv(.C) f64 {
    _ = x; _ = y;
    @panic("pow not implemented");
}

// --------------------------------------------------------------------------------
// setjmp
// --------------------------------------------------------------------------------
export fn setjmp(env: c.jmp_buf) callconv(.C) c_int {
    _ = env;
    @panic("setjmp not implemented");
}

export fn longjmp(env: c.jmp_buf, val: c_int) callconv(.C) void {
    _ = env; _ = val;
    @panic("longjmp not implemented");
}

// --------------------------------------------------------------------------------
// locale
// --------------------------------------------------------------------------------
export fn localeconv() callconv(.C) *c.lconv {
    @panic("localeconv not implemented");
}

// --------------------------------------------------------------------------------
// time
// --------------------------------------------------------------------------------
export fn time(timer: c.time_t) callconv(.C) c.time_t {
    _ = timer;
    @panic("time not implemented");
}
