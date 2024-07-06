const std = @import("std");
const Expression = @import("./expression.zig").Expression;

pub const Select = struct {
    select_items: std.ArrayList(*Expression),
    table: *Expression,
    where: ?*Expression,
};

pub const CTEType = enum { select };

pub const SelectCTE = struct { select: Select };

pub const CTE = union(CTEType) { select: SelectCTE };

pub const StatementType = enum { select, cte };

pub const Statement = union(StatementType) { select: Select, cte: CTE };
