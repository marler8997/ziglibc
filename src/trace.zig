const std = @import("std");
const trace_options = @import("trace_options");

pub fn log(comptime fmt: []const u8, args: anytype) void {
    if (trace_options.enabled) {
        std.log.scoped(.trace).info(fmt, args);
    }
}

pub fn fmtStr(s: anytype) FmtStr {
    switch (@typeInfo(@TypeOf(s))) {
        .Pointer => |info| switch (info.size) {
            .Slice => return FmtStr.initSlice(s),
            .Many => if (info.sentinel) |_| {
                return FmtStr.initSentinel(s);
            },
            else => {},
        },
        else => {},
    }
    @compileError("fmtStr for type " ++ @typeName(@TypeOf(s)) ++ " is not implemented");
}
const FmtStr = struct {
    const max_str_len = 26;

    ptr: [*]const u8,
    len: union(enum) {
        full: u8,
        truncated: void,
    },

    pub fn initSlice(s: []const u8) FmtStr {
        if (s.len > max_str_len) {
            return .{ .ptr = s.ptr, .len = .truncated };
        }
        return .{ .ptr = s.ptr, .len = .{ .len = @intCast(u8, s.len) } };
    }

    pub fn initSentinel(s: [*:0]const u8) FmtStr {
        var len: u8 = 0;
        while (len <= max_str_len) : (len += 1) {
            if (s[len] == 0)
                return .{ .ptr = s, .len = .{ .full = len } };
        }
        return .{ .ptr = s, .len = .truncated };
    }

    pub fn format(
        self: @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        _ = fmt;
        _ = options;
        const part: struct { s_len: u8, suffix: []const u8 } = switch (self.len) {
            .full => |len| .{ .s_len = len, .suffix = "" },
            .truncated => .{ .s_len = max_str_len - 3, .suffix = "..." },
        };
        try writer.print("{*} \"{}\"{s}", .{self.ptr, std.zig.fmtEscapes(self.ptr[0 .. part.s_len]), part.suffix});
    }
};
