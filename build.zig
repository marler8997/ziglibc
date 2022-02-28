const std = @import("std");
const GitRepoStep = @import("GitRepoStep.zig");
const libcbuild = @import("ziglibcbuild.zig");
const luabuild = @import("luabuild.zig");

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

    const zig_lib_posix = libcbuild.addZigLibPosix(b, .{
        .link = .static,
    });
    zig_lib_posix.setTarget(target);
    zig_lib_posix.setBuildMode(mode);

    const test_step = b.step("test", "Run unit tests");

    const test_env_exe = b.addExecutable("testenv", "test" ++ std.fs.path.sep_str ++ "testenv.zig");
    test_env_exe.setTarget(target);
    test_env_exe.setBuildMode(mode);

    {
        const exe = addTest("hello", b, target, mode, zig_libc, zig_start);
        const run_step = exe.run();
        run_step.stdout_action = .{
            .expect_exact = "Hello\n",
        };
        test_step.dependOn(&run_step.step);
    }
    {
        const exe = addTest("strings", b, target, mode, zig_libc, zig_start);
        const run_step = exe.run();
        run_step.stdout_action = .{
            .expect_exact = "Success!\n",
        };
        test_step.dependOn(&run_step.step);
    }
    {
        const exe = addTest("fs", b, target, mode, zig_libc, zig_start);
        const run_step = test_env_exe.run();
        run_step.addArtifactArg(exe);
        run_step.stdout_action = .{
            .expect_exact = "Success!\n",
        };
        test_step.dependOn(&run_step.step);
    }
    {
        const exe = addTest("getopt", b, target, mode, zig_libc, zig_start);
        addPosix(exe, zig_lib_posix);
        const run_step = exe.run();
        run_step.stdout_action = .{
            .expect_exact = "Success!\n",
        };
        // NOTE: just build for now, until I implement getopt
        test_step.dependOn(&exe.step);
        //test_step.dependOn(&run_step.step);
    }
    {
        const libc_test_repo = GitRepoStep.create(b, .{
            .url = "git://nsz.repo.hu:49100/repo/libc-test",
            .sha = "b7ec467969a53756258778fa7d9b045f912d1c93",
            .branch = null,
        });
        const libc_test_path = libc_test_repo.path;
        const libc_test_step = b.step("libc-test", "run tests from the libc-test project");
        {
            const lib = b.addObject("string", b.pathJoin(&.{libc_test_path, "/src/api/string.c"}));
            lib.setTarget(target);
            lib.setBuildMode(mode);
            lib.addIncludePath("inc" ++ std.fs.path.sep_str ++ "libc");
            libc_test_step.dependOn(&lib.step);
        }
        const libc_inc_path = b.pathJoin(&.{libc_test_path, "src", "common"});
        const common_src = &[_][]const u8 {
            b.pathJoin(&.{libc_test_path, "src", "common", "print.c"}),
        };
        {
            const exe = b.addExecutable("string", b.pathJoin(&.{libc_test_path, "src", "functional", "string.c"}));
            exe.addCSourceFiles(common_src, &[_][]const u8 {});
            exe.setTarget(target);
            exe.setBuildMode(mode);
            exe.addIncludePath(libc_inc_path);
            exe.addIncludePath("inc" ++ std.fs.path.sep_str ++ "libc");
            exe.addIncludePath("inc" ++ std.fs.path.sep_str ++ "posix");
            exe.linkLibrary(zig_libc);
            exe.linkLibrary(zig_start);
            exe.linkLibrary(zig_lib_posix);
            libc_test_step.dependOn(&exe.run().step);
        }
    }

    _ = addLua(b, target, mode, zig_libc, zig_start);
}

fn addPosix(artifact: *std.build.LibExeObjStep, zig_posix: *std.build.LibExeObjStep) void {
    artifact.linkLibrary(zig_posix);
    artifact.addIncludePath("inc" ++ std.fs.path.sep_str ++ "posix");
}

fn addTest(
    comptime name: []const u8,
    b: *std.build.Builder,
    target: anytype,
    mode: anytype,
    zig_libc: *std.build.LibExeObjStep,
    zig_start: *std.build.LibExeObjStep,
) *std.build.LibExeObjStep {
    const exe = b.addExecutable(name, "test" ++ std.fs.path.sep_str ++ name ++ ".c");
    exe.addIncludePath("inc" ++ std.fs.path.sep_str ++ "libc");
    exe.linkLibrary(zig_libc);
    exe.linkLibrary(zig_start);
    exe.setTarget(target);
    exe.setBuildMode(mode);
    // TODO: should zig_libc and zig_start be able to add library dependencies?
    if (target.getOs().tag == .windows) {
        exe.linkSystemLibrary("ntdll");
        exe.linkSystemLibrary("kernel32");
    }
    return exe;
}

fn addLua(
    b: *std.build.Builder,
    target: anytype,
    mode: anytype,
    zig_libc: *std.build.LibExeObjStep,
    zig_start: *std.build.LibExeObjStep,
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
    var files = std.ArrayList([]const u8).init(b.allocator);
    files.append(b.pathJoin(&.{ lua_repo_path, "lua.c" })) catch unreachable;
    inline for (luabuild.core_objects) |obj| {
        files.append(b.pathJoin(&.{ lua_repo_path, obj ++ ".c" })) catch unreachable;
    }
    inline for (luabuild.aux_objects) |obj| {
        files.append(b.pathJoin(&.{ lua_repo_path, obj ++ ".c" })) catch unreachable;
    }
    inline for (luabuild.lib_objects) |obj| {
        files.append(b.pathJoin(&.{ lua_repo_path, obj ++ ".c" })) catch unreachable;
    }

    lua_exe.addCSourceFiles(files.toOwnedSlice(), &[_][]const u8{
        "-std=c99",
    });

    lua_exe.addIncludePath("inc" ++ std.fs.path.sep_str ++ "libc");
    lua_exe.linkLibrary(zig_libc);
    lua_exe.linkLibrary(zig_start);

    const step = b.step("lua", "build the LUA interpreter");
    step.dependOn(&lua_exe.step);

    return lua_exe;
}
