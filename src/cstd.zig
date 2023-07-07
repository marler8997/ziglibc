const builtin = @import("builtin");
const std = @import("std");

const c = @cImport({
    // problem with LONG_MIN/LONG_MAX, they are currently assuming 64 bit
    //@cInclude("limits.h");
    @cInclude("errno.h");
    @cInclude("stdio.h");
    @cInclude("stdlib.h");
    @cInclude("setjmp.h");
    @cInclude("locale.h");
    @cInclude("time.h");
    @cInclude("signal.h");
    @cInclude("limits.h");
});

const trace = @import("trace.zig");

// __main appears to be a design inherited by LLVM from gcc.
// it's typically provided by libgcc and is used to call constructors
fn __main() callconv(.C) void {
    stdin.fd = std.os.windows.peb().ProcessParameters.hStdInput;
    stdout.fd = std.os.windows.peb().ProcessParameters.hStdOutput;
    stderr.fd = std.os.windows.peb().ProcessParameters.hStdError;

    // TODO: call constructors
}
comptime {
    if (builtin.os.tag == .windows) @export(__main, .{ .name = "__main" });
}

const windows = struct {
    const HANDLE = std.os.windows.HANDLE;

    // always sets out_written, even if it returns an error
    fn writeAll(hFile: HANDLE, buffer: []const u8, out_written: *usize) error{WriteFailed}!void {
        var written: usize = 0;
        while (written < buffer.len) {
            const next_write = std.math.cast(u32, buffer.len - written) orelse std.math.maxInt(u32);
            var last_written: u32 = undefined;
            const result = std.os.windows.kernel32.WriteFile(hFile, buffer.ptr + written, next_write, &last_written, null);
            written += last_written; // WriteFile always sets last_written to 0 before doing anything
            if (result != 0) {
                out_written.* = written;
                return error.WriteFailed;
            }
        }
        out_written.* = written;
    }
    pub extern "kernel32" fn CreateFileA(
        lpFileName: ?[*:0]const u8,
        dwDesiredAccess: u32,
        dwShareMode: u32,
        lpSecurityAttributes: ?*anyopaque,
        dwCreationDisposition: u32,
        dwFlagsAndAttributes: u32,
        hTemplateFile: ?HANDLE,
    ) callconv(@import("std").os.windows.WINAPI) ?HANDLE;
};

// --------------------------------------------------------------------------------
// errno
// --------------------------------------------------------------------------------
export var errno: c_int = 0;

// --------------------------------------------------------------------------------
// stdlib
// --------------------------------------------------------------------------------
export fn exit(status: c_int) callconv(.C) noreturn {
    trace.log("exit {}", .{status});

    {
        global.atexit_mutex.lock();
        defer global.atexit_mutex.unlock();
        global.atexit_started = true;
    }
    {
        var i = global.atexit_funcs.items.len;
        while (i != 0) : (i -= 1) {
            global.atexit_funcs.items[i - 1]();
        }
    }
    std.os.exit(@intCast(status));
}

const ExitFunc = switch (builtin.zig_backend) {
    .stage1 => fn () callconv(.C) void,
    else => *const fn () callconv(.C) void,
};

export fn atexit(func: ExitFunc) c_int {
    global.atexit_mutex.lock();
    defer global.atexit_mutex.unlock();

    if (global.atexit_started) {
        c.errno = c.EPERM;
        return -1;
    }
    global.atexit_funcs.append(global.gpa.allocator(), func) catch |e| switch (e) {
        error.OutOfMemory => {
            c.errno = c.ENOMEM;
            return -1;
        },
    };
    return 0;
}

export fn abort() callconv(.C) noreturn {
    trace.log("abort", .{});
    @panic("abort");
}

// TODO: can name be null?
// TODO: should we detect and do something different if there is a '=' in name?
export fn getenv(name: [*:0]const u8) callconv(.C) ?[*:0]u8 {
    trace.log("getenv {}", .{trace.fmtStr(name)});
    return null; // not implemented
    //const name_len = std.mem.len(name);
    //var e: ?[*:0]u8 = environ;
}

export fn system(string: ?[*:0]const u8) callconv(.C) c_int {
    trace.log("system {}", .{trace.fmtStr(string)});
    if (string) |_| {
        @panic("system function not implemented");
    } else {
        trace.log("system returning -1 to indicate it is not supported yet", .{});
        // TODO: do we need to set errno?
        return -1; // system not implemented yet
    }
}

/// alloc_align is the maximum alignment needed for all types
/// since malloc is not type aware, it just aligns every allocation
/// to accomodate the maximum possible alignment that could be needed.
///
/// TODO: this should probably be in the zig std library somewhere.
const alloc_align = 16;

const alloc_metadata_len = std.mem.alignForward(usize, alloc_align, @sizeOf(usize));

pub export fn malloc(size: usize) callconv(.C) ?[*]align(alloc_align) u8 {
    trace.log("malloc {}", .{size});
    std.debug.assert(size > 0); // TODO: what should we do in this case?
    const full_len = alloc_metadata_len + size;
    const buf = global.gpa.allocator().alignedAlloc(u8, alloc_align, full_len) catch |err| switch (err) {
        error.OutOfMemory => {
            trace.log("malloc return null", .{});
            return null;
        },
    };
    @as(*usize, @ptrCast(buf)).* = full_len;
    const result = @as([*]align(alloc_align) u8, @ptrFromInt(@intFromPtr(buf.ptr) + alloc_metadata_len));
    trace.log("malloc return {*}", .{result});
    return result;
}

fn getGpaBuf(ptr: [*]u8) []align(alloc_align) u8 {
    const start = @intFromPtr(ptr) - alloc_metadata_len;
    const len = @as(*usize, @ptrFromInt(start)).*;
    return @alignCast(@as([*]u8, @ptrFromInt(start))[0..len]);
}

