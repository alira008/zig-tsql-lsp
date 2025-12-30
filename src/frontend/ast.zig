const dialect = @import("dialect.zig");
pub const Span = @import("token.zig").Span;

pub const Keyword = struct {
    tag: dialect.Keyword,
    span: Span,
};
