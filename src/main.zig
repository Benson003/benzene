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
fn a(s: *Scheduler) void {
    std.debug.print("A1\n", .{});
    s.yield();
    std.debug.print("A2\n", .{});
    s.yield();
    std.debug.print("A3\n", .{});
}

fn b(s: *Scheduler) void {
    std.debug.print("B1\n", .{});
    s.yield();
    std.debug.print("B2\n", .{});
    s.yield();
    std.debug.print("B3\n", .{});
}