export fn realloc(ptr: ?[*]align(alloc_align) u8, size: usize) callconv(.C) ?[*]align(alloc_align) u8 {
    trace.log("realloc {*} {}", .{ ptr, size });
    const gpa_buf = getGpaBuf(ptr orelse {
        const result = malloc(size);
        trace.log("realloc return {*} (from malloc)", .{result});
        return result;
    });
    if (size == 0) {
        global.gpa.allocator().free(gpa_buf);
        return null;
    }

    const gpa_size = alloc_metadata_len + size;
    if (global.gpa.allocator().rawResize(gpa_buf, std.math.log2(alloc_align), gpa_size, @returnAddress())) {
        @as(*usize, @ptrCast(gpa_buf.ptr)).* = gpa_size;
        trace.log("realloc return {*}", .{ptr});
        return ptr;
    }

    const new_buf = global.gpa.allocator().reallocAdvanced(
        gpa_buf,
        gpa_size,
        @returnAddress(),
    ) catch |e| switch (e) {
        error.OutOfMemory => {
            trace.log("realloc out-of-mem from {} to {}", .{ gpa_buf.len, gpa_size });
            return null;
        },
    };
    @as(*usize, @ptrCast(new_buf.ptr)).* = gpa_size;
    const result = @as([*]align(alloc_align) u8, @ptrFromInt(@intFromPtr(new_buf.ptr) + alloc_metadata_len));
    trace.log("realloc return {*}", .{result});
    return result;
}

export fn calloc(nmemb: usize, size: usize) callconv(.C) ?[*]align(alloc_align) u8 {
    const total = std.math.mul(usize, nmemb, size) catch {
        // TODO: set errno
        //errno = c.ENOMEM;
        return null;
    };
    const ptr = malloc(total) orelse return null;
    @memset(ptr[0..total], 0);
    return ptr;
}

pub export fn free(ptr: ?[*]align(alloc_align) u8) callconv(.C) void {
    trace.log("free {*}", .{ptr});
    const p = ptr orelse return;
    global.gpa.allocator().free(getGpaBuf(p));
}

export fn srand(seed: c_uint) callconv(.C) void {
    trace.log("srand {}", .{seed});
    global.rand.seed(seed);
}

export fn rand() callconv(.C) c_int {
    return @as(c_int, @bitCast(@as(c_uint, @intCast(global.rand.random().int(std.math.IntFittingRange(0, c.RAND_MAX))))));
}

export fn abs(j: c_int) callconv(.C) c_int {
    return if (j >= 0) j else -j;
}

export fn atoi(nptr: [*:0]const u8) callconv(.C) c_int {
    // TODO: atoi hase some behavior difference on error, get a test for
    //       these differences
    return strto(c_int, nptr, null, 10);
}

// --------------------------------------------------------------------------------
// string
// --------------------------------------------------------------------------------
export fn strlen(s: [*:0]const u8) callconv(.C) usize {
    trace.log("strlen {}", .{trace.fmtStr(s)});
    const result = std.mem.len(s);
    trace.log("strlen return {}", .{result});
    return result;
}
// TODO: strnlen exists in some libc implementations, it might be defined by posix so
//       I should probably move it to the posix lib
fn strnlen(s: [*:0]const u8, max_len: usize) usize {
    trace.log("strnlen {*} max={}", .{ s, max_len });
    var i: usize = 0;
    while (i < max_len and s[i] != 0) : (i += 1) {}
    trace.log("strnlen return {}", .{i});
    return i;
}

export fn strcmp(a: [*:0]const u8, b: [*:0]const u8) callconv(.C) c_int {
    trace.log("strcmp {} {}", .{ trace.fmtStr(a), trace.fmtStr(b) });
    var a_next = a;
    var b_next = b;
    while (a_next[0] == b_next[0] and a_next[0] != 0) {
        a_next += 1;
        b_next += 1;
    }
    const result = @as(c_int, @intCast(a_next[0])) -| @as(c_int, @intCast(b_next[0]));
    trace.log("strcmp return {}", .{result});
    return result;
}

export fn strncmp(a: [*:0]const u8, b: [*:0]const u8, n: usize) callconv(.C) c_int {
    trace.log("strncmp {*} {*} n={}", .{ a, b, n });
    var i: usize = 0;
    while (a[i] == b[i] and a[0] != 0) : (i += 1) {
        if (i == n - 1) return 0;
    }
    return @as(c_int, @intCast(a[i])) -| @as(c_int, @intCast(b[i]));
}

export fn strcoll(s1: [*:0]const u8, s2: [*:0]const u8) callconv(.C) c_int {
    _ = s1;
    _ = s2;
    @panic("strcoll not implemented");
}

export fn strchr(s: [*:0]const u8, char: c_int) callconv(.C) ?[*:0]const u8 {
    trace.log("strchr {} c='{}'", .{ trace.fmtStr(s), char });
    var next = s;
    while (true) : (next += 1) {
        if (next[0] == char) return next;
        if (next[0] == 0) return null;
    }
}
export fn memchr(s: [*]const u8, char: c_int, n: usize) callconv(.C) ?[*]const u8 {
    trace.log("memchr {*} c='{}' n={}", .{ s, char, n });
    var i: usize = 0;
    while (true) : (i += 1) {
        if (i == n) return null;
        if (s[i] == char) return s + i;
    }
}

export fn strrchr(s: [*:0]const u8, char: c_int) callconv(.C) ?[*:0]const u8 {
    trace.log("strrchr {} c='{}'", .{ trace.fmtStr(s), char });
    var next = s + strlen(s);
    while (true) {
        if (next[0] == char) return next;
        if (next == s) return null;
        next = next - 1;
    }
}

export fn strstr(s1: [*:0]const u8, s2: [*:0]const u8) callconv(.C) ?[*:0]const u8 {
    trace.log("strstr {} {}", .{ trace.fmtStr(s1), trace.fmtStr(s2) });
    const s1_len = strlen(s1);
    const s2_len = strlen(s2);
    var i: usize = 0;
    while (i + s2_len <= s1_len) : (i += 1) {
        const search = s1 + i;
        if (0 == strncmp(search, s2, s2_len)) return search;
    }
    return null;
}

export fn strcpy(s1: [*]u8, s2: [*:0]const u8) callconv(.C) [*:0]u8 {
    trace.log("strcpy {*} {*}", .{ s1, s2 });
    @memcpy(s1[0 .. std.mem.len(s2) + 1], s2);
    return @as([*:0]u8, @ptrCast(s1)); // TODO: use std.meta.assumeSentinel if it's brought back
}

