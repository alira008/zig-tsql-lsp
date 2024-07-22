const std = @import("std");

pub const OperatorPrecedence = enum(u4) {
    lowest,
    assignment,
    other_logicals,
    and_op,
    not,
    comparison,
    sum,
    product,
    highest,
};

pub const OperatorPrecendenceMap = std.StaticStringMap(OperatorPrecedence).initComptime(.{
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
