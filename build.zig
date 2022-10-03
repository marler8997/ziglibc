const std = @import("std");
const GitRepoStep = @import("GitRepoStep.zig");
const libcbuild = @import("ziglibcbuild.zig");
const luabuild = @import("luabuild.zig");

pub fn build(b: *std.build.Builder) void {
    {
        const exe = b.addExecutable("genheaders", "src" ++ std.fs.path.sep_str ++ "genheaders.zig");
        const run = exe.run();
        run.addArg(b.pathFromRoot("capi.txt"));
        b.step("genheaders", "Generate C Headers").dependOn(&run.step);
    }

    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const zig_start = libcbuild.addZigStart(b);
    zig_start.setTarget(target);
    zig_start.setBuildMode(mode);
    zig_start.install();
    b.step("start", "").dependOn(&zig_start.install_step.?.step);

    const libc_full_static = libcbuild.addLibc(b, .{
        .variant = .full,
        .link = .static,
        .start = .ziglibc,
    });
    libc_full_static.setTarget(target);
    libc_full_static.setBuildMode(mode);
    libc_full_static.install();
    const libc_full_shared = libcbuild.addLibc(b, .{
        .variant = .full,
        .link = .shared,
        .start = .ziglibc,
    });
    libc_full_shared.setTarget(target);
    libc_full_shared.setBuildMode(mode);
    libc_full_shared.install();
    b.step("libc-full-shared", "").dependOn(&libc_full_shared.install_step.?.step);
    // TODO: create a specs file?
    //       you can add -specs=file to the gcc command line to override values in the spec

    const libc_only_std_static = libcbuild.addLibc(b, .{
        .variant = .only_std,
        .link = .static,
        .start = .ziglibc,
    });
    libc_only_std_static.setTarget(target);
    libc_only_std_static.setBuildMode(mode);
    libc_only_std_static.install();
    const libc_only_std_shared = libcbuild.addLibc(b, .{
        .variant = .only_std,
        .link = .shared,
        .start = .ziglibc,
    });
    libc_only_std_shared.setTarget(target);
    libc_only_std_shared.setBuildMode(mode);
    libc_only_std_shared.install();

    const libc_only_posix = libcbuild.addLibc(b, .{
        .variant = .only_posix,
        .link = .static,
        .start = .ziglibc,
    });
    libc_only_posix.setTarget(target);
    libc_only_posix.setBuildMode(mode);
    libc_only_posix.install();

    const libc_only_linux = libcbuild.addLibc(b, .{
        .variant = .only_linux,
        .link = .static,
        .start = .ziglibc,
    });
    libc_only_linux.setTarget(target);
    libc_only_linux.setBuildMode(mode);
    libc_only_linux.install();

    const libc_only_gnu = libcbuild.addLibc(b, .{
        .variant = .only_gnu,
        .link = .static,
        .start = .ziglibc,
    });
    libc_only_gnu.setTarget(target);
    libc_only_gnu.setBuildMode(mode);
    libc_only_gnu.install();

    const test_step = b.step("test", "Run unit tests");

    const test_env_exe = b.addExecutable("testenv", "test" ++ std.fs.path.sep_str ++ "testenv.zig");
    test_env_exe.setTarget(target);
    test_env_exe.setBuildMode(mode);

    {
        const exe = addTest("hello", b, target, mode, libc_only_std_static, zig_start);
        const run_step = exe.run();
        run_step.stdout_action = .{
            .expect_exact = "Hello\n",
        };
        test_step.dependOn(&run_step.step);
    }
    {
        const exe = addTest("strings", b, target, mode, libc_only_std_static, zig_start);
        const run_step = exe.run();
        run_step.stdout_action = .{
            .expect_exact = "Success!\n",
        };
        test_step.dependOn(&run_step.step);
    }
    {
        const exe = addTest("fs", b, target, mode, libc_only_std_static, zig_start);
        const run_step = test_env_exe.run();
        run_step.addArtifactArg(exe);
        run_step.stdout_action = .{
            .expect_exact = "Success!\n",
        };
        test_step.dependOn(&run_step.step);
    }
    {
        const exe = addTest("format", b, target, mode, libc_only_std_static, zig_start);
        const run_step = test_env_exe.run();
        run_step.addArtifactArg(exe);
        run_step.stdout_action = .{
            .expect_exact = "Success!\n",
        };
        test_step.dependOn(&run_step.step);
    }
    {
        const exe = addTest("types", b, target, mode, libc_only_std_static, zig_start);
        const run_step = exe.run();
        run_step.addArg(b.fmt("{}", .{@divExact(target.toTarget().cpu.arch.ptrBitWidth(), 8)}));
        run_step.stdout_action = .{
            .expect_exact = "Success!\n",
        };
        test_step.dependOn(&run_step.step);
    }
    {
        const exe = addTest("strto", b, target, mode, libc_only_std_static, zig_start);
        const run_step = exe.run();
        run_step.stdout_action = .{
            .expect_exact = "Success!\n",
        };
        test_step.dependOn(&run_step.step);
    }
    {
        const exe = addTest("getopt", b, target, mode, libc_only_std_static, zig_start);
        addPosix(exe, libc_only_posix);
        {
            const run = exe.run();
            run.stdout_action = .{ .expect_exact = "aflag=0, c_arg='(null)'\n" };
            test_step.dependOn(&run.step);
        }
        {
            const run = exe.run();
            run.addArgs(&.{ "-a" });
            run.stdout_action = .{ .expect_exact = "aflag=1, c_arg='(null)'\n" };
            test_step.dependOn(&run.step);
        }
        {
            const run = exe.run();
            run.addArgs(&.{ "-c", "hello" });
            run.stdout_action = .{ .expect_exact = "aflag=0, c_arg='hello'\n" };
            test_step.dependOn(&run.step);
        }
    }
    addLibcTest(b, target, mode, libc_only_std_static, zig_start, libc_only_posix);
    addTinyRegexCTests(b, target, mode, libc_only_std_static, zig_start, libc_only_posix);
    _ = addLua(b, target, mode, libc_only_std_static, zig_start);
    _ = addCmph(b, target, mode, libc_only_std_static, zig_start, libc_only_posix);
    _ = addYacc(b, target, mode, libc_only_std_static, zig_start, libc_only_posix);
    _ = addYabfc(b, target, mode, libc_only_std_static, zig_start, libc_only_posix, libc_only_gnu);
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
    libc_only_std_static: *std.build.LibExeObjStep,
    zig_start: *std.build.LibExeObjStep,
) *std.build.LibExeObjStep {
    const exe = b.addExecutable(name, "test" ++ std.fs.path.sep_str ++ name ++ ".c");
    exe.addCSourceFiles(&.{"test" ++ std.fs.path.sep_str ++ "expect.c"}, &[_][]const u8 { });
    exe.addIncludePath("inc" ++ std.fs.path.sep_str ++ "libc");
    exe.addIncludePath("inc" ++ std.fs.path.sep_str ++ "posix");
    exe.linkLibrary(libc_only_std_static);
    exe.linkLibrary(zig_start);
    exe.setTarget(target);
    exe.setBuildMode(mode);
    // TODO: should libc_only_std_static and zig_start be able to add library dependencies?
    if (target.getOs().tag == .windows) {
        exe.linkSystemLibrary("ntdll");
        exe.linkSystemLibrary("kernel32");
    }
    return exe;
}

