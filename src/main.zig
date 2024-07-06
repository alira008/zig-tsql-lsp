const std = @import("std");
const Lexer = @import("lexer.zig");
const parser = @import("parser.zig");

pub fn main() !void {
    const input = "select distinct hello.*, [hello] as tester from users";

    const heap_allocator = std.heap.page_allocator;
    var arena = std.heap.ArenaAllocator.init(heap_allocator);
    defer arena.deinit();
    const l = Lexer.new(input);
    const allocator = arena.allocator();
    var sql_parser = parser.Parser.init(allocator, l);
    try sql_parser.parse();
}
