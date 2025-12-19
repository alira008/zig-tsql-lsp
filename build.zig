const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lexer = b.addModule(
        "lexer",
        .{
            .root_source_file = b.path("src/lexer/lexer.zig"),
            .target = target,
            .optimize = optimize,
        },
    );
    const ast = b.addModule(
        "ast",
        .{
            .root_source_file = b.path("src/ast/ast.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "lexer", .module = lexer },
            },
        },
    );
    const parser = b.addModule(
        "parser",
        .{
            .root_source_file = b.path("src/parser/parser.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "lexer", .module = lexer },
                .{ .name = "ast", .module = ast },
            },
        },
    );
    // const frontend = b.addModule(
    //     "frontend",
    //     .{
    //         .root_source_file = b.path("src/frontend/root.zig"),
    //         .target = target,
    //         .optimize = optimize,
    //     },
    // );

    const exe = b.addExecutable(.{
        .name = "sql-lsp",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "lexer", .module = lexer },
                .{ .name = "parser", .module = parser },
            },
        }),
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "lexer", .module = lexer },
                .{ .name = "parser", .module = parser },
                .{ .name = "ast", .module = ast },
            },
        }),
    });
    const run_unit_tests = b.addRunArtifact(unit_tests);
    _ = run_unit_tests;

    const parser_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/parser/parser.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "lexer", .module = lexer },
                .{ .name = "ast", .module = ast },
            },
        }),
    });
    const run_parser_tests = b.addRunArtifact(parser_tests);
    _ = run_parser_tests;

    const lexer_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/lexer/lexer.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "ast", .module = ast },
            },
        }),
    });
    const run_lexer_tests = b.addRunArtifact(lexer_tests);
    _ = run_lexer_tests;

    const frontend_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/frontend/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_frontend_tests = b.addRunArtifact(frontend_tests);

    const test_step = b.step("test", "Run unit tests");
    // test_step.dependOn(&run_unit_tests.step);
    // test_step.dependOn(&run_lexer_tests.step);
    // test_step.dependOn(&run_parser_tests.step);
    test_step.dependOn(&run_frontend_tests.step);
}