fn addLibcTest(
    b: *std.build.Builder,
    target: anytype,
    mode: anytype,
    libc_only_std_static: *std.build.LibExeObjStep,
    zig_start: *std.build.LibExeObjStep,
    libc_only_posix: *std.build.LibExeObjStep,
) void {
    const libc_test_repo = GitRepoStep.create(b, .{
        .url = "git://nsz.repo.hu:49100/repo/libc-test",
        .sha = "b7ec467969a53756258778fa7d9b045f912d1c93",
        .branch = null,
    });
    const libc_test_path = libc_test_repo.path;
    const libc_test_step = b.step("libc-test", "run tests from the libc-test project");

    inline for (.{ "assert", "stddef", "string" } ) |name| {
        const lib = b.addObject("libc-test-api-" ++ name, b.pathJoin(&.{libc_test_path, "src", "api", name ++ ".c"}));
        lib.setTarget(target);
        lib.setBuildMode(mode);
        lib.addIncludePath("inc" ++ std.fs.path.sep_str ++ "libc");
        lib.step.dependOn(&libc_test_repo.step);
        libc_test_step.dependOn(&lib.step);
    }
    const libc_inc_path = b.pathJoin(&.{libc_test_path, "src", "common"});
    const common_src = &[_][]const u8 {
        b.pathJoin(&.{libc_test_path, "src", "common", "print.c"}),
    };

    // strtol, it seems there might be some disagreement between libc-test/glibc
    // about how strtoul interprets negative numbers, so leaving out strtol for now
    inline for (.{ "argv", "clock_gettime", "string" } ) |name| {
        const exe = b.addExecutable("libc-test-functional-" ++ name, b.pathJoin(&.{libc_test_path, "src", "functional", name ++ ".c"}));
        exe.addCSourceFiles(common_src, &[_][]const u8 {});
        exe.setTarget(target);
        exe.setBuildMode(mode);
        exe.step.dependOn(&libc_test_repo.step);
        exe.addIncludePath(libc_inc_path);
        exe.addIncludePath("inc" ++ std.fs.path.sep_str ++ "libc");
        exe.addIncludePath("inc" ++ std.fs.path.sep_str ++ "posix");
        exe.linkLibrary(libc_only_std_static);
        exe.linkLibrary(zig_start);
        exe.linkLibrary(libc_only_posix);
        // TODO: should libc_only_std_static and zig_start be able to add library dependencies?
        if (target.getOs().tag == .windows) {
            exe.linkSystemLibrary("ntdll");
            exe.linkSystemLibrary("kernel32");
        }
        libc_test_step.dependOn(&exe.run().step);
    }
}

