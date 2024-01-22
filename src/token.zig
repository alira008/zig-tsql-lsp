const std = @import("std");

pub const TokenKind = enum {
    identifier,
    integer,
    float,
    quoted_literal,

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
    exec,
    select,
    distinct,
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
};

pub const Token = union(TokenKind) {
    identifier: []const u8,
    integer: i64,
    float: f64,
    quoted_literal: struct { value: []const u8, quote_char: u8 },

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
    exec,
    select,
    distinct,
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

    // keyword types

    pub fn keyword(ident: []const u8) ?Token {
        const map = std.ComptimeStringMap(Token, .{
            .{ "exec", .exec },
            .{ "select", .select },
            .{ "distinct", .distinct },
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
        });

        return map.get(ident);
    }
};

pub const Location = struct { line: u64, column: u64 };

pub const TokenWithLocation = struct {
    token: Token,
    location: Location,
};
