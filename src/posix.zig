const builtin = @import("builtin");
const std = @import("std");

const c = @cImport({
    @cInclude("errno.h");
    @cInclude("string.h");
    @cInclude("stdlib.h");
    @cInclude("time.h");
});

const trace = @import("trace.zig");

const global = struct {
    export var optarg: [*:0]u8 = undefined;
    export var opterr: c_int = undefined;
    export var optind: c_int = 1;
    export var optopt: c_int = undefined;
};

/// Returns some information through these globals
///    extern char *optarg;
///    extern int opterr, optind, optopt;
export fn getopt(argc: c_int, argv: [*][*:0]u8, optstring: [*:0]const u8) callconv(.C) c_int {
    trace.log("getopt argc={} argv={*} opstring={} (err={}, ind={}, opt={})", .{
        argc,
        argv,
        trace.fmtStr(optstring),
        global.opterr,
        global.optind,
        global.optopt,
    });
    if (global.optind >= argc) {
        trace.log("getopt return -1", .{});
        return -1;
    }
    const arg = argv[@intCast(usize, global.optind)];
    if (arg[0] != '-') {
        // TODO: not sure if this is what we're supposed to do
        //       my guess is we have to take this non-option
        //       argument and move it to the front of argv,
        //       then move on to the rest of the arguments to
        //       check for more options
        if (global.optind + 1 != argc) {
            @panic("TODO: check the rest of the arguments");
        }
        return -1;
    }

    global.optind += 1;
    if (arg[2] != 0) @panic("multi-letter argument not implemented");
    const result = c.strchr(optstring, arg[1]) orelse {
        // I think we return '?'
        std.debug.panic("unknown option '{}', probably return '?'", .{arg[1]});
    };
    const takes_arg = result[1] == ':';
    if (takes_arg) {
        const is_optional = result[2] == ':';
        if (is_optional) @panic("optional args not implemented");
        global.optarg = argv[@intCast(usize, global.optind)];
        if (global.optind >= argc or global.optarg[0] == '-') {
            std.debug.panic("TODO: handle missing arg for option '{}", .{arg[1]});
        }
        global.optind += 1;
    }
    return @intCast(c_int, arg[1]);
}

export fn write(fd: c_int, buf: [*]const u8, nbyte: usize) callconv(.C) isize {
    if (builtin.os.tag == .windows) {
        @panic("write not implemented on windows");
    }
    const rc = std.os.system.write(fd, buf, nbyte);
    switch (std.os.errno(rc)) {
        .SUCCESS => return @intCast(isize, rc),
        else => |e| {
            c.errno = @enumToInt(e);
            return -1;
        }
    }
}

// --------------------------------------------------------------------------------
// string
// --------------------------------------------------------------------------------
export fn strdup(s: [*:0]const u8) callconv(.C) ?[*:0]u8 {
    trace.log("strdup '{}'", .{trace.fmtStr(s)});
    const len = c.strlen(s);
    const optional_new_s = @ptrCast(?[*]u8, c.malloc(len + 1));
    if (optional_new_s) |new_s| {
        _ = c.strcpy(new_s, s);
    }
    return std.meta.assumeSentinel(optional_new_s, 0);
}

// --------------------------------------------------------------------------------
// time
// --------------------------------------------------------------------------------
comptime {
    std.debug.assert(@sizeOf(c.timespec) == @sizeOf(std.os.timespec));
    if (builtin.os.tag != .windows) {
        std.debug.assert(c.CLOCK_REALTIME == std.os.CLOCK.REALTIME);
    }
}

export fn clock_gettime(clk_id: c.clockid_t, tp: *std.os.timespec) callconv(.C) c_int {
    if (builtin.os.tag == .windows) {
        if (clk_id == c.CLOCK_REALTIME) {
            var ft: std.os.windows.FILETIME = undefined;
            std.os.windows.kernel32.GetSystemTimeAsFileTime(&ft);
            // FileTime has a granularity of 100 nanoseconds and uses the NTFS/Windows epoch.
            const ft64 = (@as(u64, ft.dwHighDateTime) << 32) | ft.dwLowDateTime;
            const ft_per_s = std.time.ns_per_s / 100;
            tp.* = .{
                .tv_sec = @intCast(i64, ft64 / ft_per_s) + std.time.epoch.windows,
                .tv_nsec = @intCast(c_long, ft64 % ft_per_s) * 100,
            };
            return 0;
        }
        // TODO POSIX implementation of CLOCK.MONOTONIC on Windows.
        std.debug.panic("clk_id {} not implemented on Windows", .{clk_id});
    }

    switch (std.os.errno(std.os.system.clock_gettime(clk_id, tp))) {
        .SUCCESS => return 0,
        else => |e| {
            c.errno = @enumToInt(e);
            return -1;
        },
    }
}