fn addTinyRegexCTests(
    b: *std.build.Builder,
    target: anytype,
    mode: anytype,
    libc_only_std_static: *std.build.LibExeObjStep,
    zig_start: *std.build.LibExeObjStep,
    zig_posix: *std.build.LibExeObjStep,
) void {
    const repo = GitRepoStep.create(b, .{
        .url = "https://github.com/marler8997/tiny-regex-c",
        .sha = "95ef2ad35d36783d789b0ade3178b30a942f085c",
        .branch = "nocompile",
    });

    const re_step = b.step("re-tests", "run the tiny-regex-c tests");
    inline for (&[_][]const u8 { "test1", "test3" }) |test_name| {
        const exe = b.addExecutable("re" ++ test_name, null);
        exe.setTarget(target);
        exe.setBuildMode(mode);
        //exe.install();
        exe.step.dependOn(&repo.step);
        const repo_path = repo.getPath(&exe.step);
        var files = std.ArrayList([]const u8).init(b.allocator);
        const sources = [_][]const u8 {
            "re.c", "tests" ++ std.fs.path.sep_str ++ test_name ++ ".c",
        };
        for (sources) |src| {
            files.append(b.pathJoin(&.{repo_path, src})) catch unreachable;
        }

        exe.addCSourceFiles(files.toOwnedSlice(), &[_][]const u8 {
            "-std=c99",
        });
        exe.addIncludePath(repo_path);

        exe.addIncludePath("inc/libc");
        exe.addIncludePath("inc/posix");
        exe.linkLibrary(libc_only_std_static);
        exe.linkLibrary(zig_start);
        exe.linkLibrary(zig_posix);
        // TODO: should libc_only_std_static and zig_start be able to add library dependencies?
        if (target.getOs().tag == .windows) {
            exe.linkSystemLibrary("ntdll");
            exe.linkSystemLibrary("kernel32");
        }

        //const step = b.step("re", "build the re (tiny-regex-c) tool");
        //step.dependOn(&exe.install_step.?.step);
        const run = exe.run();
        re_step.dependOn(&run.step);
    }
}

