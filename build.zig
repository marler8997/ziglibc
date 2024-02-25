const std = @import("std");
const GitRepoStep = @import("GitRepoStep.zig");
const libcbuild = @import("ziglibcbuild.zig");
const luabuild = @import("luabuild.zig");
const awkbuild = @import("awkbuild.zig");
const gnumakebuild = @import("gnumakebuild.zig");

pub fn build(b: *std.Build) void {
    const trace_enabled = b.option(bool, "trace", "enable libc tracing") orelse false;

    {
        const exe = b.addExecutable(.{
            .name = "genheaders",
            .root_source_file = .{ .path = "src" ++ std.fs.path.sep_str ++ "genheaders.zig" },
            .target = b.host,
        });
        const run = b.addRunArtifact(exe);
        run.addArg(b.pathFromRoot("capi.txt"));
        b.step("genheaders", "Generate C Headers").dependOn(&run.step);
    }

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zig_start = libcbuild.addZigStart(b, target, optimize);
    b.step("start", "").dependOn(&installArtifact(b, zig_start).step);

    const libc_full_static = libcbuild.addLibc(b, .{
        .variant = .full,
        .link = .static,
        .start = .ziglibc,
        .trace = trace_enabled,
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(libc_full_static);
    const libc_full_shared = libcbuild.addLibc(b, .{
        .variant = .full,
        .link = .shared,
        .start = .ziglibc,
        .trace = trace_enabled,
        .target = target,
        .optimize = optimize,
    });
    b.step("libc-full-shared", "").dependOn(&installArtifact(b, libc_full_shared).step);
    // TODO: create a specs file?
    //       you can add -specs=file to the gcc command line to override values in the spec

    const libc_only_std_static = libcbuild.addLibc(b, .{
        .variant = .only_std,
        .link = .static,
        .start = .ziglibc,
        .trace = trace_enabled,
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(libc_only_std_static);
    const libc_only_std_shared = libcbuild.addLibc(b, .{
        .variant = .only_std,
        .link = .shared,
        .start = .ziglibc,
        .trace = trace_enabled,
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(libc_only_std_shared);

    const libc_only_posix = libcbuild.addLibc(b, .{
        .variant = .only_posix,
        .link = .static,
        .start = .ziglibc,
        .trace = trace_enabled,
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(libc_only_posix);

    const libc_only_linux = libcbuild.addLibc(b, .{
        .variant = .only_linux,
        .link = .static,
        .start = .ziglibc,
        .trace = trace_enabled,
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(libc_only_linux);

    const libc_only_gnu = libcbuild.addLibc(b, .{
        .variant = .only_gnu,
        .link = .static,
        .start = .ziglibc,
        .trace = trace_enabled,
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(libc_only_gnu);

    const test_step = b.step("test", "Run unit tests");

    const test_env_exe = b.addExecutable(.{
        .name = "testenv",
        .root_source_file = .{ .path = "test" ++ std.fs.path.sep_str ++ "testenv.zig" },
        .target = target,
        .optimize = optimize,
    });

    {
        const exe = addTest("hello", b, target, optimize, libc_only_std_static, zig_start);
        const run_step = b.addRunArtifact(exe);
        run_step.addCheck(.{ .expect_stdout_exact = "Hello\n" });
        test_step.dependOn(&run_step.step);
    }
    {
        const exe = addTest("strings", b, target, optimize, libc_only_std_static, zig_start);
        const run_step = b.addRunArtifact(exe);
        run_step.addCheck(.{ .expect_stdout_exact = "Success!\n" });
        test_step.dependOn(&run_step.step);
    }
    {
        const exe = addTest("fs", b, target, optimize, libc_only_std_static, zig_start);
        const run_step = b.addRunArtifact(test_env_exe);
        run_step.addArtifactArg(exe);
        run_step.addCheck(.{ .expect_stdout_exact = "Success!\n" });
        test_step.dependOn(&run_step.step);
    }
    {
        const exe = addTest("format", b, target, optimize, libc_only_std_static, zig_start);
        const run_step = b.addRunArtifact(test_env_exe);
        run_step.addArtifactArg(exe);
        run_step.addCheck(.{ .expect_stdout_exact = "Success!\n" });
        test_step.dependOn(&run_step.step);
    }
    {
        const exe = addTest("types", b, target, optimize, libc_only_std_static, zig_start);
        const run_step = b.addRunArtifact(exe);
        run_step.addArg(b.fmt("{}", .{@divExact(target.result.ptrBitWidth(), 8)}));
        run_step.addCheck(.{ .expect_stdout_exact = "Success!\n" });
        test_step.dependOn(&run_step.step);
    }
    {
        const exe = addTest("scanf", b, target, optimize, libc_only_std_static, zig_start);
        const run_step = b.addRunArtifact(exe);
        run_step.addCheck(.{ .expect_stdout_exact = "Success!\n" });
        test_step.dependOn(&run_step.step);
    }
    {
        const exe = addTest("strto", b, target, optimize, libc_only_std_static, zig_start);
        const run_step = b.addRunArtifact(exe);
        run_step.addCheck(.{ .expect_stdout_exact = "Success!\n" });
        test_step.dependOn(&run_step.step);
    }
    {
        const exe = addTest("getopt", b, target, optimize, libc_only_std_static, zig_start);
        addPosix(exe, libc_only_posix);
        {
            const run = b.addRunArtifact(exe);
            run.addCheck(.{ .expect_stdout_exact = "aflag=0, c_arg='(null)'\n" });
            test_step.dependOn(&run.step);
        }
        {
            const run = b.addRunArtifact(exe);
            run.addArgs(&.{"-a"});
            run.addCheck(.{ .expect_stdout_exact = "aflag=1, c_arg='(null)'\n" });
            test_step.dependOn(&run.step);
        }
        {
            const run = b.addRunArtifact(exe);
            run.addArgs(&.{ "-c", "hello" });
            run.addCheck(.{ .expect_stdout_exact = "aflag=0, c_arg='hello'\n" });
            test_step.dependOn(&run.step);
        }
    }

    // this test only works on linux right now
    if (target.result.os.tag == .linux) {
        const exe = addTest("jmp", b, target, optimize, libc_only_std_static, zig_start);
        const run_step = b.addRunArtifact(exe);
        run_step.addCheck(.{ .expect_stdout_exact = "Success!\n" });
        test_step.dependOn(&run_step.step);
    }

    addLibcTest(b, target, optimize, libc_only_std_static, zig_start, libc_only_posix);
    addTinyRegexCTests(b, target, optimize, libc_only_std_static, zig_start, libc_only_posix);
    _ = addLua(b, target, optimize, libc_only_std_static, libc_only_posix, zig_start);
    _ = addCmph(b, target, optimize, libc_only_std_static, zig_start, libc_only_posix);
    _ = addYacc(b, target, optimize, libc_only_std_static, zig_start, libc_only_posix);
    _ = addYabfc(b, target, optimize, libc_only_std_static, zig_start, libc_only_posix, libc_only_gnu);
    _ = addSecretGame(b, target, optimize, libc_only_std_static, zig_start, libc_only_posix, libc_only_gnu);
    _ = awkbuild.addAwk(b, target, optimize, libc_only_std_static, libc_only_posix, zig_start);
    _ = gnumakebuild.addGnuMake(b, target, optimize, libc_only_std_static, libc_only_posix, zig_start);
}

// re-implements Build.installArtifact but also returns it
fn installArtifact(b: *std.Build, artifact: anytype) *std.Build.Step.InstallArtifact {
    const install = b.addInstallArtifact(artifact, .{});
    b.getInstallStep().dependOn(&install.step);
    return install;
}

fn addPosix(artifact: *std.Build.Step.Compile, zig_posix: *std.Build.Step.Compile) void {
    artifact.linkLibrary(zig_posix);
    artifact.addIncludePath(.{ .path = "inc" ++ std.fs.path.sep_str ++ "posix" });
}

fn addTest(
    comptime name: []const u8,
    b: *std.Build,
    target: anytype,
    optimize: anytype,
    libc_only_std_static: *std.Build.Step.Compile,
    zig_start: *std.Build.Step.Compile,
) *std.Build.Step.Compile {
    const exe = b.addExecutable(.{
        .name = name,
        .target = target,
        .optimize = optimize,
    });
    exe.addCSourceFile(.{ .file = .{ .path = "test" ++ std.fs.path.sep_str ++ name ++ ".c" } });
    exe.addCSourceFiles(.{
        .files = &.{"test" ++ std.fs.path.sep_str ++ "expect.c"},
    });
    exe.addIncludePath(.{ .path = "inc" ++ std.fs.path.sep_str ++ "libc" });
    exe.addIncludePath(.{ .path = "inc" ++ std.fs.path.sep_str ++ "posix" });
    exe.linkLibrary(libc_only_std_static);
    exe.linkLibrary(zig_start);
    // TODO: should libc_only_std_static and zig_start be able to add library dependencies?
    if (target.result.os.tag == .windows) {
        exe.linkSystemLibrary("ntdll");
        exe.linkSystemLibrary("kernel32");
    }
    return exe;
}

fn addLibcTest(
    b: *std.Build,
    target: anytype,
    optimize: anytype,
    libc_only_std_static: *std.Build.Step.Compile,
    zig_start: *std.Build.Step.Compile,
    libc_only_posix: *std.Build.Step.Compile,
) void {
    const libc_test_repo = GitRepoStep.create(b, .{
        .url = "git://nsz.repo.hu:49100/repo/libc-test",
        .sha = "b7ec467969a53756258778fa7d9b045f912d1c93",
        .branch = null,
        .fetch_enabled = true,
    });
    const libc_test_path = libc_test_repo.path;
    const libc_test_step = b.step("libc-test", "run tests from the libc-test project");

    // inttypes
    inline for (.{ "assert", "ctype", "errno", "main", "stdbool", "stddef", "string" }) |name| {
        const lib = b.addObject(.{
            .name = "libc-test-api-" ++ name,
            .target = target,
            .optimize = optimize,
        });
        lib.addCSourceFile(.{ .file = .{ .path = b.pathJoin(&.{ libc_test_path, "src", "api", name ++ ".c" }) } });
        lib.addIncludePath(.{ .path = "inc" ++ std.fs.path.sep_str ++ "libc" });
        lib.step.dependOn(&libc_test_repo.step);
        libc_test_step.dependOn(&lib.step);
    }
    const libc_inc_path = b.pathJoin(&.{ libc_test_path, "src", "common" });
    const common_src = &[_][]const u8{
        b.pathJoin(&.{ libc_test_path, "src", "common", "print.c" }),
    };

    // strtol, it seems there might be some disagreement between libc-test/glibc
    // about how strtoul interprets negative numbers, so leaving out strtol for now
    inline for (.{ "argv", "basename", "clock_gettime", "string" }) |name| {
        const exe = b.addExecutable(.{
            .name = "libc-test-functional-" ++ name,
            .target = target,
            .optimize = optimize,
        });
        exe.addCSourceFile(.{ .file = .{ .path = b.pathJoin(&.{ libc_test_path, "src", "functional", name ++ ".c" }) } });
        exe.addCSourceFiles(.{ .files = common_src });
        exe.step.dependOn(&libc_test_repo.step);
        exe.addIncludePath(.{ .path = libc_inc_path });
        exe.addIncludePath(.{ .path = "inc" ++ std.fs.path.sep_str ++ "libc" });
        exe.addIncludePath(.{ .path = "inc" ++ std.fs.path.sep_str ++ "posix" });
        exe.linkLibrary(libc_only_std_static);
        exe.linkLibrary(zig_start);
        exe.linkLibrary(libc_only_posix);
        // TODO: should libc_only_std_static and zig_start be able to add library dependencies?
        if (target.result.os.tag == .windows) {
            exe.linkSystemLibrary("ntdll");
            exe.linkSystemLibrary("kernel32");
        }
        libc_test_step.dependOn(&b.addRunArtifact(exe).step);
    }
}

fn addTinyRegexCTests(
    b: *std.Build,
    target: anytype,
    optimize: anytype,
    libc_only_std_static: *std.Build.Step.Compile,
    zig_start: *std.Build.Step.Compile,
    zig_posix: *std.Build.Step.Compile,
) void {
    const repo = GitRepoStep.create(b, .{
        .url = "https://github.com/marler8997/tiny-regex-c",
        .sha = "95ef2ad35d36783d789b0ade3178b30a942f085c",
        .branch = "nocompile",
        .fetch_enabled = true,
    });

    const re_step = b.step("re-tests", "run the tiny-regex-c tests");
    inline for (&[_][]const u8{ "test1", "test3" }) |test_name| {
        const exe = b.addExecutable(.{
            .name = "re" ++ test_name,
            .target = target,
            .optimize = optimize,
        });
        //b.installArtifact(exe);
        exe.step.dependOn(&repo.step);
        const repo_path = repo.getPath(&exe.step);
        var files = std.ArrayList([]const u8).init(b.allocator);
        const sources = [_][]const u8{
            "re.c", "tests" ++ std.fs.path.sep_str ++ test_name ++ ".c",
        };
        for (sources) |src| {
            files.append(b.pathJoin(&.{ repo_path, src })) catch unreachable;
        }

        exe.addCSourceFiles(.{
            .files = files.toOwnedSlice() catch unreachable,
            .flags = &[_][]const u8{"-std=c99"},
        });
        exe.addIncludePath(.{ .path = repo_path });

        exe.addIncludePath(.{ .path = "inc/libc" });
        exe.addIncludePath(.{ .path = "inc/posix" });
        exe.linkLibrary(libc_only_std_static);
        exe.linkLibrary(zig_start);
        exe.linkLibrary(zig_posix);
        // TODO: should libc_only_std_static and zig_start be able to add library dependencies?
        if (target.result.os.tag == .windows) {
            exe.linkSystemLibrary("ntdll");
            exe.linkSystemLibrary("kernel32");
        }

        //const step = b.step("re", "build the re (tiny-regex-c) tool");
        //step.dependOn(&exe.install_step.?.step);
        const run = b.addRunArtifact(exe);
        re_step.dependOn(&run.step);
    }
}

fn addLua(
    b: *std.Build,
    target: anytype,
    optimize: anytype,
    libc_only_std_static: *std.Build.Step.Compile,
    libc_only_posix: *std.Build.Step.Compile,
    zig_start: *std.Build.Step.Compile,
) *std.Build.Step.Compile {
    const lua_repo = GitRepoStep.create(b, .{
        .url = "https://github.com/lua/lua",
        .sha = "5d708c3f9cae12820e415d4f89c9eacbe2ab964b",
        .branch = "v5.4.4",
        .fetch_enabled = true,
    });
    const lua_exe = b.addExecutable(.{
        .name = "lua",
        .target = target,
        .optimize = optimize,
    });
    lua_exe.step.dependOn(&lua_repo.step);
    const install = b.addInstallArtifact(lua_exe, .{});
    // doesn't compile for windows for some reason
    if (target.result.os.tag != .windows) {
        b.getInstallStep().dependOn(&install.step);
    }
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

    lua_exe.addCSourceFiles(.{
        .files = files.toOwnedSlice() catch unreachable,
        .flags = &[_][]const u8{
            "-nostdinc",
            "-nostdlib",
            "-std=c99",
        },
    });

    lua_exe.addIncludePath(.{ .path = "inc" ++ std.fs.path.sep_str ++ "libc" });
    lua_exe.linkLibrary(libc_only_std_static);
    lua_exe.linkLibrary(libc_only_posix);
    lua_exe.linkLibrary(zig_start);
    // TODO: should libc_only_std_static and zig_start be able to add library dependencies?
    if (target.result.os.tag == .windows) {
        lua_exe.addIncludePath(.{ .path = "inc/win32" });
        lua_exe.linkSystemLibrary("ntdll");
        lua_exe.linkSystemLibrary("kernel32");
    }

    const step = b.step("lua", "build/install the LUA interpreter");
    step.dependOn(&install.step);

    const test_step = b.step("lua-test", "Run the lua tests");

    for ([_][]const u8{ "bwcoercion.lua", "tracegc.lua" }) |test_file| {
        var run_test = b.addRunArtifact(lua_exe);
        run_test.addArg(b.pathJoin(&.{ lua_repo_path, "testes", test_file }));
        test_step.dependOn(&run_test.step);
    }

    return lua_exe;
}

fn addCmph(
    b: *std.Build,
    target: anytype,
    optimize: anytype,
    libc_only_std_static: *std.Build.Step.Compile,
    zig_start: *std.Build.Step.Compile,
    zig_posix: *std.Build.Step.Compile,
) *std.Build.Step.Compile {
    const repo = GitRepoStep.create(b, .{
        //.url = "https://git.code.sf.net/p/cmph/git",
        .url = "https://github.com/bonitao/cmph",
        .sha = "abd5e1e17e4d51b3e24459ab9089dc0522846d0d",
        .branch = null,
        .fetch_enabled = true,
    });

    const config_step = b.addWriteFile(
        b.pathJoin(&.{ repo.path, "src", "config.h" }),
        "#define VERSION \"1.0\"",
    );
    config_step.step.dependOn(&repo.step);

    const exe = b.addExecutable(.{
        .name = "cmph",
        .target = target,
        .optimize = optimize,
    });
    const install = installArtifact(b, exe);
    exe.step.dependOn(&repo.step);
    exe.step.dependOn(&config_step.step);
    const repo_path = repo.getPath(&exe.step);
    var files = std.ArrayList([]const u8).init(b.allocator);
    const sources = [_][]const u8{
        "main.c",        "cmph.c",         "hash.c",           "chm.c",             "bmz.c",          "bmz8.c",   "brz.c",          "fch.c",
        "bdz.c",         "bdz_ph.c",       "chd_ph.c",         "chd.c",             "jenkins_hash.c", "graph.c",  "vqueue.c",       "buffer_manager.c",
        "fch_buckets.c", "miller_rabin.c", "compressed_seq.c", "compressed_rank.c", "buffer_entry.c", "select.c", "cmph_structs.c",
    };
    for (sources) |src| {
        files.append(b.pathJoin(&.{ repo_path, "src", src })) catch unreachable;
    }

    exe.addCSourceFiles(.{
        .files = files.toOwnedSlice() catch unreachable,
        .flags = &[_][]const u8{
            "-std=c11",
        },
    });

    exe.addIncludePath(.{ .path = "inc/libc" });
    exe.addIncludePath(.{ .path = "inc/posix" });
    exe.addIncludePath(.{ .path = "inc/gnu" });
    exe.linkLibrary(libc_only_std_static);
    exe.linkLibrary(zig_start);
    exe.linkLibrary(zig_posix);
    // TODO: should libc_only_std_static and zig_start be able to add library dependencies?
    if (target.result.os.tag == .windows) {
        exe.linkSystemLibrary("ntdll");
        exe.linkSystemLibrary("kernel32");
    }

    const step = b.step("cmph", "build the cmph tool");
    step.dependOn(&install.step);

    return exe;
}

fn addYacc(
    b: *std.Build,
    target: anytype,
    optimize: anytype,
    libc_only_std_static: *std.Build.Step.Compile,
    zig_start: *std.Build.Step.Compile,
    zig_posix: *std.Build.Step.Compile,
) *std.Build.Step.Compile {
    const repo = GitRepoStep.create(b, .{
        .url = "https://github.com/ibara/yacc",
        .sha = "1a4138ce2385ec676c6d374245fda5a9cd2fbee2",
        .branch = null,
        .fetch_enabled = true,
    });

    const config_step = b.addWriteFile(b.pathJoin(&.{ repo.path, "config.h" }),
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
    const gen_progname_step = b.addWriteFile(b.pathJoin(&.{ repo.path, "progname.c" }),
        \\// workaround __progname not defined, https://github.com/ibara/yacc/pull/1
        \\char *__progname;
        \\
    );
    gen_progname_step.step.dependOn(&repo.step);

    const exe = b.addExecutable(.{
        .name = "yacc",
        .target = target,
        .optimize = optimize,
    });
    const install = installArtifact(b, exe);
    exe.step.dependOn(&repo.step);
    exe.step.dependOn(&config_step.step);
    exe.step.dependOn(&gen_progname_step.step);
    const repo_path = repo.getPath(&exe.step);
    var files = std.ArrayList([]const u8).init(b.allocator);
    const sources = [_][]const u8{
        "closure.c",  "error.c",  "lalr.c",    "lr0.c",      "main.c",     "mkpar.c",    "output.c", "reader.c",
        "skeleton.c", "symtab.c", "verbose.c", "warshall.c", "portable.c", "progname.c",
    };
    for (sources) |src| {
        files.append(b.pathJoin(&.{ repo_path, src })) catch unreachable;
    }

    exe.addCSourceFiles(.{
        .files = files.toOwnedSlice() catch unreachable,
        .flags = &[_][]const u8{
            "-std=c90",
        },
    });

    exe.addIncludePath(.{ .path = "inc/libc" });
    exe.addIncludePath(.{ .path = "inc/posix" });
    exe.linkLibrary(libc_only_std_static);
    exe.linkLibrary(zig_start);
    exe.linkLibrary(zig_posix);
    // TODO: should libc_only_std_static and zig_start be able to add library dependencies?
    if (target.result.os.tag == .windows) {
        exe.linkSystemLibrary("ntdll");
        exe.linkSystemLibrary("kernel32");
    }

    const step = b.step("yacc", "build the yacc tool");
    step.dependOn(&install.step);

    return exe;
}

fn addYabfc(
    b: *std.Build,
    target: anytype,
    optimize: anytype,
    libc_only_std_static: *std.Build.Step.Compile,
    zig_start: *std.Build.Step.Compile,
    zig_posix: *std.Build.Step.Compile,
    zig_gnu: *std.Build.Step.Compile,
) *std.Build.Step.Compile {
    const repo = GitRepoStep.create(b, .{
        .url = "https://github.com/julianneswinoga/yabfc",
        .sha = "a789be25a0918d330b7a4de12db0d33e0785f244",
        .branch = null,
        .fetch_enabled = true,
    });

    const exe = b.addExecutable(.{
        .name = "yabfc",
        .target = target,
        .optimize = optimize,
    });
    const install = installArtifact(b, exe);
    exe.step.dependOn(&repo.step);
    const repo_path = repo.getPath(&exe.step);
    var files = std.ArrayList([]const u8).init(b.allocator);
    const sources = [_][]const u8{
        "assembly.c", "elfHelper.c", "helpers.c", "optimize.c", "yabfc.c",
    };
    for (sources) |src| {
        files.append(b.pathJoin(&.{ repo_path, src })) catch unreachable;
    }
    exe.addCSourceFiles(.{
        .files = files.toOwnedSlice() catch unreachable,
        .flags = &[_][]const u8{
            "-std=c99",
        },
    });

    exe.addIncludePath(.{ .path = "inc/libc" });
    exe.addIncludePath(.{ .path = "inc/posix" });
    exe.addIncludePath(.{ .path = "inc/linux" });
    exe.addIncludePath(.{ .path = "inc/gnu" });
    exe.linkLibrary(libc_only_std_static);
    exe.linkLibrary(zig_start);
    exe.linkLibrary(zig_posix);
    exe.linkLibrary(zig_gnu);
    // TODO: should libc_only_std_static and zig_start be able to add library dependencies?
    if (target.result.os.tag == .windows) {
        exe.linkSystemLibrary("ntdll");
        exe.linkSystemLibrary("kernel32");
    }

    const step = b.step("yabfc", "build/install the yabfc tool (Yet Another BrainFuck Compiler)");
    step.dependOn(&install.step);

    return exe;
}

fn addSecretGame(
    b: *std.Build,
    target: anytype,
    optimize: anytype,
    libc_only_std_static: *std.Build.Step.Compile,
    zig_start: *std.Build.Step.Compile,
    zig_posix: *std.Build.Step.Compile,
    zig_gnu: *std.Build.Step.Compile,
) *std.Build.Step.Compile {
    const repo = GitRepoStep.create(b, .{
        .url = "https://github.com/ethinethin/Secret",
        .sha = "8ec8442f84f8bed2cb3985455e7af4d1ce605401",
        .branch = null,
        .fetch_enabled = true,
    });

    const exe = b.addExecutable(.{
        .name = "secret",
        .target = target,
        .optimize = optimize,
    });
    const install = b.addInstallArtifact(exe, .{});
    exe.step.dependOn(&repo.step);
    const repo_path = repo.getPath(&exe.step);
    var files = std.ArrayList([]const u8).init(b.allocator);
    const sources = [_][]const u8{
        "main.c", "inter.c", "input.c", "items.c", "rooms.c", "linenoise/linenoise.c",
    };
    for (sources) |src| {
        files.append(b.pathJoin(&.{ repo_path, src })) catch unreachable;
    }
    exe.addCSourceFiles(.{
        .files = files.toOwnedSlice() catch unreachable,
        .flags = &[_][]const u8{
            "-std=c90",
        },
    });

    exe.addIncludePath(.{ .path = "inc/libc" });
    exe.addIncludePath(.{ .path = "inc/posix" });
    exe.addIncludePath(.{ .path = "inc/linux" });
    exe.addIncludePath(.{ .path = "inc/gnu" });
    exe.linkLibrary(libc_only_std_static);
    exe.linkLibrary(zig_start);
    exe.linkLibrary(zig_posix);
    exe.linkLibrary(zig_gnu);
    // TODO: should libc_only_std_static and zig_start be able to add library dependencies?
    if (target.result.os.tag == .windows) {
        exe.linkSystemLibrary("ntdll");
        exe.linkSystemLibrary("kernel32");
    }

    const step = b.step("secret", "build/install the secret game");
    step.dependOn(&install.step);

    return exe;
}