// TODO: find out which standard this function comes from
export fn strncpy(s1: [*]u8, s2: [*:0]const u8, n: usize) callconv(.C) [*]u8 {
    trace.log("strncpy {*} {} n={}", .{ s1, trace.fmtStr(s2), n });
    const len = strnlen(s2, n);
    @memcpy(s1[0..len], s2);
    @memset(s1[len..][0 .. n - len], 0);
    return s1;
}

// NOTE: strlcpy and strlcat appear in some libc implementations (rejected by glibc though)
//       they don't appear to be a part of any standard.
//       not sure whether they should live in this library or a separate one
//       see https://lwn.net/Articles/507319/
export fn strlcpy(dst: [*]u8, src: [*:0]const u8, size: usize) callconv(.C) usize {
    trace.log("strncpy {*} {*} n={}", .{ dst, src, size });
    var i: usize = 0;
    while (true) : (i += 1) {
        if (i == size) {
            if (size > 0)
                dst[size - 1] = 0;
            return i + strlen(src + i);
        }
        dst[i] = src[i];
        if (src[i] == 0) {
            return i;
        }
    }
}
export fn strlcat(dst: [*:0]u8, src: [*:0]const u8, size: usize) callconv(.C) usize {
    trace.log("strlcat {} {} n={}", .{ trace.fmtStr(dst), trace.fmtStr(src), size });
    const dst_len = strnlen(dst, size);
    if (dst_len == size) return dst_len + strlen(src);
    return dst_len + strlcpy(dst + dst_len, src, size - dst_len);
}

export fn strncat(s1: [*:0]u8, s2: [*:0]const u8, n: usize) callconv(.C) [*:0]u8 {
    trace.log("strncat {} {} n={}", .{ trace.fmtStr(s1), trace.fmtStr(s2), n });
    const dest = s1 + strlen(s1);
    var i: usize = 0;
    while (s2[i] != 0 and i < n) : (i += 1) {
        dest[i] = s2[i];
    }
    dest[i] = 0;
    return s1;
}

export fn strspn(s1: [*:0]const u8, s2: [*:0]const u8) callconv(.C) usize {
    trace.log("strspn {} {}", .{ trace.fmtStr(s1), trace.fmtStr(s2) });
    var spn: usize = 0;
    while (true) : (spn += 1) {
        if (s1[spn] == 0 or null == strchr(s2, s1[spn])) return spn;
    }
}

export fn strcspn(s1: [*:0]const u8, s2: [*:0]const u8) callconv(.C) usize {
    trace.log("strcspn {} {}", .{ trace.fmtStr(s1), trace.fmtStr(s2) });
    var spn: usize = 0;
    while (true) : (spn += 1) {
        if (s1[spn] == 0 or null != strchr(s2, s1[spn])) return spn;
    }
}

export fn strpbrk(s1: [*:0]const u8, s2: [*:0]const u8) callconv(.C) ?[*]const u8 {
    trace.log("strpbrk {} {}", .{ trace.fmtStr(s1), trace.fmtStr(s2) });
    var next = s1;
    while (true) : (next += 1) {
        if (next[0] == 0) return null;
        if (strchr(s2, next[0]) != null) return next;
    }
}

export fn strtok(s1: ?[*:0]u8, s2: [*:0]const u8) callconv(.C) ?[*:0]u8 {
    if (s1 != null) {
        trace.log("strtok {} {}", .{ trace.fmtStr(s1.?), trace.fmtStr(s2) });
        global.strtok_ptr = s1;
    } else {
        trace.log("strtok NULL {}", .{trace.fmtStr(s2)});
    }
    var next = global.strtok_ptr.?;
    next += strspn(next, s2);
    if (next[0] == 0) {
        return null;
    }
    const start = next;
    const end = start + 1 + strcspn(start + 1, s2);
    if (end[0] == 0) {
        global.strtok_ptr = end;
    } else {
        global.strtok_ptr = end + 1;
        end[0] = 0;
    }
    return start;
}

fn strto(comptime T: type, str: [*:0]const u8, optional_endptr: ?*[*:0]const u8, optional_base: c_int) T {
    var next = str;

    // skip whitespace
    while (isspace(next[0]) != 0) : (next += 1) {}
    const start = next;

    const sign: enum { pos, neg } = blk: {
        if (next[0] == '-') {
            next += 1;
            break :blk .neg;
        }
        if (next[0] == '+') next += 1;
        break :blk .pos;
    };

    const base = blk: {
        if (optional_base != 0) {
            if (optional_base > 36) {
                if (optional_endptr) |endptr| endptr.* = next;
                errno = c.EINVAL;
                return 0;
            }
            if (optional_base == 16 and next[0] == '0' and (next[1] == 'x' or next[1] == 'X')) {
                next += 2;
            }
            break :blk @as(u8, @intCast(optional_base));
        }
        if (next[0] == '0') {
            if (next[1] == 'x' or next[1] == 'X') {
                next += 2;
                break :blk 16;
            }
            next += 1;
            break :blk 8;
        }
        break :blk 10;
    };

    var digit_start = next;
    var x: T = 0;

    while (true) : (next += 1) {
        const ch = next[0];
        if (ch == 0) break;
        const digit = std.math.cast(T, std.fmt.charToDigit(ch, base) catch break) orelse {
            if (optional_endptr) |endptr| endptr.* = next;
            errno = c.ERANGE;
            return 0;
        };
        if (x != 0) x = std.math.mul(T, x, std.math.cast(T, base) orelse {
            errno = c.EINVAL;
            return 0;
        }) catch {
            if (optional_endptr) |endptr| endptr.* = next;
            errno = c.ERANGE;
            return switch (sign) {
                .neg => std.math.minInt(T),
                .pos => std.math.maxInt(T),
            };
        };
        x = switch (sign) {
            .pos => std.math.add(T, x, digit) catch {
                if (optional_endptr) |endptr| endptr.* = next + 1;
                errno = c.ERANGE;
                return switch (sign) {
                    .neg => std.math.minInt(T),
                    .pos => std.math.maxInt(T),
                };
            },
            .neg => std.math.sub(T, x, digit) catch {
                if (optional_endptr) |endptr| endptr.* = next + 1;
                errno = c.ERANGE;
                return switch (sign) {
                    .neg => std.math.minInt(T),
                    .pos => std.math.maxInt(T),
                };
            },
        };
    }

    if (optional_endptr) |endptr| endptr.* = next;
    if (next == digit_start) {
        errno = c.EINVAL; // TODO: is this right?
    } else {
        trace.log("strto str='{s}' result={}", .{ start[0 .. @intFromPtr(next) - @intFromPtr(start)], x });
    }
    return x;
}

