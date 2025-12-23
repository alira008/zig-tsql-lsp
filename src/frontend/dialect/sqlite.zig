const std = @import("std");
const token = @import("../token.zig");

pub const sqlite_keywords = std.StaticStringMap(token.Tag).initComptime(.{
    .{ "blob", .kw_blob },
    .{ "integer", .kw_integer },
    .{ "text", .kw_text },
    .{ "datetime", .kw_datetime },
    .{ "replace", .kw_replace },
    .{ "conflict", .kw_conflict },
    .{ "abort", .kw_abort },
    .{ "fail", .kw_fail },
    .{ "ignore", .kw_ignore },
    .{ "restrict", .kw_restrict },
    .{ "without", .kw_without },
});
