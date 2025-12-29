const std = @import("std");
const token = @import("token.zig");
const Dialect = @import("dialect.zig").Dialect;
const Span = token.Span;
const Tag = token.Tag;
const Token = token.Token;

pub const Lexer = struct {
    source: []const u8,
    read: usize = 0,
    current: usize = 0,
    char: u8 = 0,

    pub fn init(source: []const u8) Lexer {
        var lexer = Lexer{ .source = source };
        lexer.readChar();
        return lexer;
    }

    pub fn next_token(lexer: *Lexer, dialect: Dialect) Token {
        lexer.skipWhitespace();
        const start = lexer.current;
        const tok = switch (lexer.char) {
            ':' => blk: {
                if (lexer.peek() == ':' and dialect == .postgres) {
                    lexer.readChar();
                    break :blk lexer.makeToken("::", .double_colon, start);
                } else {
                    break :blk lexer.makeToken(":", .illegal, start);
                }
            },
            ',' => lexer.makeToken(",", .comma, start),
            '(' => lexer.makeToken("(", .left_paren, start),
            ')' => lexer.makeToken(")", .right_paren, start),
            '=' => lexer.makeToken("=", .equal, start),
            '!' => blk: {
                if (lexer.peek() == '=') {
                    lexer.readChar();
                    break :blk lexer.makeToken("!=", .not_equal_bang, start);
                } else {
                    break :blk lexer.makeToken("!", .illegal, start);
                }
            },
            '<' => blk: {
                if (lexer.peek() == '=') {
                    lexer.readChar();
                    break :blk lexer.makeToken("<=", .less_than_equal, start);
                } else if (lexer.peek() == '>') {
                    lexer.readChar();
                    break :blk lexer.makeToken("<>", .not_equal_arrow, start);
                } else {
                    break :blk lexer.makeToken("<", .illegal, start);
                }
            },
            '>' => blk: {
                if (lexer.peek() == '=') {
                    lexer.readChar();
                    break :blk lexer.makeToken(">=", .greater_than_equal, start);
                } else {
                    break :blk lexer.makeToken(">", .illegal, start);
                }
            },
            '+' => blk: {
                if (lexer.peek() == '=') {
                    lexer.readChar();
                    break :blk lexer.makeToken("+=", .plus_equal, start);
                } else {
                    break :blk lexer.makeToken("+", .illegal, start);
                }
            },
            '-' => blk: {
                if (lexer.peek() == '=') {
                    lexer.readChar();
                    break :blk lexer.makeToken("-=", .plus_equal, start);
                } else if (lexer.peek() == '-') {
                    const slice = lexer.readCommentLine();
                    break :blk lexer.makeToken(slice, .comment_line, start);
                } else {
                    break :blk lexer.makeToken("-", .illegal, start);
                }
            },
            '/' => blk: {
                if (lexer.peek() == '=') {
                    lexer.readChar();
                    break :blk lexer.makeToken("/=", .divide_equal, start);
                } else {
                    break :blk lexer.makeToken("/", .forward_slash, start);
                }
            },
            '*' => blk: {
                if (lexer.peek() == '=') {
                    lexer.readChar();
                    break :blk lexer.makeToken("*=", .multiply_equal, start);
                } else {
                    break :blk lexer.makeToken("*", .asterisk, start);
                }
            },
            '%' => blk: {
                if (lexer.peek() == '=') {
                    lexer.readChar();
                    break :blk lexer.makeToken("%=", .mod_equal, start);
                } else {
                    break :blk lexer.makeToken("*", .mod, start);
                }
            },
            '^' => blk: {
                if (lexer.peek() == '=') {
                    lexer.readChar();
                    break :blk lexer.makeToken("^=", .caret_equal, start);
                } else {
                    break :blk lexer.makeToken("^", .illegal, start);
                }
            },
            '|' => blk: {
                if (lexer.peek() == '=') {
                    lexer.readChar();
                    break :blk lexer.makeToken("|=", .pipe_equal, start);
                } else {
                    break :blk lexer.makeToken("|", .pipe, start);
                }
            },
            '&' => blk: {
                if (lexer.peek() == '=') {
                    lexer.readChar();
                    break :blk lexer.makeToken("&=", .ampersand_equal, start);
                } else {
                    break :blk lexer.makeToken("&", .ampersand, start);
                }
            },
            '.' => lexer.makeToken(".", .period, start),
            ';' => lexer.makeToken(";", .semicolon, start),
            '[' => blk: {
                const slice = lexer.readQuotedIdentifier();
                break :blk lexer.makeToken(slice, .quoted_identifier, start);
            },
            '\'' => blk: {
                const slice = lexer.readQuotedString();
                break :blk lexer.makeToken(slice, .string_literal, start);
            },
            '~' => lexer.makeToken("~", .tilde, start),
            '@' => blk: {
                lexer.readChar();
                const slice = lexer.readIdentifier();
                break :blk lexer.makeToken(slice, .local_variable, start);
            },
            '0'...'9' => blk: {
                const slice = lexer.readNumber();
                break :blk lexer.makeToken(slice, .number_literal, start);
            },
            else => blk: {
                if (std.ascii.isAlphabetic(lexer.char) or lexer.char == '_') {
                    const slice = lexer.readIdentifier();
                    if (token.keyword(slice, dialect)) |tag| {
                        break :blk lexer.makeToken(slice, tag, start);
                    }
                    break :blk lexer.makeToken(slice, .identifier, start);
                }
                const slice = lexer.source[lexer.current .. lexer.current + 1];
                break :blk lexer.makeToken(slice, .illegal, start);
            },
        };

        lexer.readChar();
        return tok;
    }

    fn makeToken(lexer: *Lexer, lexeme: []const u8, tag: Tag, start: usize) Token {
        return Token{
            .tag = tag,
            .lexeme = lexeme,
            .span = Span.fromOffsets(start, lexer.current),
        };
    }

    fn readChar(lexer: *Lexer) void {
        if (lexer.read >= lexer.source.len) {
            lexer.char = 0;
        } else {
            lexer.char = lexer.source[lexer.read];
        }

        lexer.current = lexer.read;
        lexer.read += 1;
    }

    fn peek(lexer: *Lexer) u8 {
        // check to see if we have reached end of input
        if (lexer.read >= lexer.source.len) {
            return 0;
        }

        return lexer.source[lexer.read];
    }

    fn skipWhitespace(lexer: *Lexer) void {
        while (std.ascii.isWhitespace(lexer.char)) {
            lexer.readChar();
        }
    }

    fn readCommentLine(lexer: *Lexer) []const u8 {
        // skip the -- characters
        lexer.readChar();
        lexer.readChar();

        // read the identifier until next quote
        const start = lexer.current;

        while (true) {
            const peekChar = lexer.peek();
            if (peekChar == '\n' or peekChar == 0) {
                break;
            }
            lexer.readChar();
        }

        return lexer.source[start .. lexer.current + 1];
    }

    fn readQuotedIdentifier(lexer: *Lexer) []const u8 {
        // skip the quote character
        lexer.readChar();

        // read the identifier until next quote
        const start = lexer.current;

        while (true) {
            const peekChar = lexer.peek();
            if (peekChar == ']' or peekChar == 0) {
                break;
            }
            lexer.readChar();
        }

        // go to the quote character
        lexer.readChar();

        return lexer.source[start..lexer.current];
    }

    fn readQuotedString(lexer: *Lexer) []const u8 {
        // skip the quote character
        lexer.readChar();

        // read the identifier until next quote
        const start = lexer.current;

        while (true) {
            const peekChar = lexer.peek();
            if (peekChar == '\'' or peekChar == 0) {
                break;
            }
            lexer.readChar();
        }

        // go to the quote character
        lexer.readChar();

        return lexer.source[start..lexer.current];
    }

    fn readNumber(lexer: *Lexer) []const u8 {
        const start = lexer.current;
        while (std.ascii.isDigit(lexer.peek())) {
            lexer.readChar();
        }

        // check for floating point
        if (lexer.peek() == '.') {
            lexer.readChar();

            while (std.ascii.isDigit(lexer.peek())) {
                lexer.readChar();
            }
        }

        if (lexer.current + 1 >= lexer.source.len) {
            return lexer.source[start..];
        }
        return lexer.source[start .. lexer.current + 1];
    }

    fn readIdentifier(lexer: *Lexer) []const u8 {
        const start = lexer.current;
        var peekChar = lexer.peek();
        while (std.ascii.isAlphabetic(peekChar) or peekChar == '_') {
            lexer.readChar();
            peekChar = lexer.peek();
        }

        if (lexer.current + 1 >= lexer.source.len) {
            return lexer.source[start..];
        }
        return lexer.source[start .. lexer.current + 1];
    }
};

test "basic select test" {
    const input = "seLECt * from table;";
    const expectEqualDeep = std.testing.expectEqualDeep;
    const tests = [_]Token{
        .{
            .tag = .kw_select,
            .lexeme = "seLECt",
            .span = .{
                .start = 0,
                .end = 5,
            },
        },
        .{
            .tag = .asterisk,
            .lexeme = "*",
            .span = .{
                .start = 7,
                .end = 7,
            },
        },
        .{
            .tag = .kw_from,
            .lexeme = "from",
            .span = .{
                .start = 9,
                .end = 12,
            },
        },
        .{
            .tag = .identifier,
            .lexeme = "table",
            .span = .{
                .start = 14,
                .end = 18,
            },
        },
        .{
            .tag = .semicolon,
            .lexeme = ";",
            .span = .{
                .start = 19,
                .end = 19,
            },
        },
    };

    var lexer = Lexer.init(input);

    for (0..tests.len) |i| {
        const tok = lexer.next_token(Dialect.sqlserver);
        const test_token = tests[i];

        try expectEqualDeep(test_token, tok);
    }
}
