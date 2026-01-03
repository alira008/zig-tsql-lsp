const lex = @import("lexer.zig");
const tok = @import("token.zig");
const ast = @import("ast.zig");
const std = @import("std");
const dial = @import("dialect.zig");

pub const Error = error{
    UnexpectedToken,
    ExpectedKeyword,
} || std.mem.Allocator.Error || lex.Error;

pub const Parser = struct {
    arena: std.heap.ArenaAllocator,
    allocator: std.mem.Allocator,
    lexer: lex.Lexer,
    dialect: dial.Dialect,
    errors: std.ArrayList(Error) = undefined,
    current_token: tok.Token = undefined,

    pub fn init(allocator: std.mem.Allocator, lexer: lex.Lexer, dialect: dial.Dialect) Error!Parser {
        var parser = Parser{
            .arena = std.heap.ArenaAllocator.init(allocator),
            .allocator = allocator,
            .lexer = lexer,
            .dialect = dialect,
        };
        parser.errors = try std.ArrayList(Error).initCapacity(parser.arena.allocator(), 10);
        try parser.nextToken();
        return parser;
    }

    pub fn deinit(parser: *Parser) void {
        parser.arena.deinit();
    }

    fn alloc(parser: *Parser, comptime T: type) !*T {
        return try parser.arena.allocator().create(T);
    }

    fn allocSlice(parser: *Parser, comptime T: type, n: usize) ![]T {
        return try parser.arena.allocator().alloc(T, n);
    }

    pub fn parse(parser: *Parser) Error!ast.Query {
        const arena_allocator = parser.arena.allocator();
        var statements = try std.ArrayList(*ast.Statement).initCapacity(arena_allocator, 10);
        const start_span = parser.current_token.span;
        while (!parser.tokenIs(.eof)) {
            const stmt = parser.parseStatement() catch |err| {
                try parser.appendError(err);
                try parser.nextToken();
                continue;
            };
            statements.append(arena_allocator, stmt) catch |err| {
                try parser.appendError(err);
            };
            try parser.nextToken();
        }
        const end_span = switch (statements.items.len > 0) {
            true => statements.items[statements.items.len - 1].span(),
            false => parser.current_token.span,
        };
        return ast.Query{
            .statements = statements.items,
            .span = ast.Span.merge(start_span, end_span),
        };
    }

    fn appendError(parser: *Parser, err: Error) !void {
        try parser.errors.append(parser.arena.allocator(), err);
    }

    fn nextToken(parser: *Parser) !void {
        parser.current_token = try parser.lexer.next_token();
    }

    fn tokenIs(parser: *Parser, tag: tok.Tag) bool {
        return parser.current_token.tag == tag;
    }

    fn tokenIsAny(parser: *Parser, tags: []tok.Tag) bool {
        for (tags) |tag| {
            if (parser.tokenIs(tag)) {
                return true;
            }
        }

        return false;
    }

    fn consumeKeyword(parser: *Parser, tag: tok.Tag) !ast.Keyword {
        const span = parser.current_token.span;
        if (dial.Keyword.fromTokenTagKeyword(tag)) |keyword| {
            try parser.nextToken();

            return ast.Keyword{
                .tag = keyword,
                .span = span,
            };
        }
        return Error.ExpectedKeyword;
    }

    fn consumeToken(parser: *Parser, tag: tok.Tag) !tok.Token {
        const current_token = parser.current_token;
        if (current_token.tag != tag) {
            return Error.UnexpectedToken;
        }
        try parser.nextToken();

        return current_token;
    }

    fn consumeTokenAny(parser: *Parser, tags: []tok.Tag) !tok.Token {
        const current_token = parser.current_token;
        for (tags) |tag| {
            if (parser.tokenIs(tag)) {
                try parser.nextToken();
                return current_token;
            }
        }

        return Error.UnexpectedToken;
    }

    fn maybeKeyword(parser: *Parser, tag: dial.Keyword) ?ast.Keyword {
        const span = parser.current_token.span;
        if (dial.Keyword.fromTokenTagKeyword(tag)) |keyword| {
            try parser.nextToken();

            return ast.Keyword{
                .tag = keyword,
                .span = span,
            };
        }
        return null;
    }

    fn parseStatement(parser: *Parser) !*ast.Statement {
        const maybeKw = dial.lookupKeyword(parser.current_token.lexeme, parser.dialect);
        if (maybeKw) |kw| {
            return switch (kw) {
                .select => {
                    const selectStatement = try parser.parseSelectStatement();
                    const stmt = try parser.alloc(ast.Statement);
                    stmt.* = .{ .select = selectStatement };
                    return stmt;
                },
                else => Error.UnexpectedToken,
            };
        } else {
            return Error.UnexpectedToken;
        }
    }

    fn parseSelectStatement(parser: *Parser) !*ast.SelectStatement {
        _ = try parser.consumeKeyword(.kw_select);
        const selectStatementSelect = try parser.alloc(ast.SelectStatement);
        selectStatementSelect.* = .{
            .select_kw = .{
                .tag = .select,
                .span = .{ .start = 0, .end = 5 },
            },
            .select_list = .{ .items = try parser.allocSlice(*ast.Expression, 0), .span = .global },
            .span = .{ .start = 0, .end = 5 },
        };

        return selectStatementSelect;
    }

    fn currentSpan(parser: *Parser) ast.Span {
        return parser.current_token.span;
    }

    fn currentPrecedence(parser: *Parser) tok.Precedence {
        return switch (parser.current_token.tag) {
            .identifier => |ident| blk: {
                const maybeKw = dial.lookupKeyword(ident, parser.dialect);
                if (maybeKw) |kw| {
                    break :blk dial.precedenceOf(kw);
                } else {
                    break :blk .lowest;
                }
            },
            else => |tag| tok.precedenceOf(tag),
        };
    }

    fn parseExpression(parser: *Parser, precedence: tok.Precedence) !*ast.Expression {
        var left_expr = try parser.parsePrefixExpression();
        while (precedence < parser.currentPrecedence()) {
            left_expr = try parser.parseInfixExpression(left_expr);
        }

        return left_expr;
    }

    fn parsePrefixExpression(parser: *Parser) !*ast.Expression {
        const start_span = parser.currentSpan();
        const expr = try parser.alloc(ast.Expression);
        expr.* = switch (parser.current_token.tag) {
            .identifier,
            .quoted_identifier,
            .local_variable,
            .string_literal,
            .number_literal,
            .asterisk,
            => blk: {
                const newExpr = switch (parser.current_token.tag) {
                    .identifier => ast.Expression{
                        .identifier = .{
                            .normal = .{ .value = parser.current_token.lexeme, .span = ast.Span.merge(start_span, parser.currentSpan()) },
                        },
                    },
                    .quoted_identifier => ast.Expression{
                        .identifier = .{
                            .quoted = .{ .value = parser.current_token.lexeme, .span = ast.Span.merge(start_span, parser.currentSpan()) },
                        },
                    },
                    .local_variable => ast.Expression{
                        .identifier = .{
                            .local_variable = .{ .value = parser.current_token.lexeme, .span = ast.Span.merge(start_span, parser.currentSpan()) },
                        },
                    },
                    .string_literal => ast.Expression{
                        .literal = .{
                            .string = .{ .value = parser.current_token.lexeme, .span = ast.Span.merge(start_span, parser.currentSpan()) },
                        },
                    },
                    .number_literal => ast.Expression{
                        .literal = .{
                            .number = .{ .value = parser.current_token.lexeme, .span = ast.Span.merge(start_span, parser.currentSpan()) },
                        },
                    },
                    .bool_literal => ast.Expression{
                        .literal = .{
                            .number = .{ .value = parser.current_token.lexeme, .span = ast.Span.merge(start_span, parser.currentSpan()) },
                        },
                    },
                    // .asterisk,

                };
                _ = newExpr;
                break :blk;
            },
        };
        return expr;
    }

    fn parseInfixExpression(parser: *Parser, expr: *ast.Expression) !*ast.Expression {
        _ = parser;
        _ = expr;
    }
};

test "basic select test" {
    const dialect = dial.Dialect.sqlserver;
    const input = "seLECt *, potato from table;";
    const expectEqualDeep = std.testing.expectEqualDeep;
    var testArena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer testArena.deinit();
    const a = testArena.allocator();

    var statements = try a.alloc(*ast.Statement, 1);
    const selectStatement = try a.create(ast.Statement);
    const selectStatementSelect = try a.create(ast.SelectStatement);
    selectStatementSelect.* = .{
        .select_kw = .{
            .tag = .select,
            .span = .{ .start = 0, .end = 5 },
        },
        .select_list = .{ .items = try a.alloc(*ast.Expression, 0), .span = .global },
        .span = .{ .start = 0, .end = 5 },
    };
    selectStatement.* = .{ .select = selectStatementSelect };
    statements[0] = selectStatement;
    const expected = ast.Query{
        .statements = statements,
        .span = .{ .start = 0, .end = 5 },
    };

    var parser = try Parser.init(std.testing.allocator, lex.Lexer.init(input, dialect), dialect);
    defer parser.deinit();
    const actual = try parser.parse();

    try expectEqualDeep(expected, actual);
}
