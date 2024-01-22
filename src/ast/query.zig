const std = @import("std");
const token = @import("../token.zig");

pub const Statement = union(enum) { select: SelectStatement };

pub const SelectStatement = struct { distinct: bool = false, columns: std.ArrayList(Expression) = undefined };

pub const SelectItem = union(enum) { wildcard, unnamed, with_alias, wildcard_with_alias };

pub const Expression = union(enum) { literal: token.TokenWithLocation, compound_literal: std.ArrayList(token.TokenWithLocation), binary: struct { left: *Expression, operator: token.TokenWithLocation, right: *Expression }, unary, function_call };
