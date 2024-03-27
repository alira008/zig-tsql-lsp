const std = @import("std");

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
};

pub const Token = union(TokenKind) {
    identifier: []const u8,
    quoted_identifier: []const u8,
    local_variable: []const u8,
    string_literal: []const u8,
    number: f64,

    illegal,
    eof,

    sharp,
    tilde,
    period,
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

    pub fn keyword(ident: []const u8) ?Token {
        var buf = [_]u8{0} ** 20;
        if (ident.len >= buf.len) {
            return null;
        }
        const lower_ident = std.ascii.lowerString(&buf, ident);
        const map = std.ComptimeStringMap(Token, .{
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

        return map.get(lower_ident);
    }

    pub fn to_string(self: Token) []const u8 {
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

pub const Location = struct { line: u64, column: u64 };

pub const TokenWithLocation = struct {
    token: Token,
    location: Location,
};
