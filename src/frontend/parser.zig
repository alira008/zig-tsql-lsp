const lex = @import("lexer.zig");
const tok = @import("token.zig");
const std = @import("std");

pub const Parser = struct {
    allocator: std.mem.Allocator,
    lexer: lex.Lexer,
    peekToken: tok.Token,

    // pub fn init(allocator: std.mem.Allocator, lexer: lex.Lexer) void {
    //     var parser = Parser{.lexer = lexer}
    // }
};
