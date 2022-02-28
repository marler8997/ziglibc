const builtin = @import("builtin");
const std = @import("std");

const c = @cImport({
    @cInclude("errno.h");
    //@cInclude("unistd.h");
});

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

export fn write(fd: c_int, buf: [*]const u8, nbyte: usize) isize {
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
