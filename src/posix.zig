const builtin = @import("builtin");
const std = @import("std");

const c = @cImport({
    @cInclude("errno.h");
    @cInclude("string.h");
    @cInclude("stdlib.h");
});

const trace = @import("trace.zig");

export var optarg: [*:0]u8 = undefined;
export var opterr: c_int = undefined;
export var optind: c_int = undefined;
export var optopt: c_int = undefined;

export fn getopt(argc: c_int, argv: [*:null]?[*:0]u8, optstring: [*:0]const u8) callconv(.C) c_int {
    _ = argc;
    _ = argv;
    _ = optstring;
    @panic("getopt not implemented");
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
