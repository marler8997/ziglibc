const std = @import("std");

const Time = i128;

pub fn leftFileIsNewer(left: []const u8, right: []const u8) !bool {
    const left_modify_time = (try getModifyTime(left)) orelse return false;
    const right_modify_time = (try getModifyTime(right)) orelse return false;
    // NOTE: '>' is 'safer' but could be overzealous rather than just '>='
    return left_modify_time > right_modify_time;
}

pub fn getModifyTime(path: []const u8) !?Time {
    const file = std.fs.cwd().openFile(path, .{}) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => return err,
    };
    defer file.close();
    return (try file.stat()).mtime;
}
