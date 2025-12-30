const std = @import("std");
const dialect = @import("dialect.zig");

pub const Span = struct {
    start: usize,
    end: usize,

    pub const global: Span = .{ .start = 0, .end = 0 };

    pub fn fromOffsets(start: usize, end: usize) Span {
        return .{ .start = start, .end = end };
    }

    pub fn merge(a: Span, b: Span) Span {
        return .{
            .start = @min(a.start, b.start),
            .end = @max(a.end, b.end),
        };
    }

    pub fn containsOffset(self: Span, offset: usize) bool {
        return offset >= self.start and offset < self.end;
    }

    pub fn containsSpan(self: Span, other: Span) bool {
        return other.start >= self.start and other.end <= self.end;
    }

    pub fn sliceFrom(self: Span, source: []const u8) []const u8 {
        return source[self.start..self.end];
    }

    pub fn startAt(self: Span, start: usize) Span {
        return .{ .start = start, .end = self.end };
    }

    pub fn endAt(self: Span, end: usize) Span {
        return .{ .start = self.start, .end = end };
    }
};

pub const Token = struct {
    tag: Tag,
    lexeme: []const u8,
    span: Span,
};

pub const Tag = enum {
    identifier,
    quoted_identifier,
    local_variable,
    string_literal,
    number_literal,
    comment_line,

    illegal,
    eof,

    sharp,
    mod,
    period,
    semicolon,
    left_paren,
    right_paren,
    plus,
    minus,
    comma,
    less_than,
    greater_than,
    less_than_equal,
    greater_than_equal,
    equal,
    not_equal_bang,
    not_equal_arrow,
    plus_equal,
    minus_equal,
    multiply_equal,
    divide_equal,
    mod_equal,
    caret_equal,
    pipe_equal,
    pipe,
    ampersand_equal,
    ampersand,
    asterisk,
    forward_slash,
    tilde,
    double_colon, // postgres

    pub fn toString(tag: Tag) []const u8 {
        return switch (tag) {
            .identifier => "identifier",
            .quoted_identifier => "quoted_identifier",
            .local_variable => "local_variable",
            .string_literal => "string_literal",
            .number_literal => "number_literal",
            .comment_line => "comment_line",
            .illegal => "illegal",
            .eof => "eof",
            .sharp => "sharp",
            .mod => "mod",
            .period => "period",
            .semicolon => "semicolon",
            .left_paren => "left_paren",
            .right_paren => "right_paren",
            .plus => "plus",
            .minus => "minus",
            .comma => "comma",
            .less_than => "less_than",
            .greater_than => "greater_than",
            .less_than_equal => "less_than_equal",
            .greater_than_equal => "greater_than_equal",
            .equal => "equal",
            .not_equal_bang => "not_equal_bang",
            .not_equal_arrow => "not_equal_arrow",
            .plus_equal => "plus_equal",
            .minus_equal => "minus_equal",
            .multiply_equal => "multiply_equal",
            .divide_equal => "divide_equal",
            .mod_equal => "mod_equal",
            .caret_equal => "caret_equal",
            .pipe_equal => "pipe_equal",
            .pipe => "pipe",
            .ampersand_equal => "ampersand_equal",
            .ampersand => "ampersand",
            .asterisk => "asterisk",
            .forward_slash => "forward_slash",
            .tilde => "tilde",
            .double_colon => "double_colon",
        };
    }
};
