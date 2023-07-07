/// Symbols that we need to export if our library is to be used
/// alongside the glibc start code (i.e. crtn.o, etc)
const builtin = @import("builtin");
const std = @import("std");

const c = struct {
    extern fn main(argc: c_int, argv: [*:null]?[*:0]u8) callconv(.C) c_int;
};

export fn __libc_csu_init(
    argc: c_int,
    argv: [*:null]?[*:0]u8,
    envp: [*:null]?[*:0]u8,
) callconv(.C) void {
    // do nothing for now
    _ = argc;
    _ = argv;
    _ = envp;
}

export fn __libc_csu_fini() callconv(.C) void {
    std.log.warn("called __libc_scu_fini", .{});
}

export fn __libc_start_main(
    argc: c_int,
    argv: [*:null]?[*:0]u8,
    init: switch (builtin.zig_backend) {
        .stage1 => fn (argc: c_int, argv: [*:null]?[*:0]u8) callconv(.C) c_int,
        else => *const fn (argc: c_int, argv: [*:null]?[*:0]u8) callconv(.C) c_int,
    },
    fini: fn () callconv(.C) void,
    rtld_fini: fn () callconv(.C) void,
    stack_end: *anyopaque,
) callconv(.C) noreturn {
    _ = init;
    _ = fini;
    _ = rtld_fini;
    _ = stack_end;
    std.log.warn("__libc_start_main is probably not doing everything it needs too", .{});
    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    // TODO: pass envp
    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    var result = c.main(argc, argv);
    if (result != 0) {
        while ((result & 0xff == 0)) result = result >> 8;
    }
    std.os.exit(@as(u8, @intCast(result & 0xff)));
}

export fn __tls_get_addr(ptr: *usize) callconv(.C) *anyopaque {
    std.debug.panic("__tls_get_addr (ptr={*}) is not implemented", .{ptr});
}
