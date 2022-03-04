const builtin = @import("builtin");
const std = @import("std");

const c = @cImport({
    @cInclude("stdio.h");
    @cInclude("setjmp.h");
    @cInclude("locale.h");
    @cInclude("time.h");
});

fn trace(comptime fmt: []const u8, args: anytype) void {
    _ = fmt;
    _ = args;
    //std.log.scoped(.trace).info(fmt, args);
}

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
            const next_write = std.math.cast(u32, buffer.len - written) catch std.math.maxInt(u32);
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
    pub extern "KERNEL32" fn CreateFileA(
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
export fn exit(status: c_int) noreturn {
    trace("exit {}", .{status});
    std.os.exit(@intCast(u8, status));
}

export fn abort() callconv(.C) noreturn {
    trace("abort", .{});
    @panic("abort");
}

// TODO: can name be null?
// TODO: should we detect and do something different if there is a '=' in name?
export fn getenv(name: [*:0]const u8) callconv(.C) ?[*:0]u8 {
    trace("getenv '{s}'", .{std.mem.span(name)});
    _ = name;
    return null; // not implemented
    //const name_len = std.mem.len(name);
    //var e: ?[*:0]u8 = environ;
}

export fn system(string: [*:0]const u8) callconv(.C) c_int {
    trace("system '{s}'", .{std.mem.span(string)});
    _ = string;
    @panic("system function not implemented");
}

/// alloc_align is the maximum alignment needed for all types
/// since malloc is not type aware, it just aligns every allocation
/// to accomodate the maximum possible alignment that could be needed.
///
/// TODO: this should probably be in the zig std library somewhere.
const alloc_align = 16;

const alloc_metadata_len = std.mem.alignForward(@sizeOf(usize), alloc_align);

export fn malloc(size: usize) callconv(.C) ?[*]align(alloc_align) u8 {
    trace("malloc {}", .{size});
    std.debug.assert(size > 0); // TODO: what should we do in this case?
    const full_len = alloc_metadata_len + size;
    const buf = global.gpa.allocator().alignedAlloc(u8, alloc_align, full_len) catch |err| switch (err) {
        error.OutOfMemory => {
            trace("malloc return null", .{});
            return null;
        },
    };
    @ptrCast(*usize, buf).* = full_len;
    const result = @intToPtr([*]align(alloc_align) u8, @ptrToInt(buf.ptr) + alloc_metadata_len);
    trace("malloc return {*}", .{result});
    return result;
}

fn getGpaBuf(ptr: [*]u8) []align(alloc_align) u8 {
    const start = @ptrToInt(ptr) - alloc_metadata_len;
    const len = @intToPtr(*usize, start).*;
    return @alignCast(alloc_align, @intToPtr([*]u8, start)[0 .. len]);
}

export fn realloc(ptr: ?[*]align(alloc_align) u8, size: usize) callconv(.C) ?[*]align(alloc_align) u8 {
    trace("realloc {*} {}", .{ptr, size});
    const buf = getGpaBuf(ptr orelse {
        const result = malloc(size);
        trace("realloc return {*} (from malloc)", .{result});
        return result;
    });
    if (size == 0) {
        global.gpa.allocator().free(buf);
        trace("realloc return null", .{});
        return null;
    }
    if (size <= buf.len) {
        const result = global.gpa.allocator().rawResize(buf, alloc_align, size, 1, @returnAddress());
        std.debug.assert(result == size);
        trace("realloc return {*}", .{ptr});
        return ptr;
    }
    @panic("realloc not implemented");
}

export fn free(ptr: ?[*]align(alloc_align) u8) callconv(.C) void {
    trace("free {*}", .{ptr});
    const p = ptr orelse return;
    global.gpa.allocator().free(getGpaBuf(p));
}

// --------------------------------------------------------------------------------
// string
// --------------------------------------------------------------------------------
export fn strlen(s: [*:0]const u8) callconv(.C) usize {
    trace("strlen {}", .{fmtTraceStr(s)});
    const result = std.mem.len(s);
    trace("strlen return {}", .{result});
    return result;
}
// TODO: strnlen exists in some libc implementations, it might be defined by posix so
//       I should probably move it to the posix lib
fn strnlen(s: [*:0]const u8, max_len: usize) usize {
    trace("strnlen {*} max={}", .{s, max_len});
    var i: usize = 0;
    while (i < max_len and s[i] != 0) : (i += 1) { }
    trace("strnlen return {}", .{i});
    return i;
}

fn fmtTraceStr(s: anytype) FmtTraceStr {
    switch (@typeInfo(@TypeOf(s))) {
        .Pointer => |info| switch (info.size) {
            .Slice => return FmtTraceStr.initSlice(s),
            .Many => if (info.sentinel) |_| {
                return FmtTraceStr.initSentinel(s);
            },
            else => {},
        },
        else => {},
    }
    @compileError("fmtTraceStr for type " ++ @typeName(@TypeOf(s)) ++ " is not implemented");
}
const FmtTraceStr = struct {
    const max_str_len = 20;

    ptr: [*]const u8,
    len: union(enum) {
        full: u8,
        truncated: void,
    },

    pub fn initSlice(s: []const u8) FmtTraceStr {
        if (s.len > max_str_len) {
            return .{ .ptr = s.ptr, .len = .truncated };
        }
        return .{ .ptr = s.ptr, .len = .{ .len = @intCast(u8, s.len) } };
    }

    pub fn initSentinel(s: [*:0]const u8) FmtTraceStr {
        var len: u8 = 0;
        while (len <= max_str_len) : (len += 1) {
            if (s[len] == 0)
                return .{ .ptr = s, .len = .{ .full = len } };
        }
        return .{ .ptr = s, .len = .truncated };
    }

    pub fn format(
        self: @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        _ = fmt;
        _ = options;
        const part: struct { s_len: u8, suffix: []const u8 } = switch (self.len) {
            .full => |len| .{ .s_len = len, .suffix = "" },
            .truncated => .{ .s_len = max_str_len - 3, .suffix = "..." },
        };
        try writer.print("{*} \"{}\"{s}", .{self.ptr, std.zig.fmtEscapes(self.ptr[0 .. part.s_len]), part.suffix});
    }
};

export fn strcmp(a: [*:0]const u8, b: [*:0]const u8) callconv(.C) c_int {
    trace("strcmp {} {}", .{fmtTraceStr(a), fmtTraceStr(b)});
    var a_next = a;
    var b_next = b;
    while (a_next[0] == b_next[0] and a_next[0] != 0) {
        a_next += 1;
        b_next += 1;
    }
    const result = @intCast(c_int, a_next[0]) -| @intCast(c_int, b_next[0]);
    trace("strcmp return {}", .{result});
    return result;
}

export fn strncmp(a: [*:0]const u8, b: [*:0]const u8, n: usize) callconv(.C) c_int {
    trace("strncmp {*} {*} n={}", .{a, b, n});
    var i: usize = 0;
    while (a[i] == b[i] and a[0] != 0) : (i += 1) {
        if (i == n - 1) return 0;
    }
    return @intCast(c_int, a[i]) -| @intCast(c_int, b[i]);
}

export fn strcoll(s1: [*:0]const u8, s2: [*:0]const u8) callconv(.C) c_int {
    _ = s1;
    _ = s2;
    @panic("strcoll not implemented");
}

export fn strchr(s: [*:0]const u8, char: c_int) callconv(.C) ?[*:0]const u8 {
    trace("strchr {} c='{}'", .{fmtTraceStr(s), char});
    var next = s;
    while (true) : (next += 1) {
        if (next[0] == char) return next;
        if (next[0] == 0) return null;
    }
}
export fn memchr(s: [*]const u8, char: c_int, n: usize) callconv(.C) ?[*]const u8 {
    trace("memchr {*} c='{}' n={}", .{s, char, n});
    var i: usize = 0;
    while (true) : (i += 1) {
        if (i == n) return null;
        if (s[i] == char) return s + i;
    }
}

export fn strrchr(s: [*:0]const u8, char: c_int) callconv(.C) ?[*:0]const u8 {
    trace("strrchr {} c='{}'", .{fmtTraceStr(s), char});
    var next = s + strlen(s);
    while (true) {
        if (next[0] == char) return next;
        if (next == s) return null;
        next = next - 1;
    }
}



export fn strstr(s1: [*:0]const u8, s2: [*:0]const u8) callconv(.C) ?[*:0]const u8 {
    trace("strstr {} {}", .{fmtTraceStr(s1), fmtTraceStr(s2)});
    const s2_len = strlen(s2);
    var i: usize = 0;
    while (true) {
        if (0 == strncmp(s1, s2, s2_len)) return s1 + i;
    }
    return null;
}

export fn strcpy(s1: [*]u8, s2: [*:0]const u8) callconv(.C) [*:0]u8 {
    trace("strcpy {*} {*}", .{s1, s2});
    @memcpy(s1, s2, std.mem.len(s2) + 1);
    return std.meta.assumeSentinel(s1, 0);
}

// TODO: find out which standard this function comes from
export fn strncpy(s1: [*]u8, s2: [*:0]const u8, n: usize) callconv(.C) [*]u8 {
    trace("strncpy {*} {} n={}", .{s1, fmtTraceStr(s2), n});
    const len = strnlen(s2, n);
    @memcpy(s1, s2, len);
    @memset(s1 + len, 0, n - len);
    return s1;
}

// NOTE: strlcpy and strlcat appear in some libc implementations (rejected by glibc though)
//       they don't appear to be a part of any standard.
//       not sure whether they should live in this library or a separate one
//       see https://lwn.net/Articles/507319/
export fn strlcpy(dst: [*]u8, src: [*]const u8, size: usize) callconv(.C) usize {
    trace("strncpy {*} {*} n={}", .{dst, src, size});
    var i: usize = 0;
    while (true) : (i += 1) {
        if (i == size) {
            if (size > 0)
                dst[size - 1] = 0;
            return i + strlen(std.meta.assumeSentinel(src + i, 0));
        }
        dst[i] = src[i];
        if (src[i] == 0) {
            return i;
        }
    }
}
export fn strlcat(dst: [*:0]u8, src: [*:0]const u8, size: usize) callconv(.C) usize {
    trace("strlcat {} {} n={}", .{fmtTraceStr(dst), fmtTraceStr(src), size});
    const dst_len = strnlen(dst, size);
    if (dst_len == size) return dst_len + strlen(src);
    return dst_len + strlcpy(dst + dst_len, src, size - dst_len);
}

export fn strncat(s1: [*:0]u8, s2: [*:0]const u8, n: usize) callconv(.C) [*:0]u8 {
    trace("strncat {} {} n={}", .{fmtTraceStr(s1), fmtTraceStr(s2), n});
    const dest = s1 + strlen(s1);
    var i: usize = 0;
    while (s2[i] != 0 and i < n) : (i += 1) {
        dest[i] = s2[i];
    }
    dest[i] = 0;
    return s1;
}

export fn strspn(s1: [*:0]const u8, s2: [*:0]const u8) callconv(.C) usize {
    trace("strspn {} {}", .{fmtTraceStr(s1), fmtTraceStr(s2)});
    var spn: usize = 0;
    while (true) : (spn += 1) {
        if (s1[spn] == 0 or null == strchr(s2, s1[spn])) return spn;
    }
}

export fn strcspn(s1: [*:0]const u8, s2: [*:0]const u8) callconv(.C) usize {
    trace("strcspn {} {}", .{fmtTraceStr(s1), fmtTraceStr(s2)});
    var spn: usize = 0;
    while (true) : (spn += 1) {
        if (s1[spn] == 0 or null != strchr(s2, s1[spn])) return spn;
    }
}

export fn strpbrk(s1: [*:0]const u8, s2: [*:0]const u8) callconv(.C) ?[*]const u8 {
    trace("strpbrk {} {}", .{fmtTraceStr(s1), fmtTraceStr(s2)});
    var next = s1;
    while (true) : (next += 1) {
        if (next[0] == 0) return null;
        if (strchr(s2, next[0]) != null) return next;
    }
}

export fn strtok(s1: ?[*:0]u8, s2: [*:0]const u8) callconv(.C) ?[*:0]u8 {
    if (s1 != null) {
        trace("strtok {} {}", .{fmtTraceStr(s1.?), fmtTraceStr(s2)});
        global.strtok_ptr = s1;
    } else {
        trace("strtok NULL {}", .{fmtTraceStr(s2)});
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

export fn strtod(nptr: [*:0]const u8, endptr: [*][*:0]const u8) callconv(.C) f64 {
    _ = nptr;
    _ = endptr;
    @panic("strtod not implemented");
}

export fn strerror(errnum: c_int) callconv(.C) [*:0]const u8 {
    std.debug.panic("strerror (num={}) not implemented", .{errnum});
}


// --------------------------------------------------------------------------------
// signal
// --------------------------------------------------------------------------------
export fn signal(sig: c_int, func: fn (c_int) callconv(.C) void) void {
    _ = sig;
    _ = func;
    @panic("signal not implemented");
}

// --------------------------------------------------------------------------------
// stdio
// --------------------------------------------------------------------------------
const global = struct {
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
        .{ .fd = if (builtin.os.tag == .windows) undefined else std.os.STDIN_FILENO, .errno = undefined },
        .{ .fd = if (builtin.os.tag == .windows) undefined else std.os.STDOUT_FILENO, .errno = undefined },
        .{ .fd = if (builtin.os.tag == .windows) undefined else std.os.STDERR_FILENO, .errno = undefined },
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
        const i = (@ptrToInt(file) - @ptrToInt(&files[0])) / @sizeOf(usize);
        if (!@atomicRmw(bool, &files_reserved[i], .Xchg, false, .SeqCst)) {
            std.debug.panic("released FILE (i={} ptr={*}) that was not reserved", .{ i, file });
        }
    }
};
export const stdin: *c.FILE = &global.files[0];
export const stdout: *c.FILE = &global.files[1];
export const stderr: *c.FILE = &global.files[2];

export fn remove(filename: [*:0]const u8) callconv(.C) c_int {
    trace("remove '{s}'", .{filename});
    @panic("remove not implemented");
}

export fn rename(old: [*:0]const u8, new: [*:0]const u8) callconv(.C) c_int {
    trace("remove '{s}' '{s}'", .{old, new});
    @panic("rename not implemented");
}

export fn getc(stream: *c.FILE) callconv(.C) c_int {
    trace("getc {*}", .{stream});
    _ = stream;
    @panic("getc not implemented");
}

comptime {
    @export(getc, .{ .name = "fgetc" });
}

export fn ungetc(char: c_int, stream: *c.FILE) callconv(.C) c_int {
    _ = char; _ = stream;
    @panic("ungetc not implemented");
}

export fn _fread_buf(ptr: [*]const u8, size: usize, stream: *c.FILE) callconv(.C) usize {
    _ = ptr;
    _ = size;
    _ = stream;
    @panic("_fread_buf not implemented");
}

export fn fread(ptr: [*]u8, size: usize, nmemb: usize, stream: *c.FILE) callconv(.C) usize {
    const total = size * nmemb;
    const result = _fread_buf(ptr, total, stream);
    // TODO: if length read is not aligned then we need to leave it
    //       in an interal read buffer inside FILE
    _ = result;
    @panic("fread not implemented");
    //if (result == total) return nmemb;
    //return result / size;
    //return _fread_buf(ptr,
}

export fn feof(stream: *c.FILE) callconv(.C) c_int {
    _ = stream;
    @panic("feof not implemented");
}

export fn ferror(stream: *c.FILE) callconv(.C) c_int {
    trace("ferror {*} return {}", .{stream, stream.errno});
    return stream.errno;
}

export fn fopen(filename: [*:0]const u8, mode: [*:0]const u8) callconv(.C) ?*c.FILE {
    trace("fopen '{s}' mode={s}", .{filename, mode});
    if (builtin.os.tag == .windows) {
        var create_disposition: u32 = std.os.windows.OPEN_EXISTING;
        var access: u32 = 0;
        for (std.mem.span(mode)) |mode_char| {
            if (mode_char == 'r') {
                access |= std.os.windows.GENERIC_READ;
            } else if (mode_char == 'w') {
                access |= std.os.windows.GENERIC_WRITE;
                create_disposition = std.os.windows.CREATE_ALWAYS;
            } else {
                std.debug.panic("unhandled open flag '{}' (from '{s}')", .{ mode_char, mode });
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
            errno = @enumToInt(std.os.windows.kernel32.GetLastError());
            return null;
        }
        const file = global.reserveFile();
        file.fd = fd;
        return file;
    }

    var flags: u32 = 0;
    var os_mode: std.os.mode_t = 0;
    for (std.mem.span(mode)) |mode_char| {
        if (mode_char == 'r') {
            flags |= std.os.O.RDONLY;
        } else if (mode_char == 'w') {
            flags |= std.os.O.WRONLY;
        } else {
            std.debug.panic("unhandled open flag '{}' (from '{s}')", .{ mode_char, mode });
        }
    }
    const fd = std.os.system.open(filename, flags, os_mode);
    switch (std.os.errno(fd)) {
        .SUCCESS => {},
        else => |e| {
            errno = @enumToInt(e);
            return null;
        },
    }
    const file = global.reserveFile();
    file.fd = @intCast(c_int, fd);
    return file;
}

export fn freopen(filename: [*:0]const u8, mode: [*:0]const u8, stream: *c.FILE) callconv(.C) *c.FILE {
    _ = filename;
    _ = mode;
    _ = stream;
    @panic("freopen not implemented");
}

export fn fclose(stream: *c.FILE) callconv(.C) c_int {
    trace("fclose {*}", .{stream});
    if (builtin.os.tag == .windows) {
        std.os.close(stream.fd.?);
    } else {
        std.os.close(stream.fd);
    }
    global.releaseFile(stream);
    return 0;
}

export fn fseek(stream: *c.FILE, offset: c_long, whence: c_int) callconv(.C) c_int {
    _ = stream; _ = offset; _ = whence;
    @panic("fseek not implemented");
}

export fn ftell(stream: *c.FILE) callconv(.C) c_long {
    _ = stream;
    @panic("ftell not implemented");
}

export fn fputc(character: c_int, stream: *c.FILE) callconv(.C) c_int {
    trace("fputc {} stream={*}", .{character, stream});
    if (builtin.os.tag == .windows) {
        @panic("fputc not implemented");
    }
    const buf = [_]u8{@intCast(u8, 0xff & character)};
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
        windows.writeAll(stream.fd.?, ptr[0..size], &written) catch {
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
    trace("fwrite {*} size={} n={} stream={*}", .{ptr, size, nmemb, stream});
    const total = size * nmemb;
    const result = _fwrite_buf(ptr, total, stream);
    if (result == total) return nmemb;
    return result / size;
}

export fn fflush(stream: ?*c.FILE) callconv(.C) c_int {
    trace("fflush {*}", .{stream});
    _ = stream;
    return 0; // no-op since there's no buffering right now
}

export fn puts(s: [*:0]const u8) callconv(.C) c_int {
    trace("puts '{}'", .{fmtTraceStr(s)});
    return fputs(s, stdout);
}

export fn fputs(s: [*:0]const u8, stream: *c.FILE) callconv(.C) c_int {
    trace("fputs '{}' stream={*}", .{fmtTraceStr(s), stream});
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
    _ = s;
    _ = n;
    _ = stream;
    @panic("fgets not implemented");
}

export fn tmpfile() callconv(.C) *c.FILE {
    @panic("tmpfile not implemented");
}

export fn tmpnam(s: [*]u8) callconv(.C) [*]u8 {
    _ = s;
    @panic("tmpnam not implemented");
}

export fn clearerr(stream: *c.FILE) callconv(.C) void {
    trace("clearerr {*}", .{stream});
    stream.errno = 0;
}

export fn setvbuf(stream: *c.FILE, buf: ?[*]u8, mode: c_int, size: usize) callconv(.C) c_int {
    _ = stream;
    _ = buf;
    _ = mode;
    _ = size;
    @panic("setvbuf not implemented");
}

// NOTE: this is not a libc function, it's exported so it can be used
//       by vformat in libc.c
// buf must be at least 100 bytes
export fn _formatCInt(buf: [*]u8, value: c_int) callconv(.C) usize {
    return std.fmt.formatIntBuf(buf[0..100], value, 10, .lower, .{});
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
    _ = value;
    _ = exp;
    @panic("frexp not implemented");
}

export fn ldexp(x: f64, exp: c_int) callconv(.C) f64 {
    _ = x;
    _ = exp;
    @panic("ldexp not implemented");
}

export fn pow(x: f64, y: f64) callconv(.C) f64 {
    _ = x;
    _ = y;
    @panic("pow not implemented");
}

// --------------------------------------------------------------------------------
// setjmp
// --------------------------------------------------------------------------------
export fn setjmp(env: c.jmp_buf) callconv(.C) c_int {
    trace("setjmp", .{});
    // not implemented, but we'll just return success for now
    // and throw a not-implemented error in longjmp
    _ = env;
    return 0;
}

export fn longjmp(env: c.jmp_buf, val: c_int) callconv(.C) void {
    trace("longjmp {}", .{val});
    _ = env;
    _ = val;
    @panic("longjmp not implemented");
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
    @panic("localeconv not implemented");
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
    trace("time {*}", .{timer});
    const now = std.time.timestamp();
    if (timer) |_| {
        timer.?.* = now;
    }
    trace("time return {}", .{now});
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
    trace("isalnum {}", .{char});
    return @boolToInt(std.ascii.isAlNum(std.math.cast(u8, char) catch return 0));
}

export fn toupper(char: c_int) callconv(.C) c_int {
    trace("toupper {}", .{char});
    return std.ascii.toUpper(std.math.cast(u8, char) catch return char);
}

export fn tolower(char: c_int) callconv(.C) c_int {
    trace("tolower {}", .{char});
    return std.ascii.toLower(std.math.cast(u8, char) catch return char);
}

export fn isspace(char: c_int) callconv(.C) c_int {
    trace("isspace {}", .{char});
    return @boolToInt(std.ascii.isSpace(std.math.cast(u8, char) catch return 0));
}

export fn isxdigit(char: c_int) callconv(.C) c_int {
    trace("isxdigit {}", .{char});
    return @boolToInt(std.ascii.isXDigit(std.math.cast(u8, char) catch return 0));
}

export fn iscntrl(char: c_int) callconv(.C) c_int {
    trace("iscntrl {}", .{char});
    return @boolToInt(std.ascii.isCntrl(std.math.cast(u8, char) catch return 0));
}

export fn isalpha(char: c_int) callconv(.C) c_int {
    trace("isalhpa {}", .{char});
    return @boolToInt(std.ascii.isAlpha(std.math.cast(u8, char) catch return 0));
}

export fn isgraph(char: c_int) callconv(.C) c_int {
    trace("isgraph {}", .{char});
    return @boolToInt(std.ascii.isGraph(std.math.cast(u8, char) catch return 0));
}

export fn islower(char: c_int) callconv(.C) c_int {
    trace("islower {}", .{char});
    return @boolToInt(std.ascii.isLower(std.math.cast(u8, char) catch return 0));
}

export fn isupper(char: c_int) callconv(.C) c_int {
    trace("isupper {}", .{char});
    return @boolToInt(std.ascii.isUpper(std.math.cast(u8, char) catch return 0));
}

export fn ispunct(char: c_int) callconv(.C) c_int {
    trace("ispunct {}", .{char});
    return @boolToInt(std.ascii.isPunct(std.math.cast(u8, char) catch return 0));
}

// --------------------------------------------------------------------------------
// assert
// --------------------------------------------------------------------------------
export fn assert(expression: c_int) callconv(.C) void {
    trace("assert {}", .{expression});
    if (expression == 0) {
        abort();
    }
}
