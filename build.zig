const std = @import("std");
const GitRepoStep = @import("GitRepoStep.zig");
const libcbuild = @import("ziglibcbuild.zig");
const luabuild = @import("luabuild.zig");
const awkbuild = @import("awkbuild.zig");
const gnumakebuild = @import("gnumakebuild.zig");

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const trace_enabled = b.option(bool, "trace", "enable libc tracing") orelse false;

    const opt_variant = b.option(libcbuild.LibVariant, "variant", "Defines which variant should be built. Can be: only_std, only_posix, only_linux, only_gnu, full") orelse .full;
    const opt_link = b.option(libcbuild.LinkKind, "link", "Defines if it's a static or shared build") orelse .static;
    const opt_start = b.option(libcbuild.Start, "start", "Defines what startup mode should be used. Can be one of none, ziglibc or glibc.") orelse .ziglibc;

    const test_step = b.step("test", "Run unit tests");
    const all_step = b.step("all", "builds all variants of the library");

    {
        const exe = b.addExecutable(.{
            .name = "genheaders",
            .root_source_file = .{ .path = "src" ++ std.fs.path.sep_str ++ "genheaders.zig" },
        });
        const run = b.addRunArtifact(exe);
        run.addArg(b.pathFromRoot("capi.txt"));
        b.step("genheaders", "Generate C Headers").dependOn(&run.step);
    }

    // Export the ziglibc headers
    b.installDirectory(.{
        .source_dir = "inc",
        .install_dir = .header,
        .install_subdir = "cguana",
    });

    const zig_start = libcbuild.addZigStart(b, target, optimize);
    const install_start = b.addInstallArtifact(zig_start);
    b.step("start", "").dependOn(&install_start.step);
    all_step.dependOn(&install_start.step);
    if (opt_start != .none) {
        b.getInstallStep().dependOn(&install_start.step);
    }

    const libc_user_configured = libcbuild.addLibc(b, .{
        .variant = opt_variant,
        .link = opt_link,
        .start = opt_start,
        .trace = trace_enabled,
        .target = target,
        .optimize = optimize,
        .name = .{ .explicit = "cguana" },
    });
    const install_user_configured = b.addInstallArtifact(libc_user_configured);
    b.getInstallStep().dependOn(&install_user_configured.step);
    all_step.dependOn(&install_user_configured.step);

    const libc_full_static = libcbuild.addLibc(b, .{
        .variant = .full,
        .link = .static,
        .start = .ziglibc,
        .trace = trace_enabled,
        .target = target,
        .optimize = optimize,
        .name = .auto,
    });
    all_step.dependOn(&b.addInstallArtifact(libc_full_static).step);

    const libc_full_shared = libcbuild.addLibc(b, .{
        .variant = .full,
        .link = .shared,
        .start = .ziglibc,
        .trace = trace_enabled,
        .target = target,
        .optimize = optimize,
        .name = .auto,
    });
    b.step("libc-full-shared", "").dependOn(&b.addInstallArtifact(libc_full_shared).step);
    // TODO: create a specs file?
    //       you can add -specs=file to the gcc command line to override values in the spec

    const libc_only_std_static = libcbuild.addLibc(b, .{
        .variant = .only_std,
        .link = .static,
        .start = .ziglibc,
        .trace = trace_enabled,
        .target = target,
        .optimize = optimize,
        .name = .auto,
    });
    all_step.dependOn(&b.addInstallArtifact(libc_only_std_static).step);

    const libc_only_std_shared = libcbuild.addLibc(b, .{
        .variant = .only_std,
        .link = .shared,
        .start = .ziglibc,
        .trace = trace_enabled,
        .target = target,
        .optimize = optimize,
        .name = .auto,
    });
    all_step.dependOn(&b.addInstallArtifact(libc_only_std_shared).step);

    const libc_only_posix = libcbuild.addLibc(b, .{
        .variant = .only_posix,
        .link = .static,
        .start = .ziglibc,
        .trace = trace_enabled,
        .target = target,
        .optimize = optimize,
        .name = .auto,
    });
    all_step.dependOn(&b.addInstallArtifact(libc_only_posix).step);

    const libc_only_linux = libcbuild.addLibc(b, .{
        .variant = .only_linux,
        .link = .static,
        .start = .ziglibc,
        .trace = trace_enabled,
        .target = target,
        .optimize = optimize,
        .name = .auto,
    });
    all_step.dependOn(&b.addInstallArtifact(libc_only_linux).step);

    const libc_only_gnu = libcbuild.addLibc(b, .{
        .variant = .only_gnu,
        .link = .static,
        .start = .ziglibc,
        .trace = trace_enabled,
        .target = target,
        .optimize = optimize,
        .name = .auto,
    });
    all_step.dependOn(&b.addInstallArtifact(libc_only_gnu).step);

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
        run_step.addArg(b.fmt("{}", .{@divExact(target.toTarget().ptrBitWidth(), 8)}));
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
    if (target.getOsTag() == .linux) {
        const exe = addTest("jmp", b, target, optimize, libc_only_std_static, zig_start);
        const run_step = b.addRunArtifact(exe);
        run_step.addCheck(.{ .expect_stdout_exact = "Success!\n" });
        test_step.dependOn(&run_step.step);
    }

    addLibcTest(b, target, optimize, libc_only_std_static, zig_start, libc_only_posix, all_step);
    addTinyRegexCTests(b, target, optimize, libc_only_std_static, zig_start, libc_only_posix, all_step);
    _ = addLua(b, target, optimize, libc_only_std_static, libc_only_posix, zig_start, all_step);
    _ = addCmph(b, target, optimize, libc_only_std_static, zig_start, libc_only_posix, all_step);
    _ = addYacc(b, target, optimize, libc_only_std_static, zig_start, libc_only_posix, all_step);
    _ = addYabfc(b, target, optimize, libc_only_std_static, zig_start, libc_only_posix, libc_only_gnu, all_step);
    _ = addSecretGame(b, target, optimize, libc_only_std_static, zig_start, libc_only_posix, libc_only_gnu, all_step);
    _ = awkbuild.addAwk(b, target, optimize, libc_only_std_static, libc_only_posix, zig_start, all_step);
    _ = gnumakebuild.addGnuMake(b, target, optimize, libc_only_std_static, libc_only_posix, zig_start, all_step);

    _ = @import("busybox/build.zig").add(b, target, optimize, libc_only_std_static, libc_only_posix, all_step);
    _ = @import("ncurses/build.zig").add(b, target, optimize, libc_only_std_static, libc_only_posix, all_step);
}

