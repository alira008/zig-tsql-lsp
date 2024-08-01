const std = @import("std");
const ast = @import("ast");
const Lexer = @import("lexer");
const query = ast.query;
const errors = @import("errors.zig");
const OperatorPrecedence = @import("precedence.zig").OperatorPrecedence;
const getPrecedence = @import("precedence.zig").getPrecedence;
const LexerError = Lexer.LexerError;
const Token = Lexer.Token;
const TokenKind = Token.TokenKind;
const ErrorContext = errors.ErrorContext;
const ParserError = errors.ParserError;
const Expression = ast.expression.Expression;

const Self = @This();

allocator: std.mem.Allocator,
lexer: Lexer,
current_token: Token,
peek_token: Token,
peek_token2: Token,
error_context: ErrorContext,

pub fn init(allocator: std.mem.Allocator, lexer: Lexer) Self {
    var parser = Self{
        .allocator = allocator,
        .lexer = lexer,
        .current_token = undefined,
        .peek_token = undefined,
        .peek_token2 = undefined,
        .error_context = ErrorContext.init(allocator),
    };

    parser.next_token();
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

fn peek_precedence(self: *Self) OperatorPrecedence {
    return getPrecedence(self.peek_token.token);
}

fn next_token(self: *Self) void {
    self.current_token = self.peek_token;
    self.peek_token = self.peek_token2;
    self.peek_token2 = self.lexer.next_token();
}

fn debug_print_current_token(self: Self) void {
    std.debug.print("current_token: {s}\n", .{self.current_token.token.toString()});
}

fn debug_print_peek_token(self: Self) void {
    std.debug.print("peek_token: {s}\n", .{self.peek_token.token.toString()});
}

fn peek_token_is(self: *Self, expected: TokenKind) bool {
    return @as(TokenKind, self.peek_token.token) == expected;
}

fn peek_token2_is(self: *Self, expected: TokenKind) bool {
    return @as(TokenKind, self.peek_token2.token) == expected;
}

fn current_token_is(self: *Self, expected: TokenKind) bool {
    return @as(TokenKind, self.current_token.token) == expected;
}

fn expect_current(self: *Self, expected: TokenKind) ParserError!void {
    if (self.current_token_is(expected)) {
        return self.next_token();
    } else {
        return self.error_context.addUnexpectedToken(&self.current_token, expected);
    }
}

fn expect_peek(self: *Self, expected: TokenKind) ParserError!void {
    if (self.peek_token_is(expected)) {
        return self.next_token();
    } else {
        return self.error_context.addUnexpectedToken(&self.peek_token, expected);
    }
}

fn expect_peek2(self: *Self, expected: TokenKind) ParserError!void {
    if (self.peek_token2_is(expected)) {
        return self.next_token();
    } else {
        return self.error_context.addUnexpectedToken(&self.peek_token2, expected);
    }
}

fn expect_peek_many(self: *Self, expected: []const TokenKind) ParserError!void {
    for (expected) |expected_token| {
        if (self.peek_token_is(expected_token)) {
            return self.next_token();
        }
    }
    return self.error_context.addUnexpectedTokenMany(&self.peek_token, expected);
}

fn peek_token_is_many(self: *Self, expected: []const TokenKind) bool {
    for (expected) |expected_token| {
        if (self.peek_token_is(expected_token)) {
            return true;
        }
    }
    return false;
}

fn parse_statement(self: *Self) ParserError!query.Statement {
    std.debug.print("parsing statement\n", .{});
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

fn parse_select_clause(self: *Self) ParserError!query.Select.SelectClause {
    var select_clause: query.Select.SelectClause = .{
        .start = self.current_token.start_pos,
        .items = undefined,
    };

    var items = std.ArrayList(*Expression).init(self.allocator);
    while (self.peek_token_is_many(&[_]TokenKind{ .identifier, .string_literal, .number, .local_variable, .asterisk, .left_paren })) {
        self.next_token();

        const column = try self.parse_expression(.lowest);
        try items.append(column);

        if (!self.peek_token_is(.comma)) {
            break;
        }
        self.next_token();
    }

    select_clause.items = try items.toOwnedSlice();
    select_clause.end = self.current_token.end_pos;
    return select_clause;
}

fn parse_select(self: *Self) ParserError!query.Select {
    std.debug.print("parsing select body\n", .{});
    var body = query.Select{
        .start = self.current_token.start_pos,
        .end = undefined,
        .select = undefined,
        .select_clause = undefined,
        .table = undefined,
    };
    const select: query.KeywordType = .{
        .single = .{
            .start = .{ .line = 1, .column = 1 },
            .end = .{ .line = 1, .column = 6 },
        },
    };
    body.select = select;

    // parse the columns
    const select_clause = try self.parse_select_clause();

    // try self.expect_peek(.from);
    // self.next_token();

    // const table = try self.parse_expression(.lowest);
    // body.table = table;
    body.select_clause = select_clause;
    body.end = self.current_token.end_pos;

    return body;
}

fn parse_expression(self: *Self, precedence: OperatorPrecedence) ParserError!*Expression {
    // check if the current token is an identifier
    // or if it is a prefix operator
    var left_expression = try self.parse_prefix_expression();

    while (@intFromEnum(precedence) < @intFromEnum(self.peek_precedence())) {
        // move to the next token
        self.next_token();

        left_expression = try self.parse_infix_expression(left_expression);
    }

    return left_expression;
}

fn parse_prefix_expression(self: *Self) ParserError!*Expression {
    const expr = try self.allocator.create(Expression);
    errdefer self.allocator.destroy(expr);

    expr.* = switch (self.current_token.token) {
        .identifier,
        .number,
        .local_variable,
        .string_literal,
        .quoted_identifier,
        => expr: {
            var expression: Expression = undefined;
            if (self.current_token.token == .identifier) {
                expression = Expression{
                    .identifier = .{
                        .start = self.current_token.start_pos,
                        .end = self.current_token.end_pos,
                        .value = try self.allocator.dupe(u8, self.current_token.token.identifier),
                    },
                };
            } else if (self.current_token.token == .number) {
                expression = Expression{
                    .number_literal = .{
                        .start = self.current_token.start_pos,
                        .end = self.current_token.end_pos,
                        .value = self.current_token.token.number,
                    },
                };
            } else if (self.current_token.token == .local_variable) {
                expression = Expression{
                    .local_variable_identifier = .{
                        .start = self.current_token.start_pos,
                        .end = self.current_token.end_pos,
                        .value = try self.allocator.dupe(
                            u8,
                            self.current_token.token.local_variable,
                        ),
                    },
                };
            } else if (self.current_token.token == .string_literal) {
                expression = Expression{
                    .string_literal = .{
                        .start = self.current_token.start_pos,
                        .end = self.current_token.end_pos,
                        .value = try self.allocator.dupe(
                            u8,
                            self.current_token.token.string_literal,
                        ),
                    },
                };
            } else if (self.current_token.token == .quoted_identifier) {
                expression = Expression{
                    .quote_identifier = .{
                        .start = self.current_token.start_pos,
                        .end = self.current_token.end_pos,
                        .value = try self.allocator.dupe(
                            u8,
                            self.current_token.token.quoted_identifier,
                        ),
                    },
                };
            } else {
                return self.error_context.addUnexpectedToken(&self.current_token, null);
            }

            break :expr expression;
        },
        else => return self.error_context.addUnexpectedToken(&self.current_token, null),
    };

    return expr;
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

    const hello_column1 = try allocator.create(Expression);
    errdefer allocator.destroy(hello_column1);
    const hello_column2 = try allocator.create(Expression);
    errdefer allocator.destroy(hello_column2);

    hello_column1.* = Expression{
        .identifier = .{
            .start = .{ .column = 8, .line = 1 },
            .end = .{ .column = 12, .line = 1 },
            .value = try allocator.dupe(u8, "hello"),
        },
    };
    hello_column2.* = Expression{
        .identifier = .{
            .start = .{ .column = 15, .line = 1 },
            .end = .{ .column = 19, .line = 1 },
            .value = try allocator.dupe(u8, "hello"),
        },
    };

    var select_items = std.ArrayList(*Expression).init(allocator);
    try select_items.append(hello_column1);
    try select_items.append(hello_column2);

    // const table = try allocator.create(Expression);
    // errdefer allocator.destroy(table);
    // table.* = Expression{ .identifier = try allocator.dupe(u8, "testtable") };
    var statements = std.ArrayList(query.Statement).init(allocator);
    try statements.append(
        query.Statement{
            .select = .{
                .start = .{ .column = 1, .line = 1 },
                .end = .{ .column = 19, .line = 1 },
                .select_clause = .{
                    .start = .{ .column = 8, .line = 1 },
                    .end = .{ .column = 19, .line = 1 },
                    .items = try select_items.toOwnedSlice(),
                },
                .table = null,
                // .where = null,
            },
        },
    );
    const input = "select hello, hello";

    const lexer = Lexer.new(input);
    var parser = Self.init(allocator, lexer);
    const parsed_sql = parser.parse();
    if (parser.error_context.errors.items.len > 0) {
        std.debug.print("errors: \n", .{});
        for (parser.error_context.errors.items) |err| {
            std.debug.print("\t{s}\n", .{err});
        }
    }
    try std.testing.expectEqualDeep(statements, parsed_sql);
}