export fn strtod(nptr: [*:0]const u8, endptr: ?*[*:0]const u8) callconv(.C) f64 {
    trace.log("strtod {}", .{trace.fmtStr(nptr)});
    const str_len: usize = if (endptr) |e| @intFromPtr(e.*) - @intFromPtr(nptr) else std.mem.len(nptr);
    if (str_len == 0) {
        return 0;
    }
    const result = std.fmt.parseFloat(f64, nptr[0..str_len]) catch |err| switch (err) {
        error.InvalidCharacter => {
            std.debug.panic("todo: strtod handle InvalidCharacter for '{s}'", .{nptr[0..str_len]});
        },
    };
    return result;
}

export fn strtol(nptr: [*:0]const u8, endptr: ?*[*:0]const u8, base: c_int) callconv(.C) c_long {
    trace.log("strtol {} endptr={*} base={}", .{ trace.fmtStr(nptr), endptr, base });
    return strto(c_long, nptr, endptr, base);
}

export fn strtoll(nptr: [*:0]const u8, endptr: ?*[*:0]const u8, base: c_int) callconv(.C) c_longlong {
    trace.log("strtoll {s} endptr={*} base={}", .{ trace.fmtStr(nptr), endptr, base });
    return strto(c_longlong, nptr, endptr, base);
}

export fn strtoul(nptr: [*:0]const u8, endptr: ?*[*:0]u8, base: c_int) callconv(.C) c_ulong {
    trace.log("strtoul {} endptr={*} base={}", .{ trace.fmtStr(nptr), endptr, base });
    return strto(c_ulong, nptr, endptr, base);
}

export fn strtoull(nptr: [*:0]const u8, endptr: ?*[*:0]u8, base: c_int) callconv(.C) c_ulonglong {
    trace.log("strtoull {} endptr={*} base={}", .{ trace.fmtStr(nptr), endptr, base });
    return strto(c_ulonglong, nptr, endptr, base);
}

export fn strerror(errnum: c_int) callconv(.C) [*:0]const u8 {
    std.log.warn("sterror (num={}) not implemented", .{errnum});
    _ = std.fmt.bufPrint(&global.tmp_strerror_buffer, "{}", .{errnum}) catch @panic("BUG");
    return @as([*:0]const u8, @ptrCast(&global.tmp_strerror_buffer)); // TODO: use std.meta.assumeSentinel if it's brought back
}

// --------------------------------------------------------------------------------
// signal
// --------------------------------------------------------------------------------
const SignalFn = switch (builtin.zig_backend) {
    .stage1 => fn (c_int) callconv(.C) void,
    else => *const fn (c_int) callconv(.C) void,
};
export fn signal(sig: c_int, func: SignalFn) callconv(.C) ?SignalFn {
    if (builtin.os.tag == .windows) {
        // TODO: maybe we can emulate/handle some signals?
        trace.log("ignoring the 'signal' function (sig={}) on windows", .{sig});
        return null;
    }
    if (builtin.os.tag == .linux) {
        var action = std.os.Sigaction{
            .handler = .{ .handler = func },
            .mask = std.os.linux.empty_sigset,
            .flags = std.os.SA.RESTART,
            .restorer = null,
        };
        var old_action: std.os.Sigaction = undefined;
        switch (std.os.errno(std.os.linux.sigaction(
            @as(u6, @intCast(sig)),
            &action,
            &old_action,
        ))) {
            .SUCCESS => return old_action.handler.handler,
            else => |e| {
                errno = @intFromEnum(e);
                // translate-c having a hard time with this one
                //return c.SIG_ERR;
                return @as(?SignalFn, @ptrFromInt(@as(usize, @bitCast(@as(isize, -1)))));
            },
        }
    }
    @panic("signal not implemented");
}

