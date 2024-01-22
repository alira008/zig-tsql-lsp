const lex = @import("lexer.zig");
const token = @import("token.zig");
const std = @import("std");
const query = @import("ast/query.zig");

pub const Parser = struct {
    allocator: std.mem.Allocator,
    lexer: lex.Lexer,
    current_token: token.TokenWithLocation,
    peek_token: token.TokenWithLocation,

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

    fn next_token(self: *Parser) void {
        self.current_token = self.peek_token;
        const location = self.lexer.location();
        self.peek_token = .{ .token = self.lexer.next_token(), .location = location };
    }

    fn peek_token_is(self: *Parser, expected: token.TokenKind) bool {
        return @as(token.TokenKind, self.peek_token.token) == expected;
    }

    fn current_token_is(self: *Parser, expected: token.TokenKind) bool {
        return @as(token.TokenKind, self.current_token.token) == expected;
    }

    pub fn parse(self: *Parser) !void {
        var list = std.ArrayList(query.Statement).init(self.allocator);
        defer list.deinit();
        while (self.current_token.token != .eof) {
            const statement = self.parse_statement() catch |err| {
                std.debug.print("failed to parse statement\n", .{});
                std.debug.print("error: {}\n", .{err});
                self.next_token();
                continue;
            };
            list.append(statement) catch {
                std.debug.print("failed to append\n", .{});
            };
            self.next_token();
        }
    }

    fn parse_statement(self: *Parser) ParserError!query.Statement {
        return switch (self.current_token.token) {
            .select => blk: {
                const select_statement = try self.parse_select();
                break :blk query.Statement{ .select = select_statement };
            },
            else => ParserError.NotImplemented,
        };
    }

    fn parse_select(self: *Parser) ParserError!query.SelectStatement {
        std.debug.print("parsing select\n", .{});
        var statement = query.SelectStatement{};

        if (self.peek_token_is(.distinct)) {
            self.next_token();
            statement.distinct = true;
        }

        self.next_token();
        var expression = try self.parse_expression(0);
        var columns = std.ArrayList(query.Expression).init(self.allocator);
        statement.columns = columns;
        std.debug.print("expression: {}\n", .{expression});

        return statement;
    }

    fn parse_expression(self: *Parser, precedence: u8) ParserError!query.Expression {
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

    fn parse_prefix_expression(self: *Parser) ParserError!query.Expression {
        return switch (self.current_token.token) {
            .identifier, .float, .integer, .asterisk => expr: {
                if (self.peek_token_is(.period)) {
                    var idents = std.ArrayList(token.TokenWithLocation).init(self.allocator);
                    defer idents.deinit();
                    std.debug.print("parsing compound literal\n", .{});
                    while (self.peek_token_is(.period)) {
                        // skip to the dot
                        self.next_token();

                        if (!self.peek_token_is(.identifier) and !self.peek_token_is(.asterisk)) {
                            return ParserError.InvalidToken;
                        }
                        self.next_token();

                        idents.append(self.current_token) catch return ParserError.OutOfMemory;
                    }
                    break :expr query.Expression{ .compound_literal = idents };
                } else {
                    break :expr query.Expression{ .literal = self.current_token };
                }
            },
            else => query.Expression{ .literal = self.current_token },
        };
    }

    fn parse_infix_expression(self: *Parser, left: query.Expression) ParserError!query.Expression {
        _ = left;
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

    fn peek_precedence(self: *Parser) u8 {
        return switch (self.peek_token.token) {
            .plus => 1,
            else => 0,
        };
    }

    const ParserError = error{ InvalidToken, NotImplemented, OutOfMemory };
};
