const Lexer = @import("lexer.zig");
const Token = @import("token.zig");
const std = @import("std");
const query = @import("ast/query.zig");
const expression = @import("ast/expression.zig");
const Expression = expression.Expression;

const Self = @This();

allocator: std.mem.Allocator,
lexer: Lexer,
current_token: Token,
peek_token: Token,

pub fn init(allocator: std.mem.Allocator, lexer: Lexer) !Self {
    var parser = Self{
        .allocator = allocator,
        .lexer = lexer,
        .current_token = undefined,
        .peek_token = undefined,
    };

    try parser.next_token();
    try parser.next_token();

    return parser;
}

pub fn parse(self: *Self) !std.ArrayList(query.Statement) {
    var list = std.ArrayList(query.Statement).init(self.allocator);
    while (self.current_token.token != .eof) {
        const statement = self.parse_statement() catch |err| {
            std.debug.print("failed to parse statement\n", .{});
            std.debug.print("[error: line: {} col: {}]: {}\n", .{ self.current_token.end_pos.line, self.current_token.end_pos.column, err });
            try self.next_token();
            continue;
        };
        list.append(statement) catch {
            std.debug.print("failed to append statement to list\n", .{});
        };

        try self.next_token();
    }
    return list;
}

const ParserError = error{ InvalidToken, NotImplemented, OutOfMemory };

fn peek_precedence(self: *Self) u8 {
    return switch (self.peek_token.token) {
        .plus => 1,
        else => 0,
    };
}

fn next_token(self: *Self) !void {
    self.current_token = self.peek_token;
    self.peek_token = try self.lexer.next_token();
}

fn peek_token_is(self: *Self, expected: Token.TokenKind) bool {
    return @as(Token.TokenKind, self.peek_token.token) == expected;
}

fn current_token_is(self: *Self, expected: Token.TokenKind) bool {
    return @as(Token.TokenKind, self.current_token.token) == expected;
}

fn expect_peek(self: *Self, expected: Token.TokenKind) !bool {
    if (self.peek_token_is(expected)) {
        try self.next_token();
        return true;
    } else {
        return false;
    }
}

fn expect_peek_many(self: *Self, expected: []const Token.TokenKind) !bool {
    for (expected) |expected_token| {
        if (self.peek_token_is(expected_token)) {
            try self.next_token();
            return true;
        }
    }
    return false;
}

fn parse_statement(self: *Self) ParserError!query.Statement {
    std.debug.print("parsing statement\n", .{});
    // std.debug.print("current token: {s}\n", .{self.current_token.token.toString()});
    return switch (self.current_token.token) {
        // .with => blk: {
        //     const select_statement = try self.parse_cte();
        //     break :blk ast.Statement{ .select = select_statement };
        // },
        .select => blk: {
            const select = try self.parse_select();
            break :blk query.Statement{ .select = select };
        },
        else => ParserError.NotImplemented,
    };
}

// fn parse_cte(self: *Self) ParserError!query.CTE {
//     var statement = query.SelectStatement{ .common_table_expression = null, .body = undefined };
//     std.debug.print("parsing select\n", .{});
//     if (self.current_token_is(.with)) {
//         std.debug.print("parsing cte\n", .{});
//     }
//
//     if (!self.peek_token_is(.select)) {
//         return ParserError.InvalidToken;
//     }
//
//     std.debug.print("parsing select body\n", .{});
//     statement.body = try self.parse_select_body();
//
//     return statement;
// }

fn parse_select(self: *Self) ParserError!query.Select {
    std.debug.print("parsing select body\n", .{});
    var body = query.Select{
        .select_items = undefined,
        .table = undefined,
        .where = undefined,
    };

    // parse the columns
    if (!try self.expect_peek_many(&[_]Token.TokenKind{ .identifier, .string_literal })) {
        return ParserError.InvalidToken;
    }
    body.select_items = std.ArrayList(*Expression).init(self.allocator);
    const column = try self.parse_expression(1);
    try body.select_items.append(column);

    if (!try self.expect_peek(.from)) {
        return ParserError.InvalidToken;
    }
    try self.next_token();
    const table = try self.parse_expression(1);
    body.table = table;

    return body;
}

fn parse_expression(self: *Self, precedence: u8) ParserError!*Expression {
    // check if the current token is an identifier
    // or if it is a prefix operator
    var left_expression = try self.parse_prefix_expression();

    while (precedence < self.peek_precedence()) {
        // move to the next token
        try self.next_token();

        left_expression = try self.parse_infix_expression(left_expression);
    }

    return left_expression;
}

fn parse_prefix_expression(self: *Self) ParserError!*Expression {
    const expr = try self.allocator.create(Expression);
    errdefer self.allocator.destroy(expr);

    return switch (self.current_token.token) {
        .identifier, .number, .local_variable, .string_literal, .quoted_identifier => expr: {
            if (self.current_token.token == .identifier) {
                expr.* = Expression{ .identifier = self.current_token.token.identifier };
                break :expr expr;
            } else if (self.current_token.token == .number) {
                expr.* = Expression{ .number_literal = self.current_token.token.number };
                break :expr expr;
            } else if (self.current_token.token == .local_variable) {
                expr.* = Expression{ .local_variable_identifier = self.current_token.token.local_variable };
                break :expr expr;
            } else if (self.current_token.token == .string_literal) {
                expr.* = Expression{ .string_literal = self.current_token.token.string_literal };
                break :expr expr;
            } else if (self.current_token.token == .quoted_identifier) {
                expr.* = Expression{ .quote_identifier = self.current_token.token.quoted_identifier };
                break :expr expr;
            }

            return ParserError.InvalidToken;
        },
        else => ParserError.InvalidToken,
    };
}

fn parse_infix_expression(self: *Self, left: *Expression) ParserError!*Expression {
    _ = left;
    const expr = try self.allocator.create(Expression);
    errdefer self.allocator.destroy(expr);

    return switch (self.current_token.token) {
        // .plus, .minus => expr: {
        //     const operator = self.current_token;
        //     // const precedence = self.current_precedence();
        //     const precedence = 0;
        //     self.next_token();
        //
        //     // parse the expression to the right of the operator
        //     const right = try self.parse_expression(precedence);
        //
        //     var binary_expr = query.Expression{ .binary = .{ .left = self.allocator.create(query.Expression) catch return ParserError.OutOfMemory, .operator = operator, .right = self.allocator.create(query.Expression) catch return ParserError.OutOfMemory } };
        //     binary_expr.binary.left.* = left;
        //     binary_expr.binary.right.* = right;
        //
        //     break :expr binary_expr;
        // },
        else => ParserError.InvalidToken,
    };
}

test "parse select statement" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const hello_column = try allocator.create(Expression);
    errdefer allocator.destroy(hello_column);
    hello_column.* = Expression{ .identifier = try allocator.dupe(u8, "hello") };
    var select_items = std.ArrayList(*Expression).init(allocator);
    try select_items.append(hello_column);

    const table = try allocator.create(Expression);
    errdefer allocator.destroy(table);
    table.* = Expression{ .identifier = try allocator.dupe(u8, "testtable") };
    var statements = std.ArrayList(query.Statement).init(allocator);
    try statements.append(
        query.Statement{
            .select = .{ .select_items = select_items, .table = table, .where = null },
        },
    );
    const input = "select hello from testtable";

    const lexer = Lexer.new(allocator, input);
    var parser = try Self.init(allocator, lexer);
    const parsed_sql = try parser.parse();
    try std.testing.expectEqualDeep(statements, parsed_sql);
}