fn addLua(
    b: *std.build.Builder,
    target: anytype,
    mode: anytype,
    libc_only_std_static: *std.build.LibExeObjStep,
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
    lua_exe.install();
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
        "-nostdinc",
        "-nostdlib",
        "-std=c99",
    });

    lua_exe.addIncludePath("inc" ++ std.fs.path.sep_str ++ "libc");
    lua_exe.linkLibrary(libc_only_std_static);
    lua_exe.linkLibrary(zig_start);

    const step = b.step("lua", "build the LUA interpreter");
    step.dependOn(&lua_exe.install_step.?.step);

    return lua_exe;
}

fn addCmph(
    b: *std.build.Builder,
    target: anytype,
    mode: anytype,
    libc_only_std_static: *std.build.LibExeObjStep,
    zig_start: *std.build.LibExeObjStep,
    zig_posix: *std.build.LibExeObjStep,
) *std.build.LibExeObjStep {
    const repo = GitRepoStep.create(b, .{
        //.url = "https://git.code.sf.net/p/cmph/git",
        .url = "https://github.com/bonitao/cmph",
        .sha = "abd5e1e17e4d51b3e24459ab9089dc0522846d0d",
        .branch = null,
    });

    const config_step = b.addWriteFile(
        b.pathJoin(&.{repo.path, "src", "config.h"}),
        "#define VERSION \"1.0\"",
    );
    config_step.step.dependOn(&repo.step);

    const exe = b.addExecutable("cmph", null);
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();
    exe.step.dependOn(&repo.step);
    exe.step.dependOn(&config_step.step);
    const repo_path = repo.getPath(&exe.step);
    var files = std.ArrayList([]const u8).init(b.allocator);
    const sources = [_][]const u8 {
        "main.c", "cmph.c", "hash.c", "chm.c", "bmz.c", "bmz8.c", "brz.c", "fch.c",
        "bdz.c", "bdz_ph.c", "chd_ph.c", "chd.c", "jenkins_hash.c", "graph.c", "vqueue.c",
        "buffer_manager.c", "fch_buckets.c", "miller_rabin.c", "compressed_seq.c",
        "compressed_rank.c", "buffer_entry.c", "select.c", "cmph_structs.c",
    };
    for (sources) |src| {
        files.append(b.pathJoin(&.{repo_path, "src", src})) catch unreachable;
    }

    exe.addCSourceFiles(files.toOwnedSlice(), &[_][]const u8 {
        "-std=c11",
    });

    exe.addIncludePath("inc/libc");
    exe.addIncludePath("inc/posix");
    exe.addIncludePath("inc/gnu");
    exe.linkLibrary(libc_only_std_static);
    exe.linkLibrary(zig_start);
    exe.linkLibrary(zig_posix);
    // TODO: should libc_only_std_static and zig_start be able to add library dependencies?
    if (target.getOs().tag == .windows) {
        exe.linkSystemLibrary("ntdll");
        exe.linkSystemLibrary("kernel32");
    }

    const step = b.step("cmph", "build the cmph tool");
    step.dependOn(&exe.install_step.?.step);

    return exe;
}