// --------------------------------------------------------------------------------
// stdio
// --------------------------------------------------------------------------------
const global = struct {
    var rand: std.rand.DefaultPrng = undefined;

    var gpa = std.heap.GeneralPurposeAllocator(.{
        .MutexType = std.Thread.Mutex,
    }){};

    var strtok_ptr: ?[*:0]u8 = undefined;

    // TODO: remove this global limit on file handles
    //       probably do an array of pages holding the file objects.
    //       the address to any file can be done in O(1) by decoding
    //       the page index and file offset
    const max_file_count = 100;
    var files_reserved: [max_file_count]bool = [_]bool{false} ** max_file_count;
    var files: [max_file_count]c.FILE = [_]c.FILE{
        .{ .fd = if (builtin.os.tag == .windows) undefined else std.os.STDIN_FILENO, .eof = 0, .errno = undefined },
        .{ .fd = if (builtin.os.tag == .windows) undefined else std.os.STDOUT_FILENO, .eof = 0, .errno = undefined },
        .{ .fd = if (builtin.os.tag == .windows) undefined else std.os.STDERR_FILENO, .eof = 0, .errno = undefined },
    } ++ ([_]c.FILE{undefined} ** (max_file_count - 3));

    fn reserveFile() *c.FILE {
        var i: usize = 0;
        while (i < files_reserved.len) : (i += 1) {
            if (!@atomicRmw(bool, &files_reserved[i], .Xchg, true, .SeqCst)) {
                return &files[i];
            }
        }
        @panic("out of file handles");
    }
    fn releaseFile(file: *c.FILE) void {
        const i = (@intFromPtr(file) - @intFromPtr(&files[0])) / @sizeOf(usize);
        if (!@atomicRmw(bool, &files_reserved[i], .Xchg, false, .SeqCst)) {
            std.debug.panic("released FILE (i={} ptr={*}) that was not reserved", .{ i, file });
        }
    }

    // TODO: remove this.  Just using it to return error numbers as strings for now
    var tmp_strerror_buffer: [30]u8 = undefined;

    var atexit_mutex = std.Thread.Mutex{};
    var atexit_started = false;
    // TODO: these don't need to be contiguous, use a chain of fixed size chunks
    //       that don't need to move/be resized ChunkedArrayList or something
    var atexit_funcs: std.ArrayListUnmanaged(ExitFunc) = .{};

    var decimal_point = [_:0]u8{'.'};
    var thousands_sep = [_:0]u8{};
    var grouping = [_:0]u8{};
    var int_curr_symbol = [_:0]u8{};
    var currency_symbol = [_:0]u8{};
    var mon_decimal_point = [_:0]u8{};
    var mon_thousands_sep = [_:0]u8{};
    var mon_grouping = [_:0]u8{};
    var positive_sign = [_:0]u8{};
    var negative_sign = [_:0]u8{};
    var localeconv = c.struct_lconv{
        .decimal_point = &decimal_point,
        .thousands_sep = &thousands_sep,
        .grouping = &grouping,
        .int_curr_symbol = &int_curr_symbol,
        .currency_symbol = &currency_symbol,
        .mon_decimal_point = &mon_decimal_point,
        .mon_thousands_sep = &mon_thousands_sep,
        .mon_grouping = &mon_grouping,
        .positive_sign = &positive_sign,
        .negative_sign = &negative_sign,
        .int_frac_digits = c.CHAR_MAX,
        .frac_digits = c.CHAR_MAX,
        .p_cs_precedes = c.CHAR_MAX,
        .p_sep_by_space = c.CHAR_MAX,
        .n_cs_precedes = c.CHAR_MAX,
        .n_sep_by_space = c.CHAR_MAX,
        .p_sign_posn = c.CHAR_MAX,
        .n_sign_posn = c.CHAR_MAX,
    };
};

export const stdin: *c.FILE = &global.files[0];
export const stdout: *c.FILE = &global.files[1];
export const stderr: *c.FILE = &global.files[2];

// used by posix.zig
export fn __zreserveFile() callconv(.C) ?*c.FILE {
    return global.reserveFile();
}

export fn remove(filename: [*:0]const u8) callconv(.C) c_int {
    trace.log("remove {}", .{trace.fmtStr(filename)});
    @panic("remove not implemented");
}

export fn rename(old: [*:0]const u8, new: [*:0]const u8) callconv(.C) c_int {
    trace.log("remove {} {}", .{ trace.fmtStr(old), trace.fmtStr(new) });
    @panic("rename not implemented");
}

export fn getchar() callconv(.C) c_int {
    return getc(stdin);
}

export fn getc(stream: *c.FILE) callconv(.C) c_int {
    if (stream.eof != 0) @panic("getc, eof not 0 not implemented");
    trace.log("getc {*}", .{stream});

    if (builtin.os.tag == .windows) {
        var buf: [1]u8 = undefined;
        const len = _fread_buf(&buf, 1, stream);
        if (len == 0) return c.EOF;
        std.debug.assert(len == 1);
        return buf[0];
    }

    var buf: [1]u8 = undefined;
    const rc = std.os.system.read(stream.fd, &buf, 1);
    if (rc == 1) {
        trace.log("getc return {}", .{buf[0]});
        return buf[0];
    }
    stream.errno = if (rc == 0) 0 else @intFromEnum(std.os.errno(rc));
    trace.log("getc return EOF, errno={}", .{stream.errno});
    return c.EOF;
}

// NOTE: this causes a bug in the Zig compiler, but it shouldn't
//       for now I'm working around it by making a wrapper function
//comptime {
//    @export(getc, .{ .name = "fgetc" });
//}
export fn fgetc(stream: *c.FILE) callconv(.C) c_int {
    return getc(stream);
}

export fn ungetc(char: c_int, stream: *c.FILE) callconv(.C) c_int {
    if (stream.eof != 0) @panic("ungetc, eof not 0 not implemented");
    _ = char;
    @panic("ungetc not implemented");
}

export fn _fread_buf(ptr: [*]u8, size: usize, stream: *c.FILE) callconv(.C) usize {
    // TODO: should I check stream.eof here?

    if (builtin.os.tag == .windows) {
        const actual_read_len = @as(u32, @intCast(@min(@as(u32, std.math.maxInt(u32)), size)));
        while (true) {
            var amt_read: u32 = undefined;
            // TODO: is stream.fd.? right?
            if (std.os.windows.kernel32.ReadFile(stream.fd.?, ptr, actual_read_len, &amt_read, null) == 0) {
                switch (std.os.windows.kernel32.GetLastError()) {
                    .OPERATION_ABORTED => continue,
                    .BROKEN_PIPE => return 0,
                    .HANDLE_EOF => return 0,
                    else => |err| std.debug.panic("ReadFile unexpected error {}", .{err}),
                }
            }
            return @as(usize, @intCast(amt_read));
        }
    }

    // Prevents EINVAL.
    const max_count = switch (builtin.os.tag) {
        .linux => 0x7ffff000,
        .macos, .ios, .watchos, .tvos => std.math.maxInt(i32),
        else => std.math.maxInt(isize),
    };
    const adjusted_len = @min(max_count, size);

    const rc = std.os.system.read(stream.fd, ptr, adjusted_len);
    switch (std.os.errno(rc)) {
        .SUCCESS => {
            if (rc == 0) stream.eof = 1;
            return @as(usize, @intCast(rc));
        },
        else => |e| {
            errno = @intFromEnum(e);
            return 0;
        },
    }
}

