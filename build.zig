const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const lexer = b.addModule("lexer", .{ .root_source_file = b.path("src/lexer/lexer.zig") });
    const ast = b.addModule("ast", .{ .root_source_file = b.path("src/ast/ast.zig") });
    const parser = b.addModule("parser", .{ .root_source_file = b.path("src/parser/parser.zig") });
    parser.addImport("lexer", lexer);
    parser.addImport("ast", ast);
    lexer.addImport("ast", ast);

    const exe = b.addExecutable(.{
        .name = "sql-lsp",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("ast", ast);
    exe.root_module.addImport("lexer", lexer);
    exe.root_module.addImport("parser", parser);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    unit_tests.root_module.addImport("ast", ast);
    unit_tests.root_module.addImport("lexer", lexer);
    unit_tests.root_module.addImport("parser", parser);
    const run_unit_tests = b.addRunArtifact(unit_tests);

    const parser_tests = b.addTest(.{
        .root_source_file = b.path("src/parser/parser.zig"),
        .target = target,
        .optimize = optimize,
    });
    parser_tests.root_module.addImport("ast", ast);
    parser_tests.root_module.addImport("lexer", lexer);
    const run_parser_tests = b.addRunArtifact(parser_tests);

    const lexer_tests = b.addTest(.{
        .root_source_file = b.path("src/lexer/lexer.zig"),
        .target = target,
        .optimize = optimize,
    });
    lexer_tests.root_module.addImport("ast", ast);
    const run_lexer_tests = b.addRunArtifact(lexer_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
    test_step.dependOn(&run_lexer_tests.step);
    test_step.dependOn(&run_parser_tests.step);
}
