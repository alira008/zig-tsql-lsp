const std = @import("std");
const token = @import("token.zig");
const lexer = @import("lexer.zig");

pub fn main() !void {
    std.log.info("Hello, world!", .{});
    const input = "=+(){},#";
    const tests = [_]token.Token{
        token.Token.equal,
        token.Token.plus,
        token.Token.left_paren,
        token.Token.right_paren,
        token.Token.comma,
        token.Token.sharp,
    };

    var l = lexer.Lexer.new(input);

    var current_line: u64 = 0;
    var current_col: u64 = 0;
    for (0..tests.len) |i| {
        const tok = l.next_token();
        // if (tok == token.Token.new_line) {
        //     current_line += 1;
        //     current_col = 0;
        // }
        var location = token.Location{ .col = current_col, .line = current_line };
        var token_with_location = token.TokenWithLocation{ .token = tok, .location = location };
        _ = token_with_location;
        const test_token = tests[i];
        _ = test_token;

        current_col += 1;
        std.log.debug("Current column: {}", .{current_col});
    }
}
