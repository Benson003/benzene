const std = @import("std");

pub fn build(b: *std.Build) void {
    const targets = b.standardTargetOptions(.{});
    const optmize = b.standardOptimizeOption(.{});

    const benz_mod = b.addModule("benz", .{
        .optimize = optmize,
        .target = targets,
        .root_source_file = b.path("src/main.zig"),
    });

    benz_mod.addAssemblyFile(b.path("src/switch_context_linux_x86_64.S"));

    const benzc_exe = b.addExecutable(.{
        .name = "benzc",
        .root_module = benz_mod,
    });

    const run = b.addRunArtifact(benzc_exe);
    const run_step = b.step("run", "run the excutable");

    run_step.dependOn(&run.step);
}
