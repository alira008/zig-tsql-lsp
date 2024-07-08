const std = @import("std");
const query = @import("ast/query.zig");
const expression = @import("ast/expression.zig");
const Lexer = @import("lexer.zig");
const LexerError = @import("lexer.zig").LexerError;
const Token = @import("token.zig");
const ErrorContext = @import("errors.zig").ErrorContext;
const ParserError = @import("errors.zig").ParserError;
const Expression = expression.Expression;

const Self = @This();

allocator: std.mem.Allocator,
lexer: Lexer,
current_token: Token,
peek_token: Token,
error_context: ErrorContext,

pub fn init(allocator: std.mem.Allocator, lexer: Lexer) Self {
    var parser = Self{
        .allocator = allocator,
        .lexer = lexer,
        .current_token = undefined,
        .peek_token = undefined,
        .error_context = ErrorContext.init(allocator),
    };

    parser.next_token();
    parser.next_token();

    return parser;
}

pub fn parse(self: *Self) std.ArrayList(query.Statement) {
    var list = std.ArrayList(query.Statement).init(self.allocator);
    while (self.current_token.token != .eof) {
        const statement = self.parse_statement() catch |err| {
            std.debug.print("failed to parse statement\n", .{});
            std.debug.print("[error: line: {} col: {}]: {}\n", .{ self.current_token.end_pos.line, self.current_token.end_pos.column, err });
            self.error_context.handleError(err);
            self.next_token();
            continue;
        };
        list.append(statement) catch {
            std.debug.print("failed to append statement to list\n", .{});
        };
        self.next_token();
    }
    return list;
}

pub fn errors(self: Self) [][]u8 {
    return self.error_context.errors.items;
}

fn peek_precedence(self: *Self) u8 {
    return switch (self.peek_token.token) {
        .plus => 1,
        else => 0,
    };
}

fn next_token(self: *Self) void {
    self.current_token = self.peek_token;
    self.peek_token = self.lexer.next_token() catch |err| {
        switch (err) {
            LexerError.OutOfMemory => std.debug.panic("Out of memory in lexer", .{}),
        }
    };
}

fn debug_print_current_token(self: Self) void {
    std.debug.print("current_token: {s}\n", .{self.current_token.token.toString()});
}

fn debug_print_peek_token(self: Self) void {
    std.debug.print("peek_token: {s}\n", .{self.peek_token.token.toString()});
}

fn peek_token_is(self: *Self, expected: Token.TokenKind) bool {
    return @as(Token.TokenKind, self.peek_token.token) == expected;
}

fn current_token_is(self: *Self, expected: Token.TokenKind) bool {
    return @as(Token.TokenKind, self.current_token.token) == expected;
}

fn expect_current(self: *Self, expected: Token.TokenKind) ParserError!void {
    if (self.current_token_is(expected)) {
        return self.next_token();
    } else {
        return self.error_context.addUnexpectedToken(&self.current_token, expected);
    }
}

fn expect_peek(self: *Self, expected: Token.TokenKind) ParserError!void {
    if (self.peek_token_is(expected)) {
        return self.next_token();
    } else {
        return self.error_context.addUnexpectedToken(&self.peek_token, expected);
    }
}

fn expect_peek_many(self: *Self, expected: []const Token.TokenKind) ParserError!void {
    for (expected) |expected_token| {
        if (self.peek_token_is(expected_token)) {
            return self.next_token();
        }
    }
    return self.error_context.addUnexpectedTokenMany(&self.peek_token, expected);
}

fn peek_token_is_many(self: *Self, expected: []const Token.TokenKind) bool {
    for (expected) |expected_token| {
        if (self.peek_token_is(expected_token)) {
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
        else => self.error_context.addNotImplementedError(&self.current_token),
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
    body.select_items = std.ArrayList(*Expression).init(self.allocator);
    while (self.peek_token_is_many(&[_]Token.TokenKind{ .identifier, .string_literal, .number, .local_variable, .asterisk, .left_paren })) {
        self.next_token();

        const column = try self.parse_expression(1);
        try body.select_items.append(column);
        if (!self.peek_token_is(Token.TokenKind.comma)) {
            break;
        }
        self.next_token();
    }

    try self.expect_peek(.from);
    self.next_token();

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
        self.next_token();

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

            return self.error_context.addUnexpectedToken(&self.current_token, null);
        },
        else => self.error_context.addUnexpectedToken(&self.current_token, null),
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
        else => self.error_context.addUnexpectedToken(&self.current_token, null),
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
    const input = "select hello, hello from testtable";

    const lexer = Lexer.new(allocator, input);
    var parser = Self.init(allocator, lexer);
    const parsed_sql = parser.parse();
    if (parser.errors().len > 0) {
        std.debug.print("errors: \n", .{});
        for (parser.errors()) |err| {
            std.debug.print("\t{s}\n", .{err});
        }
    }
    try std.testing.expectEqualDeep(statements, parsed_sql);
}
