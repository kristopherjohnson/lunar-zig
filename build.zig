const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "lunar",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (@hasField(std.Build, "args")) {
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }
    }

    const run_step = b.step("run", "Run the lunar lander game");
    run_step.dependOn(&run_cmd.step);

    // Unit tests
    const exe_unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Integration test suite (good, perfect, failure, success)
    const test_cases = [_]struct { name: []const u8, input: []const u8, expected: []const u8 }{
        .{
            .name = "good",
            .input = "test/good_input.txt",
            .expected = @embedFile("test/good_output_expected.txt"),
        },
        .{
            .name = "perfect",
            .input = "test/perfect_input.txt",
            .expected = @embedFile("test/perfect_output_expected.txt"),
        },
        .{
            .name = "failure",
            .input = "test/failure_input.txt",
            .expected = @embedFile("test/failure_output_expected.txt"),
        },
        .{
            .name = "success",
            .input = "test/success_input.txt",
            .expected = @embedFile("test/success_output_expected.txt"),
        },
    };

    const test_step = b.step("test", "Run unit and integration tests");
    test_step.dependOn(&run_exe_unit_tests.step);

    inline for (test_cases) |tc| {
        const run_tc = b.addRunArtifact(exe);
        run_tc.addArg("--echo");
        run_tc.setStdIn(.{ .lazy_path = b.path(tc.input) });
        run_tc.expectStdOutEqual(tc.expected);
        test_step.dependOn(&run_tc.step);
    }
}
