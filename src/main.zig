const std = @import("std");
const Lexer = @import("lexer.zig");
const Parser = @import("parser.zig");

pub fn main() void {
    const input = "select distinct hello.*, [hello] as tester from users";

    const heap_allocator = std.heap.page_allocator;
    var arena = std.heap.ArenaAllocator.init(heap_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const l = Lexer.new(input);
    var sql_parser = Parser.init(allocator, l);
    _ = sql_parser.parse();
}
