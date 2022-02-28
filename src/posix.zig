const builtin = @import("builtin");
const std = @import("std");

const c = @cImport({
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
