const std = @import("std");
const token = @import("../token.zig");

pub const sqlserver_keywords = std.StaticStringMap(token.Tag).initComptime(.{
    .{ "exec", .kw_exec },
    .{ "top", .kw_top },
    .{ "declare", .kw_declare },
    .{ "set", .kw_set },
    .{ "percent", .kw_percent },
    .{ "ties", .kw_ties },
    .{ "bit", .kw_bit },
    .{ "datetime", .kw_datetime },
});
