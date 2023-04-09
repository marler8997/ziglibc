const std = @import("std");
const ProcessFileStep = @This();
const filecheck = @import("filecheck.zig");

step: std.build.Step,
//builder: *std.build.Builder,
in_filename: []const u8,
out_filename: []const u8,
subs: []const Sub,

pub const Sub = struct {
    current: []const u8,
    new: []const u8,
};

pub fn create(b: *std.build.Builder, opt: struct {
    in_filename: []const u8,
    out_filename: []const u8,
    subs: []const Sub = &[_]Sub{ },
}) *ProcessFileStep {
    var result = b.allocator.create(ProcessFileStep) catch unreachable;
    const name = std.fmt.allocPrint(b.allocator, "process file '{s}'", .{std.fs.path.basename(opt.in_filename)}) catch unreachable;
    result.* = ProcessFileStep{
        .step = std.build.Step.init(.{
            .id = .custom,
            .name = name,
            .owner = b,
            .makeFn = make,
        }),
        .in_filename = opt.in_filename,
        .out_filename = opt.out_filename,
        .subs = opt.subs,
    };
    return result;
}

fn make(step: *std.build.Step, progress: *std.Progress.Node) !void {
    _ = progress;
    const self = @fieldParentPtr(ProcessFileStep, "step", step);

    if (try filecheck.leftFileIsNewer(self.out_filename, self.in_filename)) {
        return;
    }
    
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const content = std.fs.cwd().readFileAlloc(arena.allocator(), self.in_filename, std.math.maxInt(usize)) catch |err| {
        std.log.err("failed to read file '{s}' to process ({s})", .{self.in_filename, @errorName(err)});
        std.os.exit(0xff);
    };
    const tmp_filename = try std.fmt.allocPrint(arena.allocator(), "{s}.processing", .{self.out_filename});
    {
        var out_file = try std.fs.cwd().createFile(tmp_filename, .{});
        defer out_file.close();
        try process(self.subs, out_file.writer(), content);
    }
    try std.fs.cwd().rename(tmp_filename, self.out_filename);
}

fn process(subs: []const Sub, writer: anytype, content: []const u8) !void {

    var last_flush: usize = 0;
    var i: usize = 0;

    while (i < content.len) {
        const rest = content[i..];

        const match: ?Sub = blk: {
            for (subs) |sub| {
                if (std.mem.startsWith(u8, rest, sub.current)) {
                    break :blk sub;
                }
            }
            break :blk null;
        };

        if (match) |sub| {
            if (last_flush < i) try writer.writeAll(content[last_flush..i]);
            try writer.writeAll(sub.new);
            last_flush = i + sub.current.len;
            i = last_flush;
        } else {
            i += 1;
        }
    }

    if (last_flush < content.len) {
        try writer.writeAll(content[last_flush..]);
    }
}
