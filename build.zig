const std = @import("std");
const GitRepoStep = @import("GitRepoStep.zig");
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

    _ = addLua(b, target, mode, zig_libc);
}

fn addLua(
    b: *std.build.Builder,
    target: anytype,
    mode: anytype,
    zig_libc: *std.build.LibExeObjStep,
) *std.build.LibExeObjStep {
    const lua_repo = GitRepoStep.create(b, .{
        .url = "https://github.com/lua/lua",
        .sha = "5d708c3f9cae12820e415d4f89c9eacbe2ab964b",
        .branch = "v5.4.4",
    });
    const lua_exe = b.addExecutable("lua", null);
    lua_exe.setTarget(target);
    lua_exe.setBuildMode(mode);
    lua_exe.step.dependOn(&lua_repo.step);
    const lua_repo_path = lua_repo.getPath(&lua_exe.step);
    lua_exe.addCSourceFile(b.pathJoin(&.{lua_repo_path, "lua.c"}), &[_][]const u8 {
        "-std=c99",
    });

    lua_exe.addIncludePath("inc");
    lua_exe.linkLibrary(zig_libc);
    //lua_exe.linkLibrary(zig_start);

    const step = b.step("lua", "build the LUA interpreter");
    step.dependOn(&lua_exe.step);

    return lua_exe;
}