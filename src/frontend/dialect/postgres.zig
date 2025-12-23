const std = @import("std");
const token = @import("../token.zig");

pub const postgres_keywords = std.StaticStringMap(token.Tag).initComptime(.{
    .{ "returning", .kw_returning },
    .{ "lateral", .kw_lateral },
    .{ "recursive", .kw_recursive },
    .{ "ilike", .kw_ilike },
    .{ "similar", .kw_similar },
    .{ "text", .kw_text },
    .{ "uuid", .kw_uuid },
    .{ "json", .kw_json },
    .{ "jsonb", .kw_jsonb },
    .{ "serial", .kw_serial },
    .{ "bigserial", .kw_bigserial },
    .{ "enum", .kw_enum },
});
