const std = @import("std");

const c = struct {
    extern fn main(argc: c_int, argv: [*:null]?[*:0]u8) callconv(.C) c_int;
};

pub fn main() u8 {
    var args: [0:null]?[*:0]u8 = [0:null]?[*:0]u8{};
    var result = c.main(0, &args);
    if (result != 0) {
        while ((result & 0xff == 0)) result = result >> 8;
    }
    return @intCast(u8, result & 0xff);
}
