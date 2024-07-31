const std = @import("std");
const Lexer = @import("lexer");
const TokenKind = Lexer.TokenKind;
const TokenType = Lexer.TokenType;

pub const OperatorPrecedence = enum(u4) {
    lowest,
    assignment,
    other_logicals,
    and_,
    not,
    comparison,
    sum,
    product,
    highest,
};

const OperatorPrecendenceMap = std.StaticStringMap(OperatorPrecedence).initComptime(.{
    .{ "tilde", .highest },
    .{ "asterisk", .product },
    .{ "forward_slash", .product },
    .{ "plus", .sum },
    .{ "minus", .sum },
    .{ "equal", .comparison },
    .{ "not_equal_bang", .comparison },
    .{ "not_equal_arrow", .comparison },
    .{ "less_than", .comparison },
    .{ "greater_than", .comparison },
    .{ "less_than_equal", .comparison },
    .{ "greater_than_equal", .comparison },
    .{ "not", .not },
    .{ "and", .and_ },
    .{ "all", .other_logicals },
    .{ "any", .other_logicals },
    .{ "between", .other_logicals },
    .{ "in", .other_logicals },
    .{ "like", .other_logicals },
    .{ "or", .other_logicals },
    .{ "some", .other_logicals },
});

pub fn getPrecedence(token_type: TokenType) OperatorPrecedence {
    return OperatorPrecendenceMap.get(token_type.toString()) orelse .lowest;
}
