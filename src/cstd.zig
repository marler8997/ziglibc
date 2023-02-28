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
    std.os.exit(@intCast(u8, status));
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

const alloc_metadata_len = std.mem.alignForward(@sizeOf(usize), alloc_align);

export fn malloc(size: usize) callconv(.C) ?[*]align(alloc_align) u8 {
    trace.log("malloc {}", .{size});
    std.debug.assert(size > 0); // TODO: what should we do in this case?
    const full_len = alloc_metadata_len + size;
    const buf = global.gpa.allocator().alignedAlloc(u8, alloc_align, full_len) catch |err| switch (err) {
        error.OutOfMemory => {
            trace.log("malloc return null", .{});
            return null;
        },
    };
    @ptrCast(*usize, buf).* = full_len;
    const result = @intToPtr([*]align(alloc_align) u8, @ptrToInt(buf.ptr) + alloc_metadata_len);
    trace.log("malloc return {*}", .{result});
    return result;
}

fn getGpaBuf(ptr: [*]u8) []align(alloc_align) u8 {
    const start = @ptrToInt(ptr) - alloc_metadata_len;
    const len = @intToPtr(*usize, start).*;
    return @alignCast(alloc_align, @intToPtr([*]u8, start)[0..len]);
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
    @ptrCast(*usize, new_buf.ptr).* = gpa_size;
    const result = @intToPtr([*]align(alloc_align) u8, @ptrToInt(new_buf.ptr) + alloc_metadata_len);
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
    @memset(ptr, 0, total);
    return ptr;
}

export fn free(ptr: ?[*]align(alloc_align) u8) callconv(.C) void {
    trace.log("free {*}", .{ptr});
    const p = ptr orelse return;
    global.gpa.allocator().free(getGpaBuf(p));
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
        const i = (@ptrToInt(file) - @ptrToInt(&files[0])) / @sizeOf(usize);
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
    stream.errno = if (rc == 0) 0 else @enumToInt(std.os.errno(rc));
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
        const actual_read_len = @intCast(u32, std.math.min(@as(u32, std.math.maxInt(u32)), size));
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
            return @intCast(usize, amt_read);
        }
    }

    // Prevents EINVAL.
    const max_count = switch (builtin.os.tag) {
        .linux => 0x7ffff000,
        .macos, .ios, .watchos, .tvos => std.math.maxInt(i32),
        else => std.math.maxInt(isize),
    };
    const adjusted_len = std.math.min(max_count, size);

    const rc = std.os.system.read(stream.fd, ptr, adjusted_len);
    switch (std.os.errno(rc)) {
        .SUCCESS => {
            if (rc == 0) stream.eof = 1;
            return @intCast(usize, rc);
        },
        else => |e| {
            c.errno = @enumToInt(e);
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

export fn fopen(filename: [*:0]const u8, mode: [*:0]const u8) callconv(.C) ?*c.FILE {
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
            c.errno = @enumToInt(std.os.windows.kernel32.GetLastError());
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
            c.errno = @enumToInt(e);
            trace.log("fopen return null (errno={})", .{c.errno});
            return null;
        },
    }
    const file = global.reserveFile();
    file.fd = @intCast(c_int, fd);
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
    const rc = std.os.system.lseek(stream.fd, @intCast(i64, offset), @intCast(usize, whence));
    switch (std.os.errno(rc)) {
        .SUCCESS => return 0,
        else => |e| {
            c.errno = @enumToInt(e);
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
    const buf = [_]u8{@intCast(u8, ch & 0xff)};
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
    @memcpy(mem.ptr, s, len);
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
        s[total_read] = @intCast(u8, result);
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
    const now = @intCast(c.time_t, std.math.boolMask(c.time_t, true) & now_zig);
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
