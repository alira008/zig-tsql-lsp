const std = @import("std");
const Token = @import("token.zig");
const TokenType = Token.TokenType;
const expectEqualDeep = std.testing.expectEqualDeep;

pub const LexerError = error{OutOfMemory};

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

fn read_comment(self: *Self) []const u8 {
    // skip -
    self.read_char();
    // check the first position that isn't a space
    var position = self.position;
    var last_position = self.position;
    var start_found = false;
    while (self.peek_char() != '\n' and self.peek_char() != 0) {
        self.read_char();
        if (!std.ascii.isWhitespace(self.char) and !start_found) {
            start_found = true;
            position = self.position;
        }
        if (!std.ascii.isWhitespace(self.char)) {
            last_position = self.position;
        }
    }

    return self.input[position .. last_position + 1];
}

fn skip_whitespace(self: *Self) void {
    while (std.ascii.isWhitespace(self.char)) {
        self.read_char();
    }
}

pub fn next_token(self: *Self) Token {
    self.skip_whitespace();

    const start_pos = Token.Position.init(self.line, self.column);
    const tok: TokenType = switch (self.char) {
        '#' => .sharp,
        '.' => .period,
        ';' => .semicolon,
        '(' => .left_paren,
        ')' => .right_paren,
        '+' => .plus,
        '-' => blk: {
            if (self.peek_char() == '-') {
                self.read_char();
                const comment = self.read_comment();
                break :blk .{ .comment = comment };
            } else {
                break :blk .minus;
            }
        },
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
        ',' => .comma,
        '<' => blk: {
            if (self.peek_char() == '=') {
                break :blk .less_than_equal;
            } else if (self.peek_char() == '>') {
                break :blk .not_equal_arrow;
            } else {
                break :blk .less_than;
            }
        },
        '>' => blk: {
            if (self.peek_char() == '=') {
                break :blk .greater_than_equal;
            } else {
                break :blk .greater_than;
            }
        },
        '=' => .equal,
        '*' => .asterisk,
        '/' => .forward_slash,
        '%' => .percent,
        '!' => blk: {
            if (self.peek_char() == '=') {
                break :blk .not_equal_bang;
            } else {
                break :blk .illegal;
            }
        },
        'a'...'z', 'A'...'Z', '_' => blk: {
            const ident = self.read_identifier();
            if (Token.keyword(ident)) |tok| {
                break :blk tok;
            }
            break :blk .{ .identifier = ident };
        },
        '0'...'9' => blk: {
            const num_str = self.read_number();

            const number = std.fmt.parseFloat(f64, num_str) catch return .{
                .token = .illegal,
                .start_pos = start_pos,
                .end_pos = Token.Position.init(self.line, self.column),
            };
            break :blk .{ .number = number };
        },
        0 => .eof,
        else => .illegal,
    };

    const end_pos = Token.Position.init(self.line, self.column);
    self.read_char();

    return .{ .token = tok, .start_pos = start_pos, .end_pos = end_pos };
}

test "basic select test" {
    const input = "seLECt * from table; -- yessir ";
    const tests = [_]Token{
        .{
            .token = .select,
            .start_pos = .{ .line = 1, .column = 1 },
            .end_pos = .{ .line = 1, .column = 6 },
        },
        .{
            .token = .asterisk,
            .start_pos = .{ .line = 1, .column = 8 },
            .end_pos = .{ .line = 1, .column = 8 },
        },
        .{
            .token = .from,
            .start_pos = .{ .line = 1, .column = 10 },
            .end_pos = .{ .line = 1, .column = 13 },
        },
        .{
            .token = .{ .identifier = "table" },
            .start_pos = .{ .line = 1, .column = 15 },
            .end_pos = .{ .line = 1, .column = 19 },
        },
        .{
            .token = .semicolon,
            .start_pos = .{ .line = 1, .column = 20 },
            .end_pos = .{ .line = 1, .column = 20 },
        },
        .{
            .token = .{ .comment = "yessir" },
            .start_pos = .{ .line = 1, .column = 22 },
            .end_pos = .{ .line = 1, .column = 31 },
        },
    };

    var lexer = Self.new(input);

    for (0..tests.len) |i| {
        const tok = lexer.next_token();
        const test_token = tests[i];

        try expectEqualDeep(test_token, tok);
    }
}
