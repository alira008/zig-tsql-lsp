pub const query = @import("query.zig");
pub const expression = @import("expression.zig");
pub const Span = struct {
    line: usize,
    column: usize,

    pub fn init(line: usize, column: usize) Span {
        return .{ .line = line, .column = column };
    }
};
