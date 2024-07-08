const std = @import("std");

token: TokenType,
start_pos: Position,
end_pos: Position,

pub const TokenKind = enum {
    identifier,
    quoted_identifier,
    local_variable,
    string_literal,
    number,

    illegal,
    eof,

    sharp,
    tilde,
    period,
    semicolon,
    left_bracket,
    right_bracket,
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
    not_equal,
    asterisk,

    // Keywords
    with,
    exec,
    select,
    distinct,
    top,
    from,
    where,
    insert,
    update,
    delete,
    create,
    alter,
    drop,
    declare,
    set,
    cast,
    as,
    asc,
    desc,

    const Self = @This();

    pub fn toString(self: Self) []const u8 {
        return switch (self) {
            .identifier => "identifier",
            .quoted_identifier => "quoted_identifier",
            .local_variable => "local_variable",
            .string_literal => "string_literal",
            .number => "number",
            .illegal => "illegal",
            .eof => "eof",
            .sharp => "sharp",
            .tilde => "tilde",
            .period => "period",
            .semicolon => "semicolon",
            .left_bracket => "left_bracket",
            .right_bracket => "right_bracket",
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
            .not_equal => "not_equal",
            .asterisk => "asterisk",
            .with => "with",
            .exec => "exec",
            .select => "select",
            .distinct => "distinct",
            .top => "top",
            .from => "from",
            .where => "where",
            .insert => "insert",
            .update => "update",
            .delete => "delete",
            .create => "create",
            .alter => "alter",
            .drop => "drop",
            .declare => "declare",
            .set => "set",
            .cast => "cast",
            .as => "as",
            .asc => "asc",
            .desc => "desc",
        };
    }
};

pub const TokenType = union(TokenKind) {
    identifier: []u8,
    quoted_identifier: []u8,
    local_variable: []u8,
    string_literal: []u8,
    number: f64,

    illegal,
    eof,

    sharp,
    tilde,
    period,
    semicolon,
    left_bracket,
    right_bracket,
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
    not_equal,
    asterisk,

    // Keywords
    with,
    exec,
    select,
    distinct,
    top,
    from,
    where,
    insert,
    update,
    delete,
    create,
    alter,
    drop,
    declare,
    set,
    cast,
    as,
    asc,
    desc,

    // keyword types
    const map = std.StaticStringMap(TokenType).initComptime(.{
        .{ "with", .with },
        .{ "exec", .exec },
        .{ "select", .select },
        .{ "distinct", .distinct },
        .{ "top", .top },
        .{ "from", .from },
        .{ "where", .where },
        .{ "insert", .insert },
        .{ "update", .update },
        .{ "delete", .delete },
        .{ "create", .create },
        .{ "alter", .alter },
        .{ "drop", .drop },
        .{ "declare", .declare },
        .{ "set", .set },
        .{ "cast", .cast },
        .{ "as", .as },
        .{ "asc", .asc },
        .{ "desc", .desc },
    });

    pub fn keyword(ident: []const u8) ?TokenType {
        var buf = [_]u8{0} ** 20;
        if (ident.len >= buf.len) {
            return null;
        }
        const lower_ident = std.ascii.lowerString(&buf, ident);

        return map.get(lower_ident);
    }

    pub fn toString(self: TokenType) []const u8 {
        return switch (self) {
            .identifier => "identifier",
            .quoted_identifier => "quoted_identifier",
            .local_variable => "local_variable",
            .string_literal => "string_literal",
            .number => "number",
            .illegal => "illegal",
            .eof => "eof",
            .sharp => "sharp",
            .tilde => "tilde",
            .period => "period",
            .semicolon => "semicolon",
            .left_bracket => "left_bracket",
            .right_bracket => "right_bracket",
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
            .not_equal => "not_equal",
            .asterisk => "asterisk",
            .with => "with",
            .exec => "exec",
            .select => "select",
            .distinct => "distinct",
            .top => "top",
            .from => "from",
            .where => "where",
            .insert => "insert",
            .update => "update",
            .delete => "delete",
            .create => "create",
            .alter => "alter",
            .drop => "drop",
            .declare => "declare",
            .set => "set",
            .cast => "cast",
            .as => "as",
            .asc => "asc",
            .desc => "desc",
        };
    }
};

pub const Position = struct {
    line: usize,
    column: usize,

    pub fn init(line: usize, column: usize) Position {
        return .{ .line = line, .column = column };
    }
};
