const std = @import("std");
const build = std.build;
const LibExeObjStep = build.LibExeObjStep;

pub const LinkKind = enum { static, shared };
pub const LibVariant = enum {
    only_std,
    only_posix,
    only_linux,
    full,
};
pub const Start = enum {
    ziglibc,
    glibc,
};
pub const ZigLibcOptions = struct {
    variant: LibVariant,
    link: LinkKind,
    start: Start,
};

/// Provides a _start symbol that will call C main
pub fn addZigStart(builder: *std.build.Builder) *std.build.LibExeObjStep {
    const lib = builder.addStaticLibrary("start", "src" ++ std.fs.path.sep_str ++ "start.zig");
    return lib;
}

// Returns ziglibc as a LibExeObjStep
// Caller will also need to add the include path to get the C headers
pub fn addLibc(builder: *std.build.Builder, opt: ZigLibcOptions) *std.build.LibExeObjStep {
    const name = switch (opt.variant) {
        .only_std => "c-only-std",
        .only_posix => "c-only-posix",
        .only_linux => "c-only-linux",
        .full => "c",
    };
    const modules_options = builder.addOptions();
    modules_options.addOption(bool, "glibcstart", switch (opt.start) { .glibc => true, else => false });
    const index = "src" ++ std.fs.path.sep_str ++ "lib.zig";
    const lib = switch (opt.link) {
        .static => builder.addStaticLibrary(name, index),
        .shared => builder.addSharedLibrary(name, index, switch (opt.variant) {
            .full => .{ .versioned = .{ .major = 6, .minor = 0 } },
            else => .unversioned,
        }),
    };
    lib.addOptions("modules", modules_options);
    const c_flags = [_][]const u8 {
        "-std=c11",
    };
    const include_cstd = switch (opt.variant) {
        .only_std, .full => true,
        else => false,
    };
    modules_options.addOption(bool, "cstd", include_cstd);
    if (include_cstd) {
        lib.addCSourceFile("src" ++ std.fs.path.sep_str ++ "cstd.c", &c_flags);
    }
    const include_posix = switch (opt.variant) {
        .only_posix, .full => true,
        else => false,
    };
    modules_options.addOption(bool, "posix", include_posix);
    if (include_posix) {
        lib.addCSourceFile("src" ++ std.fs.path.sep_str ++ "posix.c", &c_flags);
    }
    const include_linux = switch (opt.variant) {
        .only_linux, .full => true,
        else => false,
    };
    modules_options.addOption(bool, "linux", include_linux);
    if (include_cstd or include_posix) {
        lib.addIncludePath("inc" ++ std.fs.path.sep_str ++ "libc");
        lib.addIncludePath("inc" ++ std.fs.path.sep_str ++ "posix");
    }
    return lib;
}
