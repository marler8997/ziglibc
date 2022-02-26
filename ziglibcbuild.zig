const std = @import("std");
const build = std.build;
const LibExeObjStep = build.LibExeObjStep;

pub const LinkKind = enum { static, dynamic };
pub const ZigLibcOptions = struct {
    link: LinkKind,
};

//pub fn addZigLibc(step: *LibExeObjStep, opt: ZigLibcOptions) void {
//    switch (opt.link) {
//        .static => {},
//        .dynamic => {
//            @panic("dynamic linking to ziglibc not implemented");
//        },
//    }
//    step.addIncludePath("inc");
//    const lib = step.builder.addStaticLibrary("ziglibc", "src" ++ std.fs.path.sep_str ++ "libc.zig");
//    step.link_objects.append(.{
//        .static_path = .{ .path =
//    }) catch unreachable;
//}
//

// Returns ziglibc as a LibExeObjStep
// Caller will also need to add the include path to get the C headers
pub fn addZigLibc(builder: *std.build.Builder, opt: ZigLibcOptions) *std.build.LibExeObjStep {
    switch (opt.link) {
        .static => {},
        .dynamic => {
            @panic("dynamic linking to ziglibc not implemented");
        },
    }
    const lib = builder.addStaticLibrary("ziglibc", "src" ++ std.fs.path.sep_str ++ "libc.zig");
    lib.addCSourceFile("src" ++ std.fs.path.sep_str ++ "libc.c", &[_][]const u8 {
        "-std=c11",
    });
    lib.addIncludePath("inc");
    return lib;
}


/// Provides a _start symbol that will call C main
pub fn addZigStart(builder: *std.build.Builder) *std.build.LibExeObjStep {
    const lib = builder.addStaticLibrary("zigstart", "src" ++ std.fs.path.sep_str ++ "zigstart.zig");
    return lib;
}

// Provides a _start symbol that will call C main
//pub fn addZigStart(exe: *std.build.LibExeObjStep) void {
//    exe.builder.addStaticLibrary("zigstart", "src" ++ std.fs.path.sep_str ++ "zigstart.zig");
//    exe.linkLibrary
//    exe.link_objects.append(.{
//        .static_path = .{ .path =
//    }) catch unreachable;
//}
