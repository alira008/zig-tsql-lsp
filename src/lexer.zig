const std = @import("std");
const token = @import("token.zig");
const expectEqualDeep = std.testing.expectEqualDeep;

pub const Lexer = struct {
    const Self = @This();

    input: []const u8,
    position: usize = 0,
    read_position: usize = 0,
    char: u8 = 0,
    line: usize = 1,
    column: usize = 0,

    pub fn new(input: []const u8) Self {
        var lexer = Self{
            .input = input,
        };

        lexer.read_char();

        return lexer;
    }

    pub fn location(self: *Self) token.Location {
        return .{ .line = self.line, .column = self.column };
    }

    fn peek_char(self: *Self) u8 {
        // check to see if we have reached end of input
        if (self.read_position >= self.input.len) {
            return 0;
        }

        return self.input[self.read_position];
    }

    fn is_letter(ch: u8) bool {
        return std.ascii.isAlphabetic(ch) or ch == '_';
    }

    fn is_float(ch: u8) bool {
        return std.ascii.isDigit(ch) or ch == '.';
    }

    // give us next character and advance our position in the input string
    fn read_char(self: *Self) void {
        // check to see if we have reached end of input
        if (self.read_position >= self.input.len) {
            self.char = 0;
        } else {
            self.char = self.input[self.read_position];
            if (self.char == '\n') {
                self.line += 1;
                self.column = 1;
            } else {
                self.column += 1;
            }
        }

        self.position = self.read_position;
        self.read_position += 1;
    }

    fn read_identifier(self: *Self) []const u8 {
        const position = self.position;

        while (is_letter(self.peek_char()) and self.peek_char() != 0) {
            self.read_char();
        }

        return self.input[position .. self.position + 1];
    }

    fn read_number(self: *Self) []const u8 {
        const position = self.position;

        while (std.ascii.isDigit(self.peek_char()) and self.peek_char() != 0) {
            self.read_char();
        }

        // check if we have a float
        // if we have a period, we have a float
        if (self.peek_char() == '.') {
            self.read_char();
            while (std.ascii.isDigit(self.peek_char()) and self.peek_char() != 0) {
                self.read_char();
            }
        }

        return self.input[position .. self.position + 1];
    }

    fn read_quoted_identifier(self: *Self) []const u8 {
        // skip the quote character
        self.read_char();
        const position = self.position;
        while (self.peek_char() != ']' and self.peek_char() != 0) {
            self.read_char();
        }
        // skip the quote character
        self.read_char();
        return self.input[position..self.position];
    }

    fn read_string_literal(self: *Self) []const u8 {
        // skip the quote character
        self.read_char();
        const position = self.position;
        while (self.peek_char() != '\'' and self.peek_char() != 0) {
            self.read_char();
        }

        // skip the quote character
        self.read_char();

        return self.input[position..self.position];
    }

    fn read_local_variable(self: *Self) []const u8 {
        // skip the @ character
        self.read_char();
        const position = self.position;
        while (is_letter(self.peek_char()) and self.peek_char() != 0) {
            self.read_char();
        }

        return self.input[position .. self.position + 1];
    }

    fn skip_whitespace(self: *Self) void {
        while (std.ascii.isWhitespace(self.char)) {
            self.read_char();
        }
    }

    pub fn next_token(self: *Self) token.Token {
        self.skip_whitespace();

        const tok: token.Token = switch (self.char) {
            '#' => token.Token.sharp,
            '~' => token.Token.tilde,
            '.' => token.Token.period,
            '(' => token.Token.left_paren,
            ')' => token.Token.right_paren,
            '+' => token.Token.plus,
            '-' => token.Token.minus,
            '\'' => blk: {
                const word = self.read_string_literal();
                // read closing '\''
                self.read_char();

                break :blk .{ .string_literal = word };
            },
            '[' => blk: {
                const word = self.read_quoted_identifier();
                // read closing ']'
                self.read_char();

                break :blk .{ .quoted_identifier = word };
            },
            '@' => blk: {
                const word = self.read_local_variable();
                break :blk .{ .local_variable = word };
            },
            ',' => token.Token.comma,
            '<' => blk: {
                if (self.peek_char() == '=') {
                    break :blk token.Token.less_than_equal;
                } else {
                    break :blk token.Token.less_than;
                }
            },
            '>' => blk: {
                if (self.peek_char() == '=') {
                    break :blk token.Token.greater_than_equal;
                } else {
                    break :blk token.Token.greater_than;
                }
            },
            '=' => token.Token.equal,
            '*' => token.Token.asterisk,
            '!' => blk: {
                if (self.peek_char() == '=') {
                    break :blk token.Token.not_equal;
                } else {
                    break :blk token.Token.illegal;
                }
            },
            'a'...'z', 'A'...'Z', '_' => blk: {
                const ident = self.read_identifier();
                if (token.Token.keyword(ident)) |tok| {
                    break :blk tok;
                }
                break :blk .{ .identifier = ident };
            },
            '0'...'9' => blk: {
                const num_str = self.read_number();

                const number = std.fmt.parseFloat(f64, num_str) catch return token.Token.illegal;
                break :blk .{ .number = number };
            },
            0 => token.Token.eof,
            else => token.Token.illegal,
        };

        self.read_char();

        return tok;
    }
};

test "basic select test" {
    const input = "seLECt * from table;";
    const tests = [_]token.Token{
        token.Token.select,
        token.Token.asterisk,
        token.Token.from,
        token.Token{ .identifier = "table" },
    };

    var lexer = Lexer.new(input);

    // std.debug.print("\n", .{});
    for (0..tests.len) |i| {
        // const location = lexer.location();
        const tok = lexer.next_token();
        const test_token = tests[i];

        // std.debug.print("Location {}\n", .{location});
        // std.debug.print("Token: {s}\n", .{tok.to_string()});
        try expectEqualDeep(test_token, tok);
    }
}

test "general lex test" {
    const input = "=+(),# 4.2 4 exec from hello @yes [yessir] 'noo'";
    const tests = [_]token.Token{ token.Token.equal, token.Token.plus, token.Token.left_paren, token.Token.right_paren, token.Token.comma, token.Token.sharp, token.Token{ .number = 4.2 }, token.Token{ .number = 4 }, token.Token.exec, token.Token.from, token.Token{ .identifier = "hello" }, token.Token{ .local_variable = "yes" }, token.Token{ .quoted_identifier = "yessir" }, token.Token{ .string_literal = "noo" } };

    var lexer = Lexer.new(input);

    // std.debug.print("\n", .{});
    for (0..tests.len) |i| {
        // const location = lexer.location();
        const tok = lexer.next_token();
        const test_token = tests[i];

        // std.debug.print("Location {}\n", .{location});
        // std.debug.print("Token: {s}\n", .{tok.to_string()});
        try expectEqualDeep(test_token, tok);
    }
}
