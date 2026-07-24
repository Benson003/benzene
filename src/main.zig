const std = @import("std");
const Scheduler = @import("runtime/scheduler.zig");

pub fn main() !void {
    var debug_allocator = std.heap.DebugAllocator(.{}){};
    defer _ = debug_allocator.deinit();
    const allocator = debug_allocator.allocator();

    var scheduler = try Scheduler.init(allocator);
    defer scheduler.deinit();
    _ = try scheduler.spawn(a);
    _ = try scheduler.spawn(b);
    scheduler.run();
}
fn a() void {
    std.debug.print("A1\n", .{});
    std.debug.print("A2\n", .{});
}

fn b() void {
    std.debug.print("B1\n", .{});
    std.debug.print("B2\n", .{});
}
