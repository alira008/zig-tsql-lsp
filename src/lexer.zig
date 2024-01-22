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

    fn peak_char(self: *Self) u8 {
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
                self.column = 0;
            } else {
                self.column += 1;
            }
        }

        self.position = self.read_position;
        self.read_position += 1;
    }

    fn read_identifier(self: *Self) []const u8 {
        const position = self.position;

        while (is_letter(self.char)) {
            self.read_char();
        }

        return self.input[position..self.position];
    }

    fn read_number(self: *Self) []const u8 {
        const position = self.position;

        while (is_float(self.char)) {
            self.read_char();
        }

        return self.input[position..self.position];
    }

    fn read_quoted_literal(self: *Self, quote_char: u8) []const u8 {
        const position = self.position;

        while (self.char != quote_char and self.peak_char() != quote_char) {
            self.read_char();
        }

        return self.input[position..self.position];
    }

    fn read_alias(self: *Self) []const u8 {
        const position = self.position;

        while (self.char != ']') {
            self.read_char();
        }

        return self.input[position..self.position];
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
            '\'' => {
                const word = self.read_quoted_literal('\'');
                // read closing '\''
                self.read_char();

                return .{ .quoted_literal = .{ .value = word, .quote_char = '\'' } };
            },
            '[' => {
                const word = self.read_quoted_literal(']');
                // read closing ']'
                self.read_char();

                return .{ .quoted_literal = .{ .value = word, .quote_char = '[' } };
            },
            ',' => token.Token.comma,
            '<' => blk: {
                if (self.peak_char() == '=') {
                    break :blk token.Token.less_than_equal;
                } else {
                    break :blk token.Token.less_than;
                }
            },
            '>' => blk: {
                if (self.peak_char() == '=') {
                    break :blk token.Token.greater_than_equal;
                } else {
                    break :blk token.Token.greater_than;
                }
            },
            '=' => token.Token.equal,
            '*' => token.Token.asterisk,
            '!' => blk: {
                if (self.peak_char() == '=') {
                    break :blk token.Token.not_equal;
                } else {
                    break :blk token.Token.illegal;
                }
            },
            'a'...'z', 'A'...'Z', '_' => {
                const ident = self.read_identifier();
                if (token.Token.keyword(ident)) |tok| {
                    return tok;
                }
                return .{ .identifier = ident };
            },
            '0'...'9' => {
                const num_str = self.read_number();
                var number_of_periods: u16 = 0;
                for (num_str) |c| {
                    if (c == '.') {
                        number_of_periods += 1;
                    }
                }

                if (number_of_periods == 0) {
                    const number = std.fmt.parseInt(i32, num_str, 10) catch return token.Token.illegal;
                    return .{ .integer = number };
                } else if (number_of_periods == 1) {
                    const number = std.fmt.parseFloat(f64, num_str) catch return token.Token.illegal;
                    return .{ .float = number };
                }

                return token.Token.illegal;
            },
            0 => token.Token.eof,
            else => token.Token.illegal,
        };

        self.read_char();

        return tok;
    }
};

test "next token function" {
    const input = "=+(),# 4.2 4";
    const tests = [_]token.Token{ token.Token.equal, token.Token.plus, token.Token.left_paren, token.Token.right_paren, token.Token.comma, token.Token.sharp, token.Token{ .float = 4.2 }, token.Token{ .integer = 4 } };

    var lexer = Lexer.new(input);

    for (0..tests.len) |i| {
        const location = lexer.location();
        const tok = lexer.next_token();
        const test_token = tests[i];

        std.debug.print("Location {}\n", .{location});
        try expectEqualDeep(test_token, tok);
    }
}
