const builtin = @import("builtin");
const std = @import("std");

const c = struct {
    extern fn main(argc: c_int, argv: [*:null]?[*:0]u8) callconv(.C) c_int;
};

pub fn main() u8 {
    var argc: c_int = undefined;
    const args: [*:null]?[*:0]u8 = blk: {
        if (builtin.os.tag == .windows) {
            const args = windowsArgsAlloc();
            argc = @as(c_int, args.len);
            break :blk args.ptr;
        }
        argc = @as(c_int, @intCast(std.os.argv.len));
        break :blk @as([*:null]?[*:0]u8, @ptrCast(std.os.argv.ptr));
    };

    var result = c.main(argc, args);
    if (result != 0) {
        while ((result & 0xff == 0)) result = result >> 8;
    }
    return @as(u8, @intCast(result & 0xff));
}

// TODO: I'm pretty sure this could be more memory efficient
fn windowsArgsAlloc() [:null]?[*:0]u8 {
    const out_of_memory_msg = "Out Of Memory while decoding command line";

    var argv_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var tmp_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer tmp_arena.deinit();

    var argv = std.ArrayListUnmanaged(?[*:0]u8){};
    var it = std.process.argsWithAllocator(tmp_arena.allocator()) catch |err| switch (err) {
        error.OutOfMemory => @panic(out_of_memory_msg),
        // TODO: would be nice to get the actual utf16 decode error name
        error.InvalidCmdLine => @panic("Failed to decode command line"),
    };
    defer it.deinit();
    while (it.next()) |tmp_arg| {
        const arg = argv_arena.allocator().dupeZ(u8, tmp_arg) catch @panic(out_of_memory_msg);
        argv.append(argv_arena.allocator(), arg) catch @panic(out_of_memory_msg);
    }
    return argv.toOwnedSliceSentinel(argv_arena.allocator(), null) catch @panic(out_of_memory_msg);
}