export fn fread(ptr: [*]u8, size: usize, nmemb: usize, stream: *c.FILE) callconv(.C) usize {
    if (stream.eof != 0) @panic("fread, eof not 0 not implemented");
    const total = size * nmemb;
    const result = _fread_buf(ptr, total, stream);
    if (result == 0) return 0;
    if (result == total) return nmemb;
    // TODO: if length read is not aligned then we need to leave it
    //       in an internal read buffer inside FILE
    //       for now we'll crash if it's not aligned
    return @divExact(result, size);
}

export fn feof(stream: *c.FILE) callconv(.C) c_int {
    return stream.eof;
}

pub export fn fopen(filename: [*:0]const u8, mode: [*:0]const u8) callconv(.C) ?*c.FILE {
    trace.log("fopen {} mode={}", .{ trace.fmtStr(filename), trace.fmtStr(mode) });
    if (builtin.os.tag == .windows) {
        var create_disposition: u32 = std.os.windows.OPEN_EXISTING;
        var access: u32 = 0;
        for (std.mem.span(mode)) |mode_char| {
            if (mode_char == 'r') {
                access |= std.os.windows.GENERIC_READ;
            } else if (mode_char == 'w') {
                access |= std.os.windows.GENERIC_WRITE;
                create_disposition = std.os.windows.CREATE_ALWAYS;
            } else if (mode_char == 'b') {
                // not really sure what this is supposed to do yet, ignore it for now
            } else {
                std.debug.panic("unhandled open flag '{c}' (from {})", .{ mode_char, trace.fmtStr(mode) });
            }
        }
        const fd = windows.CreateFileA(
            filename,
            access,
            std.os.windows.FILE_SHARE_DELETE |
                std.os.windows.FILE_SHARE_READ |
                std.os.windows.FILE_SHARE_WRITE,
            null,
            create_disposition,
            std.os.windows.FILE_ATTRIBUTE_NORMAL,
            null,
        );
        if (fd == std.os.windows.INVALID_HANDLE_VALUE) {
            // TODO: do I need to set errno?
            errno = @intFromEnum(std.os.windows.kernel32.GetLastError());
            return null;
        }
        const file = global.reserveFile();
        file.fd = fd;
        file.eof = 0;
        return file;
    }

    var flags: u32 = 0;
    for (std.mem.span(mode)) |mode_char| {
        if (mode_char == 'r') {
            flags |= std.os.O.RDONLY;
        } else if (mode_char == 'w') {
            flags |= std.os.O.WRONLY | std.os.O.CREAT | std.os.O.TRUNC;
        } else if (mode_char == 'b') {
            // not really sure what this is supposed to do yet, ignore it for now
        } else {
            std.debug.panic("unhandled open flag '{c}' (from {})", .{ mode_char, trace.fmtStr(mode) });
        }
    }
    const fd = std.os.system.open(filename, flags, 0o666);
    switch (std.os.errno(fd)) {
        .SUCCESS => {},
        else => |e| {
            errno = @intFromEnum(e);
            trace.log("fopen return null (errno={})", .{errno});
            return null;
        },
    }
    const file = global.reserveFile();
    file.fd = @as(c_int, @intCast(fd));
    file.eof = 0;
    return file;
}

export fn freopen(filename: [*:0]const u8, mode: [*:0]const u8, stream: *c.FILE) callconv(.C) *c.FILE {
    _ = filename;
    _ = mode;
    _ = stream;
    @panic("freopen not implemented");
}

export fn fclose(stream: *c.FILE) callconv(.C) c_int {
    trace.log("fclose {*}", .{stream});
    if (builtin.os.tag == .windows) {
        std.os.close(stream.fd.?);
    } else {
        std.os.close(stream.fd);
    }
    global.releaseFile(stream);
    return 0;
}

export fn fseek(stream: *c.FILE, offset: c_long, whence: c_int) callconv(.C) c_int {
    // TODO: update eof when applicable
    trace.log("fseek {*} offset={} whence={}", .{ stream, offset, whence });

    if (builtin.os.tag == .windows) {
        @panic("fseek not implemented on Windows");
    }

    // woraround error in std/os/linux.zig: error: destination type 'usize' has size 4 but source type 'i64' has size 8
    // return syscall3(.lseek, @bitCast(usize, @as(isize, fd)), @bitCast(usize, offset), whence);
    //                                                                   ^
    if (@sizeOf(usize) == 4) @panic("not implemented");
    const rc = std.os.system.lseek(stream.fd, @as(i64, @intCast(offset)), @as(usize, @intCast(whence)));
    switch (std.os.errno(rc)) {
        .SUCCESS => return 0,
        else => |e| {
            errno = @intFromEnum(e);
            return -1;
        },
    }
}

export fn ftell(stream: *c.FILE) callconv(.C) c_long {
    _ = stream;
    @panic("ftell not implemented");
}

export fn rewind(stream: *c.FILE) callconv(.C) void {
    trace.log("rewind {*}", .{stream});
    if (0 == fseek(stream, 0, c.SEEK_SET)) {
        stream.eof = 0;
        stream.errno = 0;
    }
    // TODO: should we set stream.errno if fseek failed?
}

// TODO: why is there a putc and an fputc function? They seem to be equivalent
//       so what's the history?
comptime {
    @export(fputc, .{ .name = "putc" });
}

export fn fputc(character: c_int, stream: *c.FILE) callconv(.C) c_int {
    trace.log("fputc {} stream={*}", .{ character, stream });
    if (builtin.os.tag == .windows) {
        @panic("fputc not implemented");
    }
    const buf = [_]u8{@as(u8, @intCast(0xff & character))};
    const written = std.os.system.write(stream.fd, &buf, 1);
    switch (std.os.errno(written)) {
        .SUCCESS => {
            if (written == 1) return character;
            stream.errno = @intFromEnum(std.os.E.IO);
            return c.EOF;
        },
        else => |e| {
            stream.errno = @intFromEnum(e);
            return c.EOF;
        },
    }
}

