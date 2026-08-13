const std = @import("std");

pub const SourceFile = struct {
    path: []const u8,
    source: []const u8,
    linemap: []u32,
};

pub const Span = struct {
    start: u32,
    end: u32,
    pub fn to(self: *const Span, span: Span) Span {
        const start = if (self.start <= span.start) self.start else span.start;
        const end = if (self.end >= span.end) self.end else span.end;
        return Span{
            .start = start,
            .end = end,
        };
    }
};

test "span test normal" {
    const span1 = Span{ .start = 0, .end = 1 };
    const span2 = Span{ .start = 2, .end = 3 };
    const span3 = span1.to(span2);
    try std.testing.expectEqual(0, span3.start);
    try std.testing.expectEqual(3, span3.end);
}

test "span test fisrt span encompass second" {
    const span1 = Span{ .start = 0, .end = 4 };
    const span2 = Span{ .start = 1, .end = 2 };
    const span3 = span1.to(span2);
    try std.testing.expectEqual(0, span3.start);
    try std.testing.expectEqual(4, span3.end);
}

test "span test second span encompass first" {
    const span1 = Span{ .start = 2, .end = 4 };
    const span2 = Span{ .start = 1, .end = 5 };
    const span3 = span1.to(span2);
    try std.testing.expectEqual(1, span3.start);
    try std.testing.expectEqual(5, span3.end);
}

test "span test spans disjointed" {
    const span1 = Span{ .start = 0, .end = 3 };
    const span2 = Span{ .start = 5, .end = 7 };
    const span3 = span1.to(span2);
    try std.testing.expectEqual(0, span3.start);
    try std.testing.expectEqual(7, span3.end);
}

test "span test order reversed" {
    const span1 = Span{ .start = 5, .end = 8 };
    const span2 = Span{ .start = 1, .end = 2 };
    const span3 = span1.to(span2);
    try std.testing.expectEqual(1, span3.start);
    try std.testing.expectEqual(8, span3.end);
}
