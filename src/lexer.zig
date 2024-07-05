const std = @import("std");
const Token = @import("token.zig");
const expectEqualDeep = std.testing.expectEqualDeep;

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

pub fn location(self: *Self) Token.Location {
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
    }

    if (self.char == '\n') {
        self.line += 1;
        self.column = 1;
    } else {
        self.column += 1;
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

pub fn next_token(self: *Self) Token {
    self.skip_whitespace();

    const start_pos = Token.Position.init(self.line, self.column);
    const tok: Token.TokenType = switch (self.char) {
        '#' => Token.TokenType.sharp,
        '~' => Token.TokenType.tilde,
        '.' => Token.TokenType.period,
        ';' => Token.TokenType.semicolon,
        '(' => Token.TokenType.left_paren,
        ')' => Token.TokenType.right_paren,
        '+' => Token.TokenType.plus,
        '-' => Token.TokenType.minus,
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
        ',' => Token.TokenType.comma,
        '<' => blk: {
            if (self.peek_char() == '=') {
                break :blk Token.TokenType.less_than_equal;
            } else {
                break :blk Token.TokenType.less_than;
            }
        },
        '>' => blk: {
            if (self.peek_char() == '=') {
                break :blk Token.TokenType.greater_than_equal;
            } else {
                break :blk Token.TokenType.greater_than;
            }
        },
        '=' => Token.TokenType.equal,
        '*' => Token.TokenType.asterisk,
        '!' => blk: {
            if (self.peek_char() == '=') {
                break :blk Token.TokenType.not_equal;
            } else {
                break :blk Token.TokenType.illegal;
            }
        },
        'a'...'z', 'A'...'Z', '_' => blk: {
            const ident = self.read_identifier();
            if (Token.TokenType.keyword(ident)) |tok| {
                break :blk tok;
            }
            break :blk .{ .identifier = ident };
        },
        '0'...'9' => blk: {
            const num_str = self.read_number();

            const number = std.fmt.parseFloat(f64, num_str) catch return .{ .token = Token.TokenType.illegal, .start_pos = start_pos, .end_pos = Token.Position.init(self.line, self.column) };
            break :blk .{ .number = number };
        },
        0 => Token.TokenType.eof,
        else => Token.TokenType.illegal,
    };

    const end_pos = Token.Position.init(self.line, self.column);
    self.read_char();

    return .{ .token = tok, .start_pos = start_pos, .end_pos = end_pos };
}

test "basic select test" {
    const input = "seLECt * from table;";
    const tests = [_]Token{
        .{ .token = Token.TokenType.select, .start_pos = .{ .line = 1, .column = 1 }, .end_pos = .{ .line = 1, .column = 6 } },
        .{ .token = Token.TokenType.asterisk, .start_pos = .{ .line = 1, .column = 8 }, .end_pos = .{ .line = 1, .column = 8 } },
        .{ .token = Token.TokenType.from, .start_pos = .{ .line = 1, .column = 10 }, .end_pos = .{ .line = 1, .column = 13 } },
        .{ .token = Token.TokenType{ .identifier = "table" }, .start_pos = .{ .line = 1, .column = 15 }, .end_pos = .{ .line = 1, .column = 19 } },
        .{ .token = Token.TokenType.semicolon, .start_pos = .{ .line = 1, .column = 20 }, .end_pos = .{ .line = 1, .column = 20 } },
    };

    var lexer = Self.new(input);

    for (0..tests.len) |i| {
        const tok = lexer.next_token();
        const test_token = tests[i];

        try expectEqualDeep(test_token, tok);
    }
}
