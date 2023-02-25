const std = @import("std");
const GitRepoStep = @import("GitRepoStep.zig");

pub fn addAwk(
    b: *std.build.Builder,
    target: anytype,
    mode: anytype,
    libc_only_std_static: *std.build.LibExeObjStep,
    zig_start: *std.build.LibExeObjStep,
    zig_posix: *std.build.LibExeObjStep,
) *std.build.LibExeObjStep {
    const repo = GitRepoStep.create(b, .{
        .url = "https://github.com/onetrueawk/awk",
        .sha = "9e248c317b88470fc86aa7c988919dc49452c88c",
        .branch = null,
    });

    //    const config_step = b.addWriteFile(
    //        b.pathJoin(&.{repo.path, "src", "config.h"}),
    //        "#define VERSION \"1.0\"",
    //    );
    //    config_step.step.dependOn(&repo.step);

    const exe = b.addExecutable(.{ .name = "awk", .target = target, .optimize = mode });
    _ = b.addInstallArtifact(exe);
    //exe.install();
    exe.step.dependOn(&repo.step);
    //    exe.step.dependOn(&config_step.step);
    const repo_path = repo.getPath(&exe.step);
    var files = std.ArrayList([]const u8).init(b.allocator);
    const sources = [_][]const u8{
        //        "main.c", "cmph.c", "hash.c", "chm.c", "bmz.c", "bmz8.c", "brz.c", "fch.c",
        //        "bdz.c", "bdz_ph.c", "chd_ph.c", "chd.c", "jenkins_hash.c", "graph.c", "vqueue.c",
        //        "buffer_manager.c", "fch_buckets.c", "miller_rabin.c", "compressed_seq.c",
        //        "compressed_rank.c", "buffer_entry.c", "select.c", "cmph_structs.c",
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

    const step = b.step("awk", "build awk");
    step.dependOn(&exe.install_step.?.step);

    return exe;
}
