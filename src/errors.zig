const Token = @import("token.zig");
const std = @import("std");

pub const ParserError = error{ UnexpectedToken, InvalidToken, NotImplemented, OutOfMemory };

pub const ErrorContext = struct {
    allocator: std.mem.Allocator,
    expected_token: ?*const Token.TokenType = null,
    errors: std.ArrayList([]u8),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{ .allocator = allocator, .errors = std.ArrayList([]u8).init(allocator) };
    }

    pub fn deinit(self: Self) void {
        self.errors.deinit();
        self.expected_token = null;
    }

    pub fn addError(self: Self, line: []const u8, token: Token.TokenType, expected_token: Token.TokenType) void {
        _ = line;
        self.expected_token = expected_token;
        _ = token;
    }

    pub fn handleError(self: Self, parserError: ParserError) void {
        _ = parserError;
        self.expected_token = null;
    }
};
