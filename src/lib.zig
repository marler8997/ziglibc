const modules = @import("modules");
comptime {
    if (modules.glibcstart) _ = @import("glibcstart.zig");
    if (modules.cstd) _ = @import("cstd.zig");
    if (modules.posix) _ = @import("posix.zig");
    if (modules.linux) _ = @import("linux.zig");
    if (modules.gnu) _ = @import("gnu.zig");
}

const builtin = @import("builtin");
pub const is_freestanding = (builtin.os.tag == .freestanding);

pub usingnamespace if (is_freestanding) struct {
    const std = @import("std");

    pub const std_options = struct {
        pub fn logFn(comptime level: std.log.Level, comptime scope: @TypeOf(.enum_literal), comptime fmt: []const u8, args: anytype) void {
            _ = level;
            _ = scope;
            _ = fmt;
            _ = args;
        }
    };
} else struct {};