// re-implements Build.installArtifact but also returns it
// fn installArtifact(b: *std.Build, artifact: anytype) *std.Build.Step.InstallArtifact {
//     const install = b.addInstallArtifact(artifact);
//     b.getInstallStep().dependOn(&install.step);
//     return install;
// }

fn addPosix(artifact: *std.build.LibExeObjStep, zig_posix: *std.build.LibExeObjStep) void {
    artifact.linkLibrary(zig_posix);
    artifact.addIncludePath("inc" ++ std.fs.path.sep_str ++ "posix");
}

fn addTest(
    comptime name: []const u8,
    b: *std.build.Builder,
    target: anytype,
    optimize: anytype,
    libc_only_std_static: *std.build.LibExeObjStep,
    zig_start: *std.build.LibExeObjStep,
) *std.build.LibExeObjStep {
    const exe = b.addExecutable(.{
        .name = name,
        .root_source_file = .{ .path = "test" ++ std.fs.path.sep_str ++ name ++ ".c" },
        .target = target,
        .optimize = optimize,
    });
    exe.addCSourceFiles(&.{"test" ++ std.fs.path.sep_str ++ "expect.c"}, &[_][]const u8{});
    exe.addIncludePath("inc" ++ std.fs.path.sep_str ++ "libc");
    exe.addIncludePath("inc" ++ std.fs.path.sep_str ++ "posix");
    exe.linkLibrary(libc_only_std_static);
    exe.linkLibrary(zig_start);
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
    optimize: anytype,
    libc_only_std_static: *std.build.LibExeObjStep,
    zig_start: *std.build.LibExeObjStep,
    libc_only_posix: *std.build.LibExeObjStep,
    install_step: *std.Build.Step,
) void {
    _ = install_step;

    const libc_test_repo = GitRepoStep.create(b, .{
        .url = "git://nsz.repo.hu:49100/repo/libc-test",
        .sha = "b7ec467969a53756258778fa7d9b045f912d1c93",
        .branch = null,
    });
    const libc_test_path = libc_test_repo.path;
    const libc_test_step = b.step("libc-test", "run tests from the libc-test project");

    // inttypes
    inline for (.{ "assert", "ctype", "errno", "main", "stdbool", "stddef", "string" }) |name| {
        const lib = b.addObject(.{
            .name = "libc-test-api-" ++ name,
            .root_source_file = .{ .path = b.pathJoin(&.{ libc_test_path, "src", "api", name ++ ".c" }) },
            .target = target,
            .optimize = optimize,
        });
        lib.addIncludePath("inc" ++ std.fs.path.sep_str ++ "libc");
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
            .root_source_file = .{ .path = b.pathJoin(&.{ libc_test_path, "src", "functional", name ++ ".c" }) },
            .target = target,
            .optimize = optimize,
        });
        exe.addCSourceFiles(common_src, &[_][]const u8{});
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
        libc_test_step.dependOn(&b.addRunArtifact(exe).step);
    }
}

