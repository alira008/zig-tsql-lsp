const std = @import("std");
const Span = @import("lexer").Span;
const Expression = @import("expression.zig").Expression;
pub const Comment = struct { text: []u8 };
pub const SymbolKind = enum { left_paren, right_paren };
pub const Symbol = union(SymbolKind) {
    left_paren: struct { start: Span, end: Span },
    right_paren: struct { start: Span, end: Span },
};
pub const KeywordKind = enum { single, multi };
pub const Keyword = struct { start: Span, end: Span, text: []u8 };
pub const KeywordType = union(KeywordKind) { single: Keyword, multi: []Keyword };

pub const Select = struct {
    start: Span = undefined,
    end: Span = undefined,

    select: KeywordType = undefined,
    distinct: ?KeywordType = null,
    all: ?KeywordType = null,
    top: ?Top = null,
    select_clause: SelectClause,
    table: ?Table = null,
    // where: ?*Expression,
    // having: ?*Expression,
    // group_by: ?[]*Expression,
    // order_by: ?OrderBy,
    pub const SelectClause = struct {
        start: Span = undefined,
        end: Span = undefined,

        items: []*Expression,
    };

    pub const Top = struct {
        start: Span = undefined,
        end: Span = undefined,

        top: KeywordType = undefined,
        with_ties: ?KeywordType = null,
        percent: ?KeywordType = null,
        quantity: *Expression = undefined,
    };

    pub const Table = struct {
        source: TableSource = undefined,
        joins: ?[]TableJoin = undefined,
    };

    pub const TableSourceType = enum { table, derived, table_valued_function };
    pub const TableSource = struct {
        type: TableSourceType,
        source: *Expression,
    };

    pub const TableJoinType = enum { inner, left, right, left_outer, right_outer, full, full_outer };
    pub const TableJoin = struct {
        type: TableJoinType,
        table: TableSource,
        condition: *Expression,
    };

    pub const OrderByType = enum { asc, desc };
    pub const OrderBy = struct {
        args: []OrderByArg,
    };

    pub const OrderByArg = struct {
        column: *Expression,
        type: ?OrderByType,
    };

    pub const OffsetFetch = struct {
        offset: Offset,
        fetch: ?Fetch,
    };

    pub const RowOrRows = enum { row, rows };
    pub const Offset = struct {
        value: *Expression,
        row_or_rows: RowOrRows,
    };

    pub const FirstOrNext = enum { first, next };
    pub const Fetch = struct {
        value: *Expression,
        first_or_next: FirstOrNext,
        row_or_rows: RowOrRows,
    };
};

pub const CTEType = enum { select };

pub const SelectCTE = struct { select: Select };

pub const CTE = union(CTEType) { select: SelectCTE };

pub const StatementType = enum { select, cte };

pub const Statement = union(StatementType) { select: Select, cte: CTE };
