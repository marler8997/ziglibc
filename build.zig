const std = @import("std");

const libcbuild = @import("ziglibcbuild.zig");

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const zig_start = libcbuild.addZigStart(b);
    zig_start.setTarget(target);
    zig_start.setBuildMode(mode);

    const zig_libc = libcbuild.addZigLibc(b, .{
        .link = .static,
    });
    zig_libc.setTarget(target);
    zig_libc.setBuildMode(mode);

    const exe = b.addExecutable("hello", "src" ++ std.fs.path.sep_str ++ "hello.c");
    exe.addIncludePath("inc");
    exe.linkLibrary(zig_libc);
    exe.linkLibrary(zig_start);
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest("src/main.zig");
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
