const std = @import("std");
const build = std.build;
const LibExeObjStep = build.LibExeObjStep;

pub const LinkKind = enum { static, shared };
pub const LibVariant = enum {
    only_std,
    only_posix,
    only_linux,
    only_gnu,
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
    trace: bool,
};

/// Provides a _start symbol that will call C main
pub fn addZigStart(builder: *std.build.Builder) *std.build.LibExeObjStep {
    const lib = builder.addStaticLibrary("start", "src" ++ std.fs.path.sep_str ++ "start.zig");
    // TODO: not sure if this is reallly needed or not, but it shouldn't hurt
    //       anything except performance to enable it
    lib.force_pic = true;
    return lib;
}

// Returns ziglibc as a LibExeObjStep
// Caller will also need to add the include path to get the C headers
pub fn addLibc(builder: *std.build.Builder, opt: ZigLibcOptions) *std.build.LibExeObjStep {
    const name = switch (opt.variant) {
        .only_std => "c-only-std",
        .only_posix => "c-only-posix",
        .only_linux => "c-only-linux",
        .only_gnu => "c-only-gnu",
        //.full => "c",
        .full => "cguana", // use cguana to avoid passing in '-lc' to zig which will
                           // cause it to add the system libc headers
    };
    const trace_options = builder.addOptions();
    trace_options.addOption(bool, "enabled", opt.trace);

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
    // TODO: not sure if this is reallly needed or not, but it shouldn't hurt
    //       anything except performance to enable it
    lib.force_pic = true;
    lib.addOptions("modules", modules_options);
    lib.addOptions("trace_options", trace_options);
    const c_flags = [_][]const u8 {
        "-std=c11",
    };
    const include_cstd = switch (opt.variant) {
        .only_std, .full => true,
        else => false,
    };
    modules_options.addOption(bool, "cstd", include_cstd);
    if (include_cstd) {
        lib.addCSourceFile("src" ++ std.fs.path.sep_str ++ "printf.c", &c_flags);
        lib.addCSourceFile("src" ++ std.fs.path.sep_str ++ "scanf.c", &c_flags);
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
    const include_gnu = switch (opt.variant) {
        .only_gnu, .full => true,
        else => false,
    };
    modules_options.addOption(bool, "gnu", include_gnu);
    if (include_gnu) {
        lib.addIncludePath("inc" ++ std.fs.path.sep_str ++ "gnu");
    }
    return lib;
}
