const builtin = @import("builtin");
const std = @import("std");

const c = @cImport({
    @cInclude("errno.h");
    @cInclude("string.h");
    @cInclude("stdlib.h");
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
