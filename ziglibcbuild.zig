const std = @import("std");
const build = std.Build;
const CompileStep = build.Step.Compile;

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
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.Mode,
};

fn relpath(comptime src_path: []const u8) std.Build.LazyPath {
    if (comptime std.fs.path.dirname(@src().file)) |dir|
        return .{ .path = dir ++ std.fs.path.sep_str ++ src_path };
    return .{ .path = src_path };
}

/// Provides a _start symbol that will call C main
pub fn addZigStart(
    builder: *build,
    target: std.Build.ResolvedTarget,
    optimize: anytype,
) *CompileStep {
    const lib = builder.addStaticLibrary(.{
        .name = "start",
        .root_source_file = relpath("src" ++ std.fs.path.sep_str ++ "start.zig"),
        .target = target,
        .optimize = optimize,
    });
    // TODO: not sure if this is reallly needed or not, but it shouldn't hurt
    //       anything except performance to enable it
    lib.root_module.pic = true;
    return lib;
}

// Returns ziglibc as a CompileStep
// Caller will also need to add the include path to get the C headers
pub fn addLibc(builder: *std.Build, opt: ZigLibcOptions) *CompileStep {
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
    modules_options.addOption(bool, "glibcstart", switch (opt.start) {
        .glibc => true,
        else => false,
    });
    const index = relpath("src" ++ std.fs.path.sep_str ++ "lib.zig");
    const lib = switch (opt.link) {
        .static => builder.addStaticLibrary(.{
            .name = name,
            .root_source_file = index,
            .target = opt.target,
            .optimize = opt.optimize,
        }),
        .shared => builder.addSharedLibrary(.{
            .name = name,
            .root_source_file = index,
            .target = opt.target,
            .optimize = opt.optimize,
            .version = switch (opt.variant) {
                .full => .{ .major = 6, .minor = 0, .patch = 0 },
                else => null,
            },
        }),
    };
    // TODO: not sure if this is reallly needed or not, but it shouldn't hurt
    //       anything except performance to enable it
    lib.root_module.pic = true;
    lib.root_module.addOptions("modules", modules_options);
    lib.root_module.addOptions("trace_options", trace_options);
    const c_flags = [_][]const u8{
        "-std=c11",
    };
    const include_cstd = switch (opt.variant) {
        .only_std, .full => true,
        else => false,
    };
    modules_options.addOption(bool, "cstd", include_cstd);
    if (include_cstd) {
        lib.addCSourceFile(.{ .file = relpath("src" ++ std.fs.path.sep_str ++ "printf.c"), .flags = &c_flags });
        lib.addCSourceFile(.{ .file = relpath("src" ++ std.fs.path.sep_str ++ "scanf.c"), .flags = &c_flags });
        if (opt.target.result.os.tag == .linux) {
            lib.addAssemblyFile(relpath("src/linux/jmp.s"));
        }
    }
    const include_posix = switch (opt.variant) {
        .only_posix, .full => true,
        else => false,
    };
    modules_options.addOption(bool, "posix", include_posix);
    if (include_posix) {
        lib.addCSourceFile(.{ .file = relpath("src" ++ std.fs.path.sep_str ++ "posix.c"), .flags = &c_flags });
    }
    const include_linux = switch (opt.variant) {
        .only_linux, .full => true,
        else => false,
    };
    modules_options.addOption(bool, "linux", include_linux);
    if (include_cstd or include_posix) {
        lib.addIncludePath(relpath("inc" ++ std.fs.path.sep_str ++ "libc"));
        lib.addIncludePath(relpath("inc" ++ std.fs.path.sep_str ++ "posix"));
    }
    const include_gnu = switch (opt.variant) {
        .only_gnu, .full => true,
        else => false,
    };
    modules_options.addOption(bool, "gnu", include_gnu);
    if (include_gnu) {
        lib.addIncludePath(relpath("inc" ++ std.fs.path.sep_str ++ "gnu"));
    }
    return lib;
}
