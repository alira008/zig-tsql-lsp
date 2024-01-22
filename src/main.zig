const std = @import("std");
const lexer = @import("lexer.zig");
const parser = @import("parser.zig");

pub fn main() !void {
    const input = "select distinct hello.*, [hello] as tester from users";

    var l = lexer.Lexer.new(input);
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer std.debug.assert(gpa.deinit() == .ok);
    var sql_parser = parser.Parser.init(allocator, l);
    try sql_parser.parse();
}
