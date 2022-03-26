const modules = @import("modules");
comptime {
    if (modules.cstd) _ = @import("cstd.zig");
    if (modules.posix) _ = @import("posix.zig");
    if (modules.linux) _ = @import("linux.zig");
}
