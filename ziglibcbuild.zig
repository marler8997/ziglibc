const std = @import("std");
const build = std.build;
const LibExeObjStep = build.LibExeObjStep;

pub const LinkKind = enum { static, dynamic };
pub const ZigLibcOptions = struct {
    link: LinkKind,
};

/// Provides a _start symbol that will call C main
pub fn addZigStart(builder: *std.build.Builder) *std.build.LibExeObjStep {
    const lib = builder.addStaticLibrary("start", "src" ++ std.fs.path.sep_str ++ "start.zig");
    return lib;
}

// Returns ziglibc as a LibExeObjStep
// Caller will also need to add the include path to get the C headers
pub fn addZigLibc(builder: *std.build.Builder, opt: ZigLibcOptions) *std.build.LibExeObjStep {
    switch (opt.link) {
        .static => {},
        .dynamic => {
            @panic("dynamic linking to ziglibc not implemented");
        },
    }
    const lib = builder.addStaticLibrary("c", "src" ++ std.fs.path.sep_str ++ "libc.zig");
    lib.addCSourceFile("src" ++ std.fs.path.sep_str ++ "libc.c", &[_][]const u8{
        "-std=c11",
    });
    lib.addIncludePath("inc" ++ std.fs.path.sep_str ++ "libc");
    return lib;
}

// Returns ziglibc as a LibExeObjStep
// Caller will also need to add the include path to get the C headers
pub fn addZigLibPosix(builder: *std.build.Builder, opt: ZigLibcOptions) *std.build.LibExeObjStep {
    switch (opt.link) {
        .static => {},
        .dynamic => {
            @panic("dynamic linking to ziglibposix not implemented");
        },
    }
    const lib = builder.addStaticLibrary("posix", "src" ++ std.fs.path.sep_str ++ "posix.zig");
    lib.addCSourceFile("src" ++ std.fs.path.sep_str ++ "posix.c", &[_][]const u8{
        "-std=c11",
    });
    lib.addIncludePath("inc" ++ std.fs.path.sep_str ++ "libc");
    lib.addIncludePath("inc" ++ std.fs.path.sep_str ++ "posix");
    return lib;
}

// Returns ziglibc as a LibExeObjStep
// Caller will also need to add the include path to get the C headers
pub fn addZigLibLinux(builder: *std.build.Builder, opt: ZigLibcOptions) *std.build.LibExeObjStep {
    switch (opt.link) {
        .static => {},
        .dynamic => {
            @panic("dynamic linking to zigliblinux not implemented");
        },
    }
    const lib = builder.addStaticLibrary("linux", "src" ++ std.fs.path.sep_str ++ "linux.zig");
    lib.addIncludePath("inc" ++ std.fs.path.sep_str ++ "libc");
    return lib;
}
