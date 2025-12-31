const dialect = @import("dialect.zig");
pub const Span = @import("token.zig").Span;

pub const Comment = struct { value: []const u8, span: Span };

pub const Keyword = struct {
    tag: dialect.Keyword,
    span: Span,
};

pub const Query = struct { statements: []*Statement, span: Span };
pub const Statement = union(enum) {
    select: *SelectStatement,
    pub fn span(statement: Statement) Span {
        return switch (statement) {
            inline else => |s| s.span,
        };
    }
};

pub const SelectStatement = struct {
    select_kw: Keyword,
    distinct: ?Keyword = null,
    all: ?Keyword = null,
    select_list: SelectList,
    from: ?FromClause = null,
    span: Span,
};

pub const SelectList = struct { items: []*Expression, span: Span };
pub const FromClause = struct { from_kw: Keyword, table: *Expression, span: Span };

pub const Literal = union(enum) {
    number: NumberLiteral,
    string: StringLiteral,
    bool: BoolLiteral,

    pub const StringLiteral = struct { value: []const u8, span: Span };
    pub const NumberLiteral = struct { value: []const u8, span: Span };
    pub const BoolLiteral = struct { value: bool, span: Span };

    pub fn span(literal: Literal) Span {
        return switch (literal) {
            inline else => |lit| lit.span,
        };
    }
};

pub const Identifier = union(enum) {
    normal: Normal,
    quoted: Quoted,
    localVariable: LocalVariable,

    pub const Normal = struct { value: []const u8, span: Span };
    pub const Quoted = struct { value: []const u8, span: Span };
    pub const LocalVariable = struct { value: []const u8, span: Span };

    pub fn span(identifier: Identifier) Span {
        return switch (identifier) {
            inline else => |ident| ident.span,
        };
    }
};

pub const Expression = union(enum) {
    literal: Literal,
    identifier: Identifier,
    binary_expr: BinaryExpression,
    unary_expr: UnaryExpression,

    pub const BinaryExpression = struct {
        left: *Expression,
        right: *Expression,
        op: BinaryOperator,
        span: Span,
    };
    pub const UnaryExpression = struct { expr: *Expression, op: UnaryOperator, span: Span };

    pub fn span(expression: Expression) Span {
        return switch (expression) {
            .literal => |lit| lit.span(),
            .identifier => |ident| ident.span(),
            inline else => |expr| expr.span,
        };
    }
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
