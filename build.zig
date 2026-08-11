const std = @import("std");

pub fn build(b: *std.Build) void {
    const targets = b.standardTargetOptions(.{});
    const optmize = b.standardOptimizeOption(.{});

    const lib_mod = b.addModule("benzene", .{
        .optimize = optmize,
        .target = targets,
        .root_source_file = b.path("src/benz.zig"),
    });

    const lib = b.addLibrary(.{
        .name = "benzene",
        .root_module = lib_mod,
    });

    lib_mod.addAssemblyFile(b.path("src/switch_context_linux_x86_64.S"));
    b.installArtifact(lib);

    const exe_mod = b.createModule(.{
        .target = targets,
        .optimize = optmize,
        .root_source_file = b.path("src/main.zig"),
    });

    exe_mod.linkLibrary(lib);
    exe_mod.addImport("benzene", lib.root_module);

    const exe = b.addExecutable(.{
        .name = "benzc",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "run the benzenze compiler");
    const run_exe = b.addRunArtifact(exe);
    run_step.dependOn(&run_exe.step);
    run_step.dependOn(b.getInstallStep());
    run_exe.addPassthruArgs();

    const lib_test = b.addTest(.{
        .name = "lib-test",
        .root_module = lib.root_module,
    });

    const test_step = b.step("test", "run unit test");
    const run_test = b.addRunArtifact(lib_test);
    test_step.dependOn(&run_test.step);
    test_step.dependOn(b.getInstallStep());
}
