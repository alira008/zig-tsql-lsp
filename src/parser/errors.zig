const std = @import("std");
const Token = @import("lexer").Token;

pub const ParserError = error{ UnexpectedToken, NotImplemented, OutOfMemory };

const max_number_expected_tokens: comptime_int = 10;

pub const ErrorContext = struct {
    allocator: std.mem.Allocator,
    expected_tokens: [max_number_expected_tokens]?Token.TokenKind,
    num_expected_token: usize = 0,
    actual_token: ?*const Token = null,
    errors: std.ArrayList([]u8),
    var scratch_buf: [1024]u8 = undefined;

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        var expected_tokens: [max_number_expected_tokens]?Token.TokenKind = undefined;
        inline for (0..max_number_expected_tokens) |i| {
            expected_tokens[i] = null;
        }
        for (0..1024) |i| {
            scratch_buf[i] = 0;
        }
        return .{ .allocator = allocator, .errors = std.ArrayList([]u8).init(allocator), .expected_tokens = expected_tokens };
    }

    pub fn deinit(self: *Self) void {
        self.errors.deinit();
        self.resetExpectedTokens();
        self.actual_token = null;
    }

    inline fn resetExpectedTokens(self: *Self) void {
        inline for (0..max_number_expected_tokens) |i| {
            self.expected_tokens[i] = null;
        }
        self.num_expected_token = 0;
    }

    pub fn addUnexpectedToken(self: *Self, actual_token: *const Token, expected_token_kind: ?Token.TokenKind) ParserError {
        self.actual_token = actual_token;
        self.expected_tokens[0] = expected_token_kind;
        self.num_expected_token = 1;
        return ParserError.UnexpectedToken;
    }

    pub fn addUnexpectedTokenMany(self: *Self, actual_token: *const Token, expected_token_kinds: []const Token.TokenKind) ParserError {
        std.debug.assert(expected_token_kinds.len < max_number_expected_tokens);
        self.actual_token = actual_token;
        for (expected_token_kinds, 0..) |expected_token_kind, i| {
            self.expected_tokens[i] = expected_token_kind;
        }
        self.num_expected_token = expected_token_kinds.len;
        return ParserError.UnexpectedToken;
    }

    pub fn addNotImplementedError(self: *Self, token: *const Token) ParserError {
        self.actual_token = token;
        return ParserError.NotImplemented;
    }

    pub fn handleError(self: *Self, parserError: ParserError) void {
        std.debug.assert(self.actual_token != null);
        const actual_token = self.actual_token.?;
        switch (parserError) {
            ParserError.UnexpectedToken => {
                var scratch_buf_index: usize = 0;
                for (self.expected_tokens, 0..) |token_maybe, i| {
                    if (token_maybe == null) continue;
                    const token = token_maybe.?.toString();
                    std.mem.copyForwards(u8, scratch_buf[scratch_buf_index..], token);
                    scratch_buf_index += token.len;
                    if (i < self.num_expected_token - 1) {
                        const middleStr = " or ";
                        std.mem.copyForwards(u8, scratch_buf[scratch_buf_index..], middleStr);
                        scratch_buf_index += middleStr.len;
                    }
                }
                const error_message = std.fmt.allocPrint(self.allocator, "[error: line: {} col: {}]: expected ({s}) got ({})", .{
                    actual_token.end_pos.line,
                    actual_token.end_pos.column,
                    scratch_buf[0..scratch_buf_index],
                    @as(Token.TokenKind, actual_token.token),
                }) catch return;
                self.errors.append(error_message) catch return;
            },
            ParserError.NotImplemented => {
                const error_message = std.fmt.allocPrint(
                    self.allocator,
                    "[error: line: {} col: {}]: start of query {} not implemented",
                    .{
                        actual_token.end_pos.line,
                        actual_token.end_pos.column,
                        @as(Token.TokenKind, actual_token.token),
                    },
                ) catch return;
                self.errors.append(error_message) catch return;
            },
            else => return,
        }
        self.resetExpectedTokens();
        self.actual_token = null;
    }
};
