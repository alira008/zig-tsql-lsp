const std = @import("std");
const query = @import("query.zig");
const Span = @import("ast.zig").Span;

pub const Operators = enum {
    Case,
    CaseItem,
};

pub const Expression = union(enum) {
    number_literal: struct {
        value: f64,
        start: Span = undefined,
        end: Span = undefined,
    },
    string_literal: struct {
        value: []u8,
        start: Span = undefined,
        end: Span = undefined,
    },
    quote_identifier: struct {
        value: []u8,
        start: Span = undefined,
        end: Span = undefined,
    },
    bool_literal: struct {
        value: bool,
        start: Span = undefined,
        end: Span = undefined,
    },
    identifier: struct {
        value: []u8,
        start: Span = undefined,
        end: Span = undefined,
    },
    local_variable_identifier: struct {
        value: []u8,
        start: Span = undefined,
        end: Span = undefined,
    },
    expr_list: struct {
        expressions: []*Expression,
        start: Span = undefined,
        end: Span = undefined,
    },
    binary_expression: struct {
        start: Span = undefined,
        end: Span = undefined,
        left: *Expression,
        right: *Expression,
        op: BinaryOperator,
    },
    unary_expression: struct {
        start: Span = undefined,
        end: Span = undefined,
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