// NOTE: this is not apart of libc
export fn _fwrite_buf(ptr: [*]const u8, size: usize, stream: *c.FILE) callconv(.C) usize {
    if (builtin.os.tag == .windows) {
        var written: usize = undefined;
        windows.writeAll(stream.fd.?, ptr[0..size], &written) catch {
            stream.errno = @intFromEnum(std.os.windows.kernel32.GetLastError());
        };
        return written;
    }
    const written = std.os.system.write(stream.fd, ptr, size);
    switch (std.os.errno(written)) {
        .SUCCESS => {
            if (written != size) {
                stream.errno = @intFromEnum(std.os.E.IO);
            }
            return written;
        },
        else => |e| {
            stream.errno = @intFromEnum(e);
            return 0;
        },
    }
}

// TODO: can ptr be NULL?
// TODO: can stream be NULL (I don't think it can)
export fn fwrite(ptr: [*]const u8, size: usize, nmemb: usize, stream: *c.FILE) callconv(.C) usize {
    trace.log("fwrite {*} size={} n={} stream={*}", .{ ptr, size, nmemb, stream });
    const total = size * nmemb;
    const result = _fwrite_buf(ptr, total, stream);
    if (result == total) return nmemb;
    return result / size;
}

export fn fflush(stream: ?*c.FILE) callconv(.C) c_int {
    trace.log("fflush {*}", .{stream});
    return 0; // no-op since there's no buffering right now
}

export fn putchar(ch: c_int) callconv(.C) c_int {
    trace.log("putchar {}", .{ch});
    const buf = [_]u8{@as(u8, @intCast(ch & 0xff))};
    return if (1 == _fwrite_buf(&buf, 1, stdout)) buf[0] else c.EOF;
}

export fn puts(s: [*:0]const u8) callconv(.C) c_int {
    trace.log("puts {}", .{trace.fmtStr(s)});
    return fputs(s, stdout);
}

export fn fputs(s: [*:0]const u8, stream: *c.FILE) callconv(.C) c_int {
    trace.log("fputs {} stream={*}", .{ trace.fmtStr(s), stream });
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
    @memcpy(mem, s);
    mem[len] = '\n';

    const written = _fwrite_buf(mem.ptr, mem.len, stream);
    return if (written == 0) c.EOF else 1;
}

export fn fgets(s: [*]u8, n: c_int, stream: *c.FILE) callconv(.C) ?[*]u8 {
    if (stream.eof != 0) return null;

    // TODO: this implementation is very slow/inefficient
    var total_read: usize = 0;
    while (true) : (total_read += 1) {
        if (total_read + 1 >= n) {
            s[total_read] = 0;
            return s;
        }
        stream.errno = 0;
        const result = getc(stream);
        if (result == c.EOF) {
            if (stream.errno == 0) {
                stream.eof = 1;
                if (total_read > 0) {
                    s[total_read] = 0;
                    return s;
                }
            }
            return null;
        }
        s[total_read] = @as(u8, @intCast(result));
        if (s[total_read] == '\n') {
            s[total_read + 1] = 0;
            return s;
        }
    }
}

export fn tmpfile() callconv(.C) *c.FILE {
    @panic("tmpfile not implemented");
}

export fn tmpnam(s: [*]u8) callconv(.C) [*]u8 {
    _ = s;
    @panic("tmpnam not implemented");
}

export fn clearerr(stream: *c.FILE) callconv(.C) void {
    trace.log("clearerr {*}", .{stream});
    stream.errno = 0;
}

export fn setvbuf(stream: *c.FILE, buf: ?[*]u8, mode: c_int, size: usize) callconv(.C) c_int {
    _ = stream;
    _ = buf;
    _ = mode;
    _ = size;
    @panic("setvbuf not implemented");
}

export fn ferror(stream: *c.FILE) callconv(.C) c_int {
    trace.log("ferror {*} return {}", .{ stream, stream.errno });
    return stream.errno;
}

export fn perror(s: [*:0]const u8) callconv(.C) void {
    trace.log("perror {}", .{trace.fmtStr(s)});
    @panic("perror not implemented");
}

// NOTE: this is not a libc function, it's exported so it can be used
//       by vformat in libc.c
// buf must be at least 100 bytes
export fn _formatCInt(buf: [*]u8, value: c_int, base: u8) callconv(.C) usize {
    return std.fmt.formatIntBuf(buf[0..100], value, base, .lower, .{});
}
export fn _formatCUint(buf: [*]u8, value: c_uint, base: u8) callconv(.C) usize {
    return std.fmt.formatIntBuf(buf[0..100], value, base, .lower, .{});
}
export fn _formatCLong(buf: [*]u8, value: c_long, base: u8) callconv(.C) usize {
    return std.fmt.formatIntBuf(buf[0..100], value, base, .lower, .{});
}
export fn _formatCUlong(buf: [*]u8, value: c_ulong, base: u8) callconv(.C) usize {
    return std.fmt.formatIntBuf(buf[0..100], value, base, .lower, .{});
}
export fn _formatCLonglong(buf: [*]u8, value: c_longlong, base: u8) callconv(.C) usize {
    return std.fmt.formatIntBuf(buf[0..100], value, base, .lower, .{});
}
export fn _formatCUlonglong(buf: [*]u8, value: c_ulonglong, base: u8) callconv(.C) usize {
    return std.fmt.formatIntBuf(buf[0..100], value, base, .lower, .{});
}

// --------------------------------------------------------------------------------
// math
// --------------------------------------------------------------------------------
export fn acos(x: f64) callconv(.C) f64 {
    _ = x;
    @panic("acos not implemented");
}

export fn asin(x: f64) callconv(.C) f64 {
    _ = x;
    @panic("asin not implemented");
}

export fn atan(x: f64) callconv(.C) f64 {
    _ = x;
    @panic("atan not implemented");
}

export fn atan2(y: f64, x: f64) callconv(.C) f64 {
    _ = y;
    _ = x;
    @panic("atan2 not implemented");
}

// cos/sin are already defined somewhere in the libraries Zig includes
// on linux, not sure what library though or how

export fn tan(x: f64) callconv(.C) f64 {
    _ = x;
    @panic("tan not implemented");
}

export fn frexp(value: f32, exp: *c_int) callconv(.C) f64 {
    // TODO: look into error handling to match C spec
    const result = std.math.frexp(value);
    exp.* = result.exponent;
    return result.significand;
}

