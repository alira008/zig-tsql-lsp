const std = @import("std");
const Expression = @import("expression.zig").Expression;
pub const Span = struct { line: u32, col: u32 };
pub const Comment = struct { text: []u8 };
pub const KeywordKind = enum { single, multi };
pub const Keyword = union(KeywordKind) { single: Keyword, multi: []Keyword };

pub const Select = struct {
    start: Span,
    end: Span,
    distinct: bool,
    top: ?Top,
    select_items: []*Expression,
    table: ?Table,
    where: ?*Expression,
    having: ?*Expression,
    group_by: ?[]*Expression,
    order_by: ?OrderBy,

    pub const Top = struct {
        start: Span,
        end: Span,
        with_ties: bool,
        percent: bool,
        quantity: *Expression,
    };

    pub const Table = struct {
        source: TableSource,
        joins: ?[]TableJoin,
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
