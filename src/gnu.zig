const c = @cImport({
    @cInclude("argp.h");
});

export fn argp_usage(state: *const c.argp_state) callconv(.C) void {
    _ = state;
    @panic("argp_usage not implemented");
}

export fn argp_parse(
    argp: *c.argp,
    argc: c_int,
    argv: [*:null]?[*:0]u8,
    flags: c_uint,
    arg_index: *c_int,
    input: *anyopaque,
) callconv(.C) c.error_t {
    _ = argp;
    _ = argc;
    _ = argv;
    _ = flags;
    _ = arg_index;
    _ = input;
    @panic("argp_parse not impl");
}