export fn ldexp(x: f64, exp: c_int) callconv(.C) f64 {
    // TODO: look into error handling to match C spec
    return std.math.ldexp(x, @as(i32, @intCast(exp)));
}

export fn pow(x: f64, y: f64) callconv(.C) f64 {
    // TODO: look into error handling to match C spec
    return std.math.pow(f64, x, y);
}

// --------------------------------------------------------------------------------
// locale
// --------------------------------------------------------------------------------
export fn setlocale(category: c_int, locale: [*:0]const u8) callconv(.C) [*:0]u8 {
    _ = category;
    _ = locale;
    @panic("setlocale not implemented");
}

export fn localeconv() callconv(.C) *c.lconv {
    trace.log("localeconv", .{});
    return &global.localeconv;
}

// --------------------------------------------------------------------------------
// time
// --------------------------------------------------------------------------------
export fn clock() callconv(.C) c.clock_t {
    @panic("clock not implemented");
}

export fn difftime(time1: c.time_t, time0: c.time_t) callconv(.C) f64 {
    _ = time1;
    _ = time0;
    @panic("difftime not implemented");
}

export fn mktime(timeptr: *c.tm) callconv(.C) c.time_t {
    _ = timeptr;
    @panic("mktime not implemented");
}

export fn time(timer: ?*c.time_t) callconv(.C) c.time_t {
    trace.log("time {*}", .{timer});
    const now_zig = std.time.timestamp();
    const now = @as(c.time_t, @intCast(std.math.boolMask(c.time_t, true) & now_zig));
    if (timer) |_| {
        timer.?.* = now;
    }
    trace.log("time return {}", .{now});
    return now;
}

export fn gmtime(timer: *c.time_t) callconv(.C) *c.tm {
    _ = timer;
    @panic("gmtime not implemented");
}

export fn localtime(timer: *const c.time_t) callconv(.C) *c.tm {
    _ = timer;
    @panic("localtime not implemented");
}

export fn strftime(s: [*]u8, maxsize: usize, format: [*:0]const u8, timeptr: *const c.tm) callconv(.C) usize {
    _ = s;
    _ = maxsize;
    _ = format;
    _ = timeptr;
    @panic("strftime not implemented");
}

// --------------------------------------------------------------------------------
// ctype
// --------------------------------------------------------------------------------
export fn isalnum(char: c_int) callconv(.C) c_int {
    trace.log("isalnum {}", .{char});
    return @intFromBool(std.ascii.isAlphanumeric(std.math.cast(u8, char) orelse return 0));
}

export fn toupper(char: c_int) callconv(.C) c_int {
    trace.log("toupper {}", .{char});
    return std.ascii.toUpper(std.math.cast(u8, char) orelse return char);
}

export fn tolower(char: c_int) callconv(.C) c_int {
    trace.log("tolower {}", .{char});
    return std.ascii.toLower(std.math.cast(u8, char) orelse return char);
}

export fn isspace(char: c_int) callconv(.C) c_int {
    trace.log("isspace {}", .{char});
    return @intFromBool(std.ascii.isWhitespace(std.math.cast(u8, char) orelse return 0));
}

export fn isxdigit(char: c_int) callconv(.C) c_int {
    trace.log("isxdigit {}", .{char});
    return @intFromBool(std.ascii.isHex(std.math.cast(u8, char) orelse return 0));
}

export fn iscntrl(char: c_int) callconv(.C) c_int {
    trace.log("iscntrl {}", .{char});
    return @intFromBool(std.ascii.isControl(std.math.cast(u8, char) orelse return 0));
}

export fn isdigit(char: c_int) callconv(.C) c_int {
    trace.log("isdigit {}", .{char});
    return @intFromBool(std.ascii.isDigit(std.math.cast(u8, char) orelse return 0));
}

export fn isalpha(char: c_int) callconv(.C) c_int {
    trace.log("isalhpa {}", .{char});
    return @intFromBool(std.ascii.isAlphabetic(std.math.cast(u8, char) orelse return 0));
}

export fn isgraph(char: c_int) callconv(.C) c_int {
    trace.log("isgraph {}", .{char});
    return @intFromBool(std.ascii.isPrint(std.math.cast(u8, char) orelse return 0));
}

export fn islower(char: c_int) callconv(.C) c_int {
    trace.log("islower {}", .{char});
    return @intFromBool(std.ascii.isLower(std.math.cast(u8, char) orelse return 0));
}

export fn isupper(char: c_int) callconv(.C) c_int {
    trace.log("isupper {}", .{char});
    return @intFromBool(std.ascii.isUpper(std.math.cast(u8, char) orelse return 0));
}

export fn ispunct(char: c_int) callconv(.C) c_int {
    trace.log("ispunct {}", .{char});
    const c_u8 = std.math.cast(u8, char) orelse return 0;
    return @intFromBool(std.ascii.isPrint(c_u8) and !std.ascii.isAlphanumeric(c_u8));
}

export fn isprint(char: c_int) callconv(.C) c_int {
    trace.log("isprint {}", .{char});
    return @intFromBool(std.ascii.isPrint(std.math.cast(u8, char) orelse return 0));
}

// --------------------------------------------------------------------------------
// assert
// --------------------------------------------------------------------------------
export fn __zassert_fail(
    expression: [*:0]const u8,
    file: [*:0]const u8,
    line: c_int,
    func: [*:0]const u8,
) callconv(.C) void {
    trace.log("assert failed '{s}' ('{s}' line {d} function '{s}')", .{ expression, file, line, func });
    abort();
}

// --------------------------------------------------------------------------------
// setjmp
// --------------------------------------------------------------------------------
fn setjmp(env: c.jmp_buf) callconv(.C) c_int {
    _ = env;
    @panic("setjmp not implemented on this platform yet");
}
fn longjmp(env: c.jmp_buf, val: c_int) callconv(.C) noreturn {
    _ = env;
    _ = val;
    @panic("longjmp not implemented on this platform yet");
}
comptime {
    // temporary to get windows to link for now
    if (builtin.os.tag == .windows) {
        @export(setjmp, .{ .name = "setjmp" });
        @export(longjmp, .{ .name = "longjmp" });
    }
}
