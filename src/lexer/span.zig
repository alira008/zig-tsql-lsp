line: usize,
column: usize,

const Self = @This();

pub fn init(line: usize, column: usize) Self {
    return .{ .line = line, .column = column };
}
