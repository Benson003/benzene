const std = @import("std");

pub const SourceFile = struct {
    path: []const u8,
    source: []const u8,
    linemap: []u32,
};

pub const Span = struct {
    lo: u32,
    hi: u32,
    pub fn to(self: *const Span, span: Span) Span {
        const high = if (self.hi >= span.hi) self.hi else span.hi;
        const low = if (self.lo <= span.lo) self.lo else span.lo;
        return Span{
            .hi = high,
            .lo = low,
        };
    }
};

test "span test normal" {
    const span1 = Span{ .lo = 0, .hi = 1 };
    const span2 = Span{ .lo = 2, .hi = 3 };
    const span3 = span1.to(span2);
    try std.testing.expectEqual(0, span3.lo);
    try std.testing.expectEqual(3, span3.hi);
}

test "span test fisrt span encompass second" {
    const span1 = Span{ .lo = 0, .hi = 4 };
    const span2 = Span{ .lo = 1, .hi = 2 };
    const span3 = span1.to(span2);
    try std.testing.expectEqual(0, span3.lo);
    try std.testing.expectEqual(4, span3.hi);
}

test "span test second span encompass first" {
    const span1 = Span{ .lo = 2, .hi = 4 };
    const span2 = Span{ .lo = 1, .hi = 5 };
    const span3 = span1.to(span2);
    try std.testing.expectEqual(1, span3.lo);
    try std.testing.expectEqual(5, span3.hi);
}

test "span test spans disjointed" {
    const span1 = Span{ .lo = 0, .hi = 3 };
    const span2 = Span{ .lo = 5, .hi = 7 };
    const span3 = span1.to(span2);
    try std.testing.expectEqual(0, span3.lo);
    try std.testing.expectEqual(7, span3.hi);
}

test "span test order reversed" {
    const span1 = Span{ .lo = 5, .hi = 8 };
    const span2 = Span{ .lo = 1, .hi = 2 };
    const span3 = span1.to(span2);
    try std.testing.expectEqual(1, span3.lo);
    try std.testing.expectEqual(8, span3.hi);
}
