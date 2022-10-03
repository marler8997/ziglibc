const std = @import("std");
const GitRepoStep = @import("../GitRepoStep.zig");

const BusyboxPrepStep = struct {
    step: std.build.Step,
    builder: *std.build.Builder,
    repo_path: []const u8,
    pub fn create(b: *std.build.Builder, repo: *GitRepoStep) *BusyboxPrepStep {
        var result = b.allocator.create(BusyboxPrepStep) catch unreachable;
        result.* = BusyboxPrepStep{
            .step = std.build.Step.init(.custom, "busybox prep", b.allocator, make),
            .builder = b,
            .repo_path = repo.path,
        };
        result.*.step.dependOn(&repo.step);
        return result;
    }
    fn make(step: *std.build.Step) !void {
        const self = @fieldParentPtr(BusyboxPrepStep, "step", step);
        const b = self.builder;

        std.log.warn("TODO: check config file timestamp to prevent unnecessary copy", .{});
        var src_dir = try std.fs.cwd().openDir(b.pathJoin(&.{ b.build_root, "busybox"}), .{});
        defer src_dir.close();
        var dst_dir = try std.fs.cwd().openDir(self.repo_path, .{});
        defer dst_dir.close();
        try src_dir.copyFile("busybox_1_35_0.config", dst_dir, ".config", .{});
    }
};

pub fn add(
    b: *std.build.Builder,
    target: anytype,
    mode: anytype,
    libc_only_std_static: *std.build.LibExeObjStep,
    zig_posix: *std.build.LibExeObjStep,
) *std.build.LibExeObjStep {
    const repo = GitRepoStep.create(b, .{
        .url = "https://git.busybox.net/busybox",
        .sha = "e512aeb0fb3c585948ae6517cfdf4a53cf99774d",
        .branch = null,
    });

    const prep = BusyboxPrepStep.create(b, repo);
    
    const exe = b.addExecutable("busybox", null);
    exe.setTarget(target);
    exe.setBuildMode(mode);
    //exe.install();
    _ = b.addInstallArtifact(exe);
    exe.step.dependOn(&prep.step);
    const repo_path = repo.getPath(&exe.step);
    var files = std.ArrayList([]const u8).init(b.allocator);
    const sources = [_][]const u8 {
        "editors/sed.c",
    };
    for (sources) |src| {
        files.append(b.pathJoin(&.{repo_path, src})) catch unreachable;
    }
    exe.addCSourceFiles(files.toOwnedSlice(), &[_][]const u8 {
        "-std=c99",
    });
    exe.addIncludePath(b.pathJoin(&.{repo_path, "include"}));

    exe.addIncludePath("inc/libc");
    exe.addIncludePath("inc/posix");
    exe.addIncludePath("inc/linux");
    exe.linkLibrary(libc_only_std_static);
    //exe.linkLibrary(zig_start);
    exe.linkLibrary(zig_posix);
    // TODO: should libc_only_std_static and zig_start be able to add library dependencies?
    if (target.getOs().tag == .windows) {
        exe.linkSystemLibrary("ntdll");
        exe.linkSystemLibrary("kernel32");
    }

    const step = b.step("busybox", "build busybox and it's applets");
    step.dependOn(&exe.install_step.?.step);

    return exe;
}
