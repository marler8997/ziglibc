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

// --------------------------------------------------------------------------------
// errno
// --------------------------------------------------------------------------------
export var errno: c_int = 0;

// --------------------------------------------------------------------------------
// stdlib
// --------------------------------------------------------------------------------

export fn srand(seed: c_uint) callconv(.C) void {
    trace.log("srand {}", .{seed});
    global.rand.seed(seed);
}

export fn rand() callconv(.C) c_int {
    return @bitCast(c_int, @intCast(c_uint, global.rand.random().int(std.math.IntFittingRange(0, c.RAND_MAX))));
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
    const result = @intCast(c_int, a_next[0]) -| @intCast(c_int, b_next[0]);
    trace.log("strcmp return {}", .{result});
    return result;
}

export fn strncmp(a: [*:0]const u8, b: [*:0]const u8, n: usize) callconv(.C) c_int {
    trace.log("strncmp {*} {*} n={}", .{ a, b, n });
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
    @memcpy(s1, s2, std.mem.len(s2) + 1);
    return @ptrCast([*:0]u8, s1); // TODO: use std.meta.assumeSentinel if it's brought back
}

// TODO: find out which standard this function comes from
export fn strncpy(s1: [*]u8, s2: [*:0]const u8, n: usize) callconv(.C) [*]u8 {
    trace.log("strncpy {*} {} n={}", .{ s1, trace.fmtStr(s2), n });
    const len = strnlen(s2, n);
    @memcpy(s1, s2, len);
    @memset(s1 + len, 0, n - len);
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
            break :blk @intCast(u8, optional_base);
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
        trace.log("strto str='{s}' result={}", .{ start[0 .. @ptrToInt(next) - @ptrToInt(start)], x });
    }
    return x;
}

export fn strtod(nptr: [*:0]const u8, endptr: ?*[*:0]const u8) callconv(.C) f64 {
    trace.log("strtod {}", .{trace.fmtStr(nptr)});
    const str_len: usize = if (endptr) |e| @ptrToInt(e.*) - @ptrToInt(nptr) else std.mem.len(nptr);
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
    // std.log.warn("sterror (num={}) not implemented", .{errnum});
    _ = std.fmt.bufPrint(&global.tmp_strerror_buffer, "{}", .{errnum}) catch @panic("BUG");
    return @ptrCast([*:0]const u8, &global.tmp_strerror_buffer); // TODO: use std.meta.assumeSentinel if it's brought back
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
            @intCast(u6, sig),
            &action,
            &old_action,
        ))) {
            .SUCCESS => return old_action.handler.handler,
            else => |e| {
                errno = @enumToInt(e);
                // translate-c having a hard time with this one
                //return c.SIG_ERR;
                return @intToPtr(?SignalFn, @bitCast(usize, @as(isize, -1)));
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

    var strtok_ptr: ?[*:0]u8 = undefined;

    // TODO: remove this.  Just using it to return error numbers as strings for now
    var tmp_strerror_buffer: [30]u8 = undefined;

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
    return std.math.ldexp(x, @intCast(i32, exp));
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
// ctype
// --------------------------------------------------------------------------------
export fn isalnum(char: c_int) callconv(.C) c_int {
    trace.log("isalnum {}", .{char});
    return @boolToInt(std.ascii.isAlphanumeric(std.math.cast(u8, char) orelse return 0));
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
    return @boolToInt(std.ascii.isWhitespace(std.math.cast(u8, char) orelse return 0));
}

export fn isxdigit(char: c_int) callconv(.C) c_int {
    trace.log("isxdigit {}", .{char});
    return @boolToInt(std.ascii.isHex(std.math.cast(u8, char) orelse return 0));
}

export fn iscntrl(char: c_int) callconv(.C) c_int {
    trace.log("iscntrl {}", .{char});
    return @boolToInt(std.ascii.isControl(std.math.cast(u8, char) orelse return 0));
}

export fn isdigit(char: c_int) callconv(.C) c_int {
    trace.log("isdigit {}", .{char});
    return @boolToInt(std.ascii.isDigit(std.math.cast(u8, char) orelse return 0));
}

export fn isalpha(char: c_int) callconv(.C) c_int {
    trace.log("isalhpa {}", .{char});
    return @boolToInt(std.ascii.isAlphabetic(std.math.cast(u8, char) orelse return 0));
}

export fn isgraph(char: c_int) callconv(.C) c_int {
    trace.log("isgraph {}", .{char});
    return @boolToInt(std.ascii.isPrint(std.math.cast(u8, char) orelse return 0));
}

export fn islower(char: c_int) callconv(.C) c_int {
    trace.log("islower {}", .{char});
    return @boolToInt(std.ascii.isLower(std.math.cast(u8, char) orelse return 0));
}

export fn isupper(char: c_int) callconv(.C) c_int {
    trace.log("isupper {}", .{char});
    return @boolToInt(std.ascii.isUpper(std.math.cast(u8, char) orelse return 0));
}

export fn ispunct(char: c_int) callconv(.C) c_int {
    trace.log("ispunct {}", .{char});
    const c_u8 = std.math.cast(u8, char) orelse return 0;
    return @boolToInt(std.ascii.isPrint(c_u8) and !std.ascii.isAlphanumeric(c_u8));
}

export fn isprint(char: c_int) callconv(.C) c_int {
    trace.log("isprint {}", .{char});
    return @boolToInt(std.ascii.isPrint(std.math.cast(u8, char) orelse return 0));
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
    @panic("assertion failed");
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
