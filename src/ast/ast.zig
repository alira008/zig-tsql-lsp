const std = @import("std");
const token = @import("../token.zig");
const query = @import("./query.zig");

pub const Sql = struct {
    statements: []Statement,
};

pub const Statement = union(enum) {
    select: query.SelectStatement,
};

pub const Operators = enum {
    Case,
    CaseItem,
};

pub const Expression = union(enum) {
    expr_list: []*Expression,
    number_literal: f64,
    string_literal: []const u8,
    quote_identifier: []const u8,
    bool_literal: bool,
    identifier: []const u8,
    binary_expression: struct {
        left: *Expression,
        right: *Expression,
        op: BinaryOperator,
    },
    unary_expression: struct {
        expr: *Expression,
        op: UnaryOperator,
    },
};

pub const UnaryOperator = enum {
    Not,
    UnaryMinus,
    IsTrue,
    IsNotTrue,
    IsNull,
    IsNotNull,
    Exists,
};

pub const BinaryOperator = enum {
    Plus,
    Minus,
    Mult,
    Div,
    Mod,
    Equal,
    Greater,
    GreaterEqual,
    Less,
    LessEqual,
    And,
    Or,
    Like,
    In,
    Between,
    Any,
    All,
    Some,
};
