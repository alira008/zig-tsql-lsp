const std = @import("std");
const query = @import("./query.zig");

pub const Operators = enum {
    Case,
    CaseItem,
};

pub const Expression = union(enum) {
    number_literal: f64,
    string_literal: []u8,
    quote_identifier: []u8,
    bool_literal: bool,
    identifier: []u8,
    local_variable_identifier: []u8,
    expr_list: std.ArrayList(*Expression),
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
