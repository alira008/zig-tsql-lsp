const lex = @import("lexer.zig");
const token = @import("token.zig");
const std = @import("std");
const query = @import("ast/query.zig");
const ast = @import("ast/ast.zig");

pub const Parser = struct {
    allocator: std.mem.Allocator,
    lexer: lex.Lexer,
    current_token: token.Token,
    peek_token: token.Token,

    pub fn init(allocator: std.mem.Allocator, lexer: lex.Lexer) Parser {
        var parser = Parser{
            .allocator = allocator,
            .lexer = lexer,
            .current_token = undefined,
            .peek_token = undefined,
        };

        parser.next_token();
        parser.next_token();

        return parser;
    }

    pub fn parse(self: *Parser) !ast.Sql {
        var list = std.ArrayList(ast.Statement).init(self.allocator);
        while (self.current_token != .eof) {
            const statement = self.parse_statement() catch |err| {
                std.debug.print("failed to parse statement\n", .{});
                std.debug.print("error: {}\n", .{err});
                self.next_token();
                continue;
            };
            list.append(statement) catch {
                std.debug.print("failed to append statement to list\n", .{});
            };

            self.next_token();
        }
        return ast.Sql{ .statements = try list.toOwnedSlice() };
    }

    const ParserError = error{ InvalidToken, NotImplemented, OutOfMemory };

    fn peek_precedence(self: *Parser) u8 {
        return switch (self.peek_token.token) {
            .plus => 1,
            else => 0,
        };
    }

    fn next_token(self: *Parser) void {
        self.current_token = self.peek_token;
        self.peek_token = self.lexer.next_token();
    }

    fn peek_token_is(self: *Parser, expected: token.TokenKind) bool {
        return @as(token.TokenKind, self.peek_token) == expected;
    }

    fn current_token_is(self: *Parser, expected: token.TokenKind) bool {
        return @as(token.TokenKind, self.current_token) == expected;
    }

    fn expect_peek(self: *Parser, expected: token.TokenKind) bool {
        if (self.peek_token_is(expected)) {
            self.next_token();
            return true;
        } else {
            return false;
        }
    }

    fn expect_peek_many(self: *Parser, expected: []const token.TokenKind) bool {
        for (expected) |expected_token| {
            if (self.peek_token_is(expected_token)) {
                self.next_token();
                return true;
            }
        }
        return false;
    }

    fn parse_statement(self: *Parser) ParserError!ast.Statement {
        std.debug.print("parsing statement\n", .{});
        std.debug.print("current token: {s}\n", .{self.current_token.to_string()});
        return switch (self.current_token) {
            .with => blk: {
                const select_statement = try self.parse_cte();
                break :blk ast.Statement{ .select = select_statement };
            },
            .select => blk: {
                const select_body = try self.parse_select_body();
                break :blk ast.Statement{ .select = query.SelectStatement{ .common_table_expression = null, .body = select_body } };
            },
            else => ParserError.NotImplemented,
        };
    }

    fn parse_cte(self: *Parser) ParserError!query.SelectStatement {
        var statement = query.SelectStatement{ .common_table_expression = null, .body = undefined };
        std.debug.print("parsing select\n", .{});
        if (self.current_token_is(.with)) {
            std.debug.print("parsing cte\n", .{});
        }

        if (!self.peek_token_is(.select)) {
            return ParserError.InvalidToken;
        }

        std.debug.print("parsing select body\n", .{});
        statement.body = try self.parse_select_body();

        return statement;
    }

    fn parse_select_body(self: *Parser) ParserError!query.SelectBody {
        std.debug.print("parsing select body\n", .{});
        var body = query.SelectBody{
            .select_items = undefined,
            .table = undefined,
            .where = undefined,
        };

        // parse the columns
        if (!self.expect_peek_many(&[_]token.TokenKind{ .identifier, .string_literal })) {
            return ParserError.InvalidToken;
        }

        if (!self.expect_peek(.from)) {
            return ParserError.InvalidToken;
        }
        return body;
    }

    fn parse_expression(self: *Parser, precedence: u8) ParserError!ast.Expression {
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

    fn parse_prefix_expression(self: *Parser) ParserError!ast.Expression {
        return switch (self.current_token) {
            .identifier, .number, .local_variable, .string_literal, .quoted_identifier => expr: {
                if (self.current_token == .identifier) {
                    break :expr ast.Expression{ .identifier = self.current_token };
                } else if (self.current_token == .number) {
                    break :expr ast.Expression{ .literal = self.current_token };
                } else if (self.current_token == .local_variable) {
                    break :expr ast.Expression{ .local_variable = self.current_token };
                } else if (self.current_token == .string_literal) {
                    break :expr ast.Expression{ .literal = self.current_token };
                } else if (self.current_token == .quoted_identifier) {
                    break :expr ast.Expression{ .quoted_identifier = self.current_token };
                }

                return ParserError.InvalidToken;
            },
            else => ParserError.InvalidToken,
        };
    }

    fn parse_infix_expression(self: *Parser, left: query.Expression) ParserError!ast.Expression {
        _ = left;
        return switch (self.current_token) {
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
};

test "parse select statement" {
    const heap_allocator = std.heap.page_allocator;
    var arena = std.heap.ArenaAllocator.init(heap_allocator);
    defer arena.deinit();
    var item = arena.allocator().create(ast.Expression) catch return;
    item.* = ast.Expression{ .identifier = "hello" };
    var select_items = &[_]*ast.Expression{item};
    const test_ast_statement = ast.Statement{ .select = query.SelectStatement{ .common_table_expression = null, .body = query.SelectBody{ .select_items = select_items[0..], .table = ast.Expression{ .identifier = "table1" } } } };
    var allocator = arena.allocator();

    var statements = [_]ast.Statement{test_ast_statement};
    const testSql = ast.Sql{ .statements = &statements };

    const input = "select hello from table1";

    var lexer = lex.Lexer.new(input);
    var parser = Parser.init(allocator, lexer);
    const sql = try parser.parse();
    try std.testing.expectEqualDeep(testSql, sql);
}
