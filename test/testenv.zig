/// Run the given program in a clean directory
const std = @import("std");

var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);

pub fn main() !u8 {
    const full_args = try std.process.argsAlloc(arena.allocator());
    if (full_args.len <= 1) {
        try std.io.getStdErr().writer().writeAll("Usage: testenv PROGRAM ARGS...\n");
        return 1;
    }
    const args = full_args[1..];

    // TODO: improve this
    const dirname = try std.fmt.allocPrint(arena.allocator(), "{s}.test.tmp", .{std.fs.path.basename(args[0])});
    try std.fs.cwd().deleteTree(dirname);
    try std.fs.cwd().makeDir(dirname);
    const child = try std.ChildProcess.init(args, arena.allocator());
    defer child.deinit();
    child.cwd = dirname;
    try child.spawn();
    const result = try child.wait();
    switch (result) {
        .Exited => |code| {
            if (code != 0) return code;
        },
        else => |r| {
            std.log.err("child process failed with {}", .{r});
            return 0xff;
        },
    }
    try std.fs.cwd().deleteTree(dirname);
    return 0;
}
