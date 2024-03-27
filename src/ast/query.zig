const std = @import("std");
const token = @import("../token.zig");
const ast = @import("./ast.zig");

pub const SelectStatement = struct {
    common_table_expression: ?CommonTableExpression,
    body: SelectBody,
};

pub const CommonTableExpression = struct {};
pub const SelectBody = struct {
    select_items: []*ast.Expression,
    table: *ast.Expression,
    where: ?ast.Expression,
};
