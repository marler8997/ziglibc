const std = @import("std");
const GitRepoStep = @import("GitRepoStep.zig");

pub fn addGnuMake(
    b: *std.build.Builder,
    target: anytype,
    optimize: anytype,
    libc_only_std_static: *std.build.LibExeObjStep,
    zig_start: *std.build.LibExeObjStep,
    zig_posix: *std.build.LibExeObjStep,
) *std.build.LibExeObjStep {
    const repo = GitRepoStep.create(b, .{
        .url = "https://git.savannah.gnu.org/git/make.git",
        .sha = "ed493f6c9116cc217b99c2cfa6a95f15803235a2",
        .branch = "4.4",
    });

    const config_step = b.allocator.create(std.build.Step) catch unreachable;
    config_step.* = std.build.Step.init(.{
        .id = .custom,
        .name = "configure GNU Make",
        .owner = b,
    });
    // note: this MUST be the first dependency
    config_step.dependOn(&repo.step);

    const gen_config_h = b.addWriteFile(b.pathJoin(&.{ repo.path, "src", "config.h" }),
        \\/* Name of package */
        \\#define PACKAGE "GNUMake"
        \\/* Define to the address where bug reports for this package should be sent. */
        \\#define PACKAGE_BUGREPORT "dontsendmebugreports.com"
        \\/* Define to the full name of this package. */
        \\#define PACKAGE_NAME "GNUMake"
        \\/* Define to the full name and version of this package. */
        \\#define PACKAGE_STRING "GNUMake 4.4"
        \\/* Define to the one symbol short name of this package. */
        \\#define PACKAGE_TARNAME "gnumake"
        \\/* Define to the home page for this package. */
        \\#define PACKAGE_URL "https://www.gnu.org/software/make/"
        \\/* Define to the version of this package. */
        \\#define PACKAGE_VERSION "4.4"
        \\
        \\#define HAVE_STRING_H 1
        \\#define HAVE_STDLIB_H 1
        \\#define HAVE_INTTYPES_H 1
        \\#define HAVE_STDINT_H 1
        \\#define HAVE_SYS_TIME_H 1
        \\#define HAVE_DIRENT_H 1
        \\#define HAVE_FCNTL_H 1
        \\#define HAVE_ALLOCA_H 1
        \\#define HAVE_LOCALE_H 1
        \\#define HAVE_UNISTD_H 1
        \\#define HAVE_LIMITS_H 1
        \\#define HAVE_UMASK 1
        \\#define HAVE_MEMCPY 1
        \\#define HAVE_ATEXIT 1
        \\
        \\#define FILE_TIMESTAMP_HI_RES 0
        \\/* not sure what this is, but default.c seems to need it */
        \\#define SCCS_GET "get"
        \\
    );
    //\\#define __ptr_t char *
    //\\#define HAVE_GETOPT_H 1
    //\\#define HAVE_ALLOCA 1
    config_step.dependOn(&gen_config_h.step);
    // gcc -DHAVE_CONFIG_H   -Isrc -I./src -Ilib -I./lib -DLIBDIR=\"/usr/local/lib\" -DLOCALEDIR=\"/usr/local/share/locale\"   -DMAKE_MAINTAINER_MODE   -C -Wall -Wextra -Werror -Wwrite-strings -Wshadow -Wdeclaration-after-statement -Wbad-function-cast -Wformat-security -Wtype-limits -Wunused-but-set-parameter -Wlogical-op -Wpointer-arith -Wignored-qualifiers -Wformat-signedness -Wduplicated-cond -g -O2 -MT src/hash.o -MD -MP -MF $depbase.Tpo -c -o src/hash.o src/hash.c &&\

    // home/marler8997/zig/0.11.0-dev.12+ebf9ffd34/files/zig build-exe -cflags -std=c11 -- /home/marler8997/git/ziglibc/dep/make.git/src/ar.c /home/marler8997/git/ziglibc/dep/make.git/src/arscan.c /home/marler8997/git/ziglibc/dep/make.git/src/commands.c /home/marler8997/git/ziglibc/dep/make.git/src/default.c /home/marler8997/git/ziglibc/dep/make.git/src/dir.c /home/marler8997/git/ziglibc/dep/make.git/src/expand.c /home/marler8997/git/ziglibc/dep/make.git/src/file.c /home/marler8997/git/ziglibc/dep/make.git/src/function.c /home/marler8997/git/ziglibc/dep/make.git/src/getopt.c /home/marler8997/git/ziglibc/dep/make.git/src/getopt1.c /home/marler8997/git/ziglibc/dep/make.git/src/guile.c /home/marler8997/git/ziglibc/dep/make.git/src/hash.c /home/marler8997/git/ziglibc/dep/make.git/src/implicit.c /home/marler8997/git/ziglibc/dep/make.git/src/job.c /home/marler8997/git/ziglibc/dep/make.git/src/load.c /home/marler8997/git/ziglibc/dep/make.git/src/loadapi.c /home/marler8997/git/ziglibc/dep/make.git/src/main.c /home/marler8997/git/ziglibc/dep/make.git/src/misc.c /home/marler8997/git/ziglibc/dep/make.git/src/output.c /home/marler8997/git/ziglibc/dep/make.git/src/read.c /home/marler8997/git/ziglibc/dep/make.git/src/remake.c /home/marler8997/git/ziglibc/dep/make.git/src/rule.c /home/marler8997/git/ziglibc/dep/make.git/src/shuffle.c /home/marler8997/git/ziglibc/dep/make.git/src/signame.c /home/marler8997/git/ziglibc/dep/make.git/src/strcache.c /home/marler8997/git/ziglibc/dep/make.git/src/variable.c /home/marler8997/git/ziglibc/dep/make.git/src/version.c /home/marler8997/git/ziglibc/dep/make.git/src/vpath.c /home/marler8997/git/ziglibc/dep/make.git/src/posixos.c /home/marler8997/git/ziglibc/dep/make.git/src/remote-stub.c /home/marler8997/git/ziglibc/zig-cache/o/b2ab2b27dd98ed5352486d2081cf35bf/libc-only-std.a /home/marler8997/git/ziglibc/zig-cache/o/4d76e73699236d8f95a7f75ae51db269/libc-only-posix.a /home/marler8997/git/ziglibc/zig-cache/o/f647e7cbfedb41adc3d86981e126be58/libstart.a --verbose-cc --cache-dir /home/marler8997/git/ziglibc/zig-cache --global-cache-dir /home/marler8997/.cache/zig --name make -I /home/marler8997/git/ziglibc/inc/libc -I /home/marler8997/git/ziglibc/inc/posix -I /home/marler8997/git/ziglibc/inc/gnu --enable-cache

    const exe = b.addExecutable(.{
        .name = "make",
        .target = target,
        .optimize = optimize,
    });
    const install = b.addInstallArtifact(exe);
    exe.step.dependOn(&repo.step);
    exe.step.dependOn(config_step);
    const repo_path = repo.getPath(&exe.step);
    var files = std.ArrayList([]const u8).init(b.allocator);
    for (src_filenames) |src| {
        files.append(b.pathJoin(&.{ repo_path, "src", src })) catch unreachable;
    }

    exe.addIncludePath(b.pathJoin(&.{ repo_path, "src" }));
    exe.addCSourceFiles(files.toOwnedSlice() catch unreachable, &[_][]const u8{
        "-std=c99",
        "-DHAVE_CONFIG_H",
        "-Wall",
        "-Wextra",
        "-Werror",
        "-Wwrite-strings",
        "-Wshadow",
        "-Wdeclaration-after-statement",
        "-Wbad-function-cast",
        "-Wformat-security",
        "-Wtype-limits",
        "-Wunused-but-set-parameter",
        "-Wpointer-arith",
        "-Wignored-qualifiers",
        // ignore unused parameter errors because the ATTRIBUTE define isn't working in makeint.h
        "-Wno-unused-parameter",
        "-Wno-dangling-else",
        //"-Wlogical-op", "-Wformat-signedness", "-Wduplicated-cond",
    });

    exe.addIncludePath("inc/libc");
    exe.addIncludePath("inc/posix");
    exe.addIncludePath("inc/gnu");
    exe.addIncludePath("inc/alloca");
    exe.linkLibrary(libc_only_std_static);
    exe.linkLibrary(zig_start);
    exe.linkLibrary(zig_posix);
    // TODO: should libc_only_std_static and zig_start be able to add library dependencies?
    if (target.getOs().tag == .windows) {
        exe.linkSystemLibrary("ntdll");
        exe.linkSystemLibrary("kernel32");
    }

    const step = b.step("make", "build GNU make");
    step.dependOn(&install.step);

    return exe;
}

const src_filenames = &[_][]const u8{
    "ar.c",
    "arscan.c",
    "commands.c",
    "default.c",
    "dir.c",
    "expand.c",
    "file.c",
    "function.c",
    "getopt.c",
    "getopt1.c",
    "guile.c",
    "hash.c",
    "implicit.c",
    "job.c",
    "load.c",
    "loadapi.c",
    "main.c",
    "misc.c",
    "output.c",
    "read.c",
    "remake.c",
    "rule.c",
    "shuffle.c",
    "signame.c",
    "strcache.c",
    "variable.c",
    "version.c",
    "vpath.c",
    "posixos.c",
    "remote-stub.c",
};