fn addTinyRegexCTests(
    b: *std.build.Builder,
    target: anytype,
    optimize: anytype,
    libc_only_std_static: *std.build.LibExeObjStep,
    zig_start: *std.build.LibExeObjStep,
    zig_posix: *std.build.LibExeObjStep,
    install_step: *std.Build.Step,
) void {
    _ = install_step;
    const repo = GitRepoStep.create(b, .{
        .url = "https://github.com/marler8997/tiny-regex-c",
        .sha = "95ef2ad35d36783d789b0ade3178b30a942f085c",
        .branch = "nocompile",
    });

    const re_step = b.step("re-tests", "run the tiny-regex-c tests");
    inline for (&[_][]const u8{ "test1", "test3" }) |test_name| {
        const exe = b.addExecutable(.{
            .name = "re" ++ test_name,
            .root_source_file = null,
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

        exe.addCSourceFiles(files.toOwnedSlice() catch unreachable, &[_][]const u8{
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
        const run = b.addRunArtifact(exe);
        re_step.dependOn(&run.step);
    }
}

fn addLua(
    b: *std.build.Builder,
    target: anytype,
    optimize: anytype,
    libc_only_std_static: *std.build.LibExeObjStep,
    libc_only_posix: *std.build.LibExeObjStep,
    zig_start: *std.build.LibExeObjStep,
    install_step: *std.Build.Step,
) *std.build.LibExeObjStep {
    const lua_repo = GitRepoStep.create(b, .{
        .url = "https://github.com/lua/lua",
        .sha = "5d708c3f9cae12820e415d4f89c9eacbe2ab964b",
        .branch = "v5.4.4",
    });
    const lua_exe = b.addExecutable(.{
        .name = "lua",
        .target = target,
        .optimize = optimize,
    });
    lua_exe.step.dependOn(&lua_repo.step);
    const install = b.addInstallArtifact(lua_exe);
    install_step.dependOn(&install.step);

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

    lua_exe.addCSourceFiles(files.toOwnedSlice() catch unreachable, &[_][]const u8{
        "-nostdinc",
        "-nostdlib",
        "-std=c99",
    });

    lua_exe.addIncludePath("inc" ++ std.fs.path.sep_str ++ "libc");
    lua_exe.linkLibrary(libc_only_std_static);
    lua_exe.linkLibrary(libc_only_posix);
    lua_exe.linkLibrary(zig_start);
    // TODO: should libc_only_std_static and zig_start be able to add library dependencies?
    if (target.getOs().tag == .windows) {
        lua_exe.addIncludePath("inc/win32");
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
    b: *std.build.Builder,
    target: anytype,
    optimize: anytype,
    libc_only_std_static: *std.build.LibExeObjStep,
    zig_start: *std.build.LibExeObjStep,
    zig_posix: *std.build.LibExeObjStep,
    install_step: *std.Build.Step,
) *std.build.LibExeObjStep {
    const repo = GitRepoStep.create(b, .{
        //.url = "https://git.code.sf.net/p/cmph/git",
        .url = "https://github.com/bonitao/cmph",
        .sha = "abd5e1e17e4d51b3e24459ab9089dc0522846d0d",
        .branch = null,
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
    const install = b.addInstallArtifact(exe);
    exe.step.dependOn(&repo.step);
    exe.step.dependOn(&config_step.step);
    install_step.dependOn(&install.step);

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

    exe.addCSourceFiles(files.toOwnedSlice() catch unreachable, &[_][]const u8{
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
    step.dependOn(&install.step);

    return exe;
}

fn addYacc(
    b: *std.build.Builder,
    target: anytype,
    optimize: anytype,
    libc_only_std_static: *std.build.LibExeObjStep,
    zig_start: *std.build.LibExeObjStep,
    zig_posix: *std.build.LibExeObjStep,
    install_step: *std.Build.Step,
) *std.build.LibExeObjStep {
    const repo = GitRepoStep.create(b, .{
        .url = "https://github.com/ibara/yacc",
        .sha = "1a4138ce2385ec676c6d374245fda5a9cd2fbee2",
        .branch = null,
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
    const install = b.addInstallArtifact(exe);
    exe.step.dependOn(&repo.step);
    exe.step.dependOn(&config_step.step);
    exe.step.dependOn(&gen_progname_step.step);
    install_step.dependOn(&install.step);

    const repo_path = repo.getPath(&exe.step);
    var files = std.ArrayList([]const u8).init(b.allocator);
    const sources = [_][]const u8{
        "closure.c",  "error.c",  "lalr.c",    "lr0.c",      "main.c",     "mkpar.c",    "output.c", "reader.c",
        "skeleton.c", "symtab.c", "verbose.c", "warshall.c", "portable.c", "progname.c",
    };
    for (sources) |src| {
        files.append(b.pathJoin(&.{ repo_path, src })) catch unreachable;
    }

    exe.addCSourceFiles(files.toOwnedSlice() catch unreachable, &[_][]const u8{
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
    step.dependOn(&install.step);

    return exe;
}

fn addYabfc(
    b: *std.build.Builder,
    target: anytype,
    optimize: anytype,
    libc_only_std_static: *std.build.LibExeObjStep,
    zig_start: *std.build.LibExeObjStep,
    zig_posix: *std.build.LibExeObjStep,
    zig_gnu: *std.build.LibExeObjStep,
    install_step: *std.Build.Step,
) *std.build.LibExeObjStep {
    const repo = GitRepoStep.create(b, .{
        .url = "https://github.com/julianneswinoga/yabfc",
        .sha = "a789be25a0918d330b7a4de12db0d33e0785f244",
        .branch = null,
    });

    const exe = b.addExecutable(.{
        .name = "yabfc",
        .target = target,
        .optimize = optimize,
    });
    const install = b.addInstallArtifact(exe);
    exe.step.dependOn(&repo.step);
    install_step.dependOn(&install.step);

    const repo_path = repo.getPath(&exe.step);
    var files = std.ArrayList([]const u8).init(b.allocator);
    const sources = [_][]const u8{
        "assembly.c", "elfHelper.c", "helpers.c", "optimize.c", "yabfc.c",
    };
    for (sources) |src| {
        files.append(b.pathJoin(&.{ repo_path, src })) catch unreachable;
    }
    exe.addCSourceFiles(files.toOwnedSlice() catch unreachable, &[_][]const u8{
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

    const step = b.step("yabfc", "build/install the yabfc tool (Yet Another BrainFuck Compiler)");
    step.dependOn(&install.step);

    return exe;
}

fn addSecretGame(
    b: *std.build.Builder,
    target: anytype,
    optimize: anytype,
    libc_only_std_static: *std.build.LibExeObjStep,
    zig_start: *std.build.LibExeObjStep,
    zig_posix: *std.build.LibExeObjStep,
    zig_gnu: *std.build.LibExeObjStep,
    install_step: *std.Build.Step,
) *std.build.LibExeObjStep {
    const repo = GitRepoStep.create(b, .{
        .url = "https://github.com/ethinethin/Secret",
        .sha = "8ec8442f84f8bed2cb3985455e7af4d1ce605401",
        .branch = null,
    });

    const exe = b.addExecutable(.{
        .name = "secret",
        .target = target,
        .optimize = optimize,
    });
    const install = b.addInstallArtifact(exe);
    exe.step.dependOn(&repo.step);
    install_step.dependOn(&install.step);

    const repo_path = repo.getPath(&exe.step);
    var files = std.ArrayList([]const u8).init(b.allocator);
    const sources = [_][]const u8{
        "main.c", "inter.c", "input.c", "items.c", "rooms.c", "linenoise/linenoise.c",
    };
    for (sources) |src| {
        files.append(b.pathJoin(&.{ repo_path, src })) catch unreachable;
    }
    exe.addCSourceFiles(files.toOwnedSlice() catch unreachable, &[_][]const u8{
        "-std=c90",
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

    const step = b.step("secret", "build/install the secret game");
    step.dependOn(&install.step);

    return exe;
}
