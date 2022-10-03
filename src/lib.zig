const modules = @import("modules");
comptime {
    if (modules.glibcstart) _ = @import("glibcstart.zig");
    if (modules.cstd) _ = @import("cstd.zig");
    if (modules.posix) _ = @import("posix.zig");
    if (modules.linux) _ = @import("linux.zig");
    if (modules.gnu) _ = @import("gnu.zig");
}
