export fn alloca(size: usize) callconv(.C) [*]u8 {
    _ = size;
    @panic("alloca not implemented");
}