fn addYacc(
    b: *std.build.Builder,
    target: anytype,
    mode: anytype,
    libc_only_std_static: *std.build.LibExeObjStep,
    zig_start: *std.build.LibExeObjStep,
    zig_posix: *std.build.LibExeObjStep,
) *std.build.LibExeObjStep {
    const repo = GitRepoStep.create(b, .{
        .url = "https://github.com/ibara/yacc",
        .sha = "1a4138ce2385ec676c6d374245fda5a9cd2fbee2",
        .branch = null,
    });

    const config_step = b.addWriteFile(
        b.pathJoin(&.{repo.path, "config.h"}),
        \\// for simplicity just don't supported __unused
        \\#define __unused
        \\// for simplicity we're just not supporting noreturn
        \\#define __dead
        \\//#define HAVE_PROGNAME
        \\//#define HAVE_ASPRINTF
        \\//#define HAVE_PLEDGE
        \\//#define HAVE_REALLOCARRAY
        \\#define HAVE_STRLCPY
        \\
    );
    config_step.step.dependOn(&repo.step);
    const gen_progname_step = b.addWriteFile(
        b.pathJoin(&.{repo.path, "progname.c"}),
        \\// workaround __progname not defined, https://github.com/ibara/yacc/pull/1
        \\char *__progname;
        \\
    );
    gen_progname_step.step.dependOn(&repo.step);

    const exe = b.addExecutable("yacc", null);
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();
    exe.step.dependOn(&repo.step);
    exe.step.dependOn(&config_step.step);
    exe.step.dependOn(&gen_progname_step.step);
    const repo_path = repo.getPath(&exe.step);
    var files = std.ArrayList([]const u8).init(b.allocator);
    const sources = [_][]const u8 {
        "closure.c", "error.c", "lalr.c", "lr0.c", "main.c", "mkpar.c", "output.c", "reader.c",
        "skeleton.c", "symtab.c", "verbose.c", "warshall.c", "portable.c", "progname.c",
    };
    for (sources) |src| {
        files.append(b.pathJoin(&.{repo_path, src})) catch unreachable;
    }

    exe.addCSourceFiles(files.toOwnedSlice(), &[_][]const u8 {
        "-std=c90",
    });

    exe.addIncludePath("inc/libc");
    exe.addIncludePath("inc/posix");
    exe.linkLibrary(libc_only_std_static);
    exe.linkLibrary(zig_start);
    exe.linkLibrary(zig_posix);
    // TODO: should libc_only_std_static and zig_start be able to add library dependencies?
    if (target.getOs().tag == .windows) {
        exe.linkSystemLibrary("ntdll");
        exe.linkSystemLibrary("kernel32");
    }

    const step = b.step("yacc", "build the yacc tool");
    step.dependOn(&exe.install_step.?.step);

    return exe;
}

fn addYabfc(
    b: *std.build.Builder,
    target: anytype,
    mode: anytype,
    libc_only_std_static: *std.build.LibExeObjStep,
    zig_start: *std.build.LibExeObjStep,
    zig_posix: *std.build.LibExeObjStep,
    zig_gnu: *std.build.LibExeObjStep,
) *std.build.LibExeObjStep {
    const repo = GitRepoStep.create(b, .{
        .url = "https://github.com/julianneswinoga/yabfc",
        .sha = "a789be25a0918d330b7a4de12db0d33e0785f244",
        .branch = null,
    });

    const exe = b.addExecutable("yabfc", null);
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();
    exe.step.dependOn(&repo.step);
    const repo_path = repo.getPath(&exe.step);
    var files = std.ArrayList([]const u8).init(b.allocator);
    const sources = [_][]const u8 {
        "assembly.c", "elfHelper.c", "helpers.c", "optimize.c", "yabfc.c",
    };
    for (sources) |src| {
        files.append(b.pathJoin(&.{repo_path, src})) catch unreachable;
    }
    exe.addCSourceFiles(files.toOwnedSlice(), &[_][]const u8 {
        "-std=c99",
    });

    exe.addIncludePath("inc/libc");
    exe.addIncludePath("inc/posix");
    exe.addIncludePath("inc/linux");
    exe.addIncludePath("inc/gnu");
    exe.linkLibrary(libc_only_std_static);
    exe.linkLibrary(zig_start);
    exe.linkLibrary(zig_posix);
    exe.linkLibrary(zig_gnu);
    // TODO: should libc_only_std_static and zig_start be able to add library dependencies?
    if (target.getOs().tag == .windows) {
        exe.linkSystemLibrary("ntdll");
        exe.linkSystemLibrary("kernel32");
    }

    const step = b.step("yabfc", "build the yabfc tool (Yet Another BrainFuck Compiler)");
    step.dependOn(&exe.install_step.?.step);

    return exe;
}
