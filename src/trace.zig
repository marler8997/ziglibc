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
        .Optional => return fmtStr(s orelse return FmtStr.initNull()),
        else => {},
    }
    @compileError("fmtStr for type " ++ @typeName(@TypeOf(s)) ++ " is not implemented");
}
const FmtStr = struct {
    const max_str_len = 26;

    ptr_opt: ?[*]const u8,
    len: union(enum) {
        full: u8,
        truncated: void,
    },

    pub fn initNull() FmtStr {
        return .{ .ptr_opt = null, .len = undefined };
    }
    pub fn initSlice(s: []const u8) FmtStr {
        if (s.len > max_str_len) {
            return .{ .ptr_opt = s.ptr, .len = .truncated };
        }
        return .{ .ptr_opt = s.ptr, .len = .{ .len = @as(u8, s.len) } };
    }

    pub fn initSentinel(s: [*:0]const u8) FmtStr {
        var len: u8 = 0;
        while (len <= max_str_len) : (len += 1) {
            if (s[len] == 0)
                return .{ .ptr_opt = s, .len = .{ .full = len } };
        }
        return .{ .ptr_opt = s, .len = .truncated };
    }

    pub fn format(
        self: @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        _ = fmt;
        _ = options;
        const ptr = self.ptr_opt orelse {
            try writer.writeAll("NULL");
            return;
        };
        const part: struct { s_len: u8, suffix: []const u8 } = switch (self.len) {
            .full => |len| .{ .s_len = len, .suffix = "" },
            .truncated => .{ .s_len = max_str_len - 3, .suffix = "..." },
        };
        try writer.print("{*} \"{}\"{s}", .{ ptr, std.zig.fmtEscapes(ptr[0..part.s_len]), part.suffix });
    }
};
