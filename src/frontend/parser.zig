const lex = @import("lexer.zig");
const tok = @import("token.zig");
const ast = @import("ast.zig");
const std = @import("std");
const dial = @import("dialect.zig");

pub const Error = error{
    UnexpectedToken,
    ExpectedKeyword,
} || lex.Error;

pub const Parser = struct {
    arena: std.heap.ArenaAllocator,
    allocator: std.mem.Allocator,
    lexer: lex.Lexer,
    dialect: dial.Dialect,
    current_token: tok.Token = undefined,

    pub fn init(allocator: std.mem.Allocator, lexer: lex.Lexer, dialect: dial.Dialect) Error!Parser {
        const arena = std.heap.ArenaAllocator.init(allocator);
        var parser = Parser{
            .arena = arena,
            .allocator = allocator,
            .lexer = lexer,
            .dialect = dialect,
        };
        try parser.nextToken();
        return parser;
    }

    // pub fn parse(parser: *Parser) void {}

    fn nextToken(parser: *Parser) Error!void {
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

    fn consumeKeyword(parser: *Parser, kw: dial.Keyword) Error!ast.Keyword {
        const current_token = parser.current_token;
        if (current_token.tag != .identifier) {
            return Error.ExpectedKeyword;
        }
        const maybeKw = dial.lookupKeyword(current_token.lexeme, parser.dialect);
        if (maybeKw != kw) {
            return Error.ExpectedKeyword;
        }
        try parser.next_token();

        return ast.Keyword{
            .tag = kw,
            .span = current_token.span,
        };
    }

    fn consumeToken(parser: *Parser, tag: tok.Tag) Error!tok.Token {
        const current_token = parser.current_token;
        if (current_token.tag != tag) {
            return Error.UnexpectedToken;
        }
        try parser.next_token();

        return current_token;
    }

    fn consumeTokenAny(parser: *Parser, tags: []tok.Tag) Error!tok.Token {
        const current_token = parser.current_token;
        for (tags) |tag| {
            if (parser.tokenIs(tag)) {
                try parser.next_token();
                return current_token;
            }
        }

        return Error.UnexpectedToken;
    }

    fn maybeKeyword(parser: *Parser, kw: dial.Keyword) ?ast.Keyword {
        const current_token = parser.current_token;
        if (current_token.tag != .identifier) {
            return null;
        }
        const maybeKw = dial.lookupKeyword(current_token.lexeme, parser.dialect);
        if (maybeKw != kw) {
            return null;
        }
        try parser.next_token();

        return ast.Keyword{
            .tag = kw,
            .span = current_token.span,
        };
    }
};
