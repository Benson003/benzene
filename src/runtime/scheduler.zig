const std = @import("std");
const Scheduler = @This();

allocator: std.mem.Allocator,
current_fiber: ?*Fiber,
ready_queue: FiberQueue,
waiting_queue: FiberQueue,
completed_queue: FiberQueue,
next_id: u64,
main_fiber: *Fiber,

const State = enum {
    Ready,
    Waiting,
    Running,
    Completed,
};

const Context = struct {
    rsp: usize, //Offset 0
    rip: usize, //Offset 8
    rbx: usize, //Offset 16
    rbp: usize, //Offset 24
    r12: usize, //Offset 32
    r13: usize, //Offset 40
    r14: usize, //Offset 48
    r15: usize, //Offset 56
    rdi: usize, // Offset 64
};

comptime {
    if (@offsetOf(Context, "rsp") != 0) @compileError("rsp offset wrong");
    if (@offsetOf(Context, "rip") != 8) @compileError("rip offset wrong");
    if (@offsetOf(Context, "rbx") != 16) @compileError("rbx offset wrong");
    if (@offsetOf(Context, "rbp") != 24) @compileError("rbp offset wrong");
    if (@offsetOf(Context, "r12") != 32) @compileError("r12 offset wrong");
    if (@offsetOf(Context, "r13") != 40) @compileError("r13 offset wrong");
    if (@offsetOf(Context, "r14") != 48) @compileError("r14 offset wrong");
    if (@offsetOf(Context, "r15") != 56) @compileError("r15 offset wrong");
    if (@offsetOf(Context, "rdi") != 64) @compileError("rdi offset wrong");
}

const Fiber = struct {
    id: usize,
    stack: []u8,
    context: Context,
    state: State,
    next: ?*Fiber,
    entry_fn: ?*const fn (*Scheduler) void,
};

const FiberError = error{
    FailedToAllocateStack,
    FailedToAllocateFiber,
};

const FiberQueueError = error{
    NoFiberInQueue,
};

const SchedulerError = error{
    FailedToInitaliseScheduler,
    FailedToAllocateStackForFiber,
    FailedToAllocateFiber,
};

const FiberQueue = struct {
    head: ?*Fiber,
    tail: ?*Fiber,

    fn push(self: *FiberQueue, fiber: *Fiber) void {
        if (self.tail) |tail| {
            tail.next = fiber;
        } else {
            self.head = fiber;
        }
        self.tail = fiber;
    }

    fn peek(self: *FiberQueue) ?*Fiber {
        return self.head;
    }

    fn isEmpty(self: *FiberQueue) bool {
        return self.head == null;
    }

    fn pop(self: *FiberQueue) FiberQueueError!*Fiber {
        if (self.head) |head| {
            self.head = head.next;
            if (self.head == null) {
                self.tail = null;
            }
            head.next = null;
            return head;
        }
        return FiberQueueError.NoFiberInQueue;
    }

    fn deinit(self: *FiberQueue, scheduler: *Scheduler) void {
        while (true) {
            const result = self.pop() catch |err| {
                switch (err) {
                    FiberQueueError.NoFiberInQueue => return,
                }
            };
            scheduler.destroy_fiber(result);
        }
        self.head = null;
        self.tail = null;
    }
};

pub fn init(allocator: std.mem.Allocator) SchedulerError!Scheduler {
    const main_fiber = allocator.create(Fiber) catch return SchedulerError.FailedToInitaliseScheduler;
    errdefer allocator.destroy(main_fiber);
    main_fiber.* = Fiber{
        .context = undefined,
        .entry_fn = null,
        .id = 1,
        .next = null,
        .stack = &.{},
        .state = .Running,
    };

    return Scheduler{
        .allocator = allocator,
        .current_fiber = main_fiber,
        .main_fiber = main_fiber,
        .ready_queue = FiberQueue{ .head = null, .tail = null },
        .waiting_queue = FiberQueue{ .head = null, .tail = null },
        .completed_queue = FiberQueue{ .head = null, .tail = null },
        .next_id = 2,
    };
}

pub fn deinit(self: *Scheduler) void {
    self.completed_queue.deinit(self);
    self.ready_queue.deinit(self);
    self.waiting_queue.deinit(self);
    self.allocator.destroy(self.main_fiber);
}

pub fn spawn(self: *Scheduler, func: *const fn (*Scheduler) void) SchedulerError!*Fiber {
    const fiber = self.create_fiber(func) catch |err| {
        switch (err) {
            FiberError.FailedToAllocateFiber => return SchedulerError.FailedToAllocateFiber,
            FiberError.FailedToAllocateStack => return SchedulerError.FailedToAllocateStackForFiber,
        }
    };

    errdefer self.destroy_fiber(fiber);
    self.ready_queue.push(fiber);
    return fiber;
}

pub fn run(self: *Scheduler) void {
    while (true) {
        const fiber = self.ready_queue.pop() catch return;

        self.current_fiber = fiber;
        switch_context(&self.main_fiber.context, &fiber.context);
        self.current_fiber = null;
        self.cleanupCompleted();
    }
}

pub fn yield(self: *Scheduler) void {
    self.ready_queue.push(self.current_fiber.?);
    switch_context(&self.current_fiber.?.context, &self.main_fiber.context);
}

fn cleanupCompleted(self: *Scheduler) void {
    while (true) {
        const completed_fiber = self.completed_queue.pop() catch |err| {
            switch (err) {
                FiberQueueError.NoFiberInQueue => break,
            }
        };
        self.destroy_fiber(completed_fiber);
    }
}

extern fn switch_context(from: *Context, to: *Context) callconv(.c) void;

fn fiber_trampoline(self: *Scheduler) callconv(.c) noreturn {
    const fiber = self.current_fiber.?;
    fiber.state = .Running;
    fiber.entry_fn.?(self);
    fiber.state = .Completed;
    self.fiber_exit();
    unreachable;
}

fn fiber_exit(self: *Scheduler) noreturn {
    self.completed_queue.push(self.current_fiber.?);
    switch_context(&self.current_fiber.?.context, &self.main_fiber.context);
    unreachable;
}

fn create_fiber(self: *Scheduler, func: *const fn (*Scheduler) void) FiberError!*Fiber {
    const stack_bytes: []u8 = self.allocator.alloc(u8, 64 * 1024) catch return FiberError.FailedToAllocateStack;
    const fiber = self.allocator.create(Fiber) catch return FiberError.FailedToAllocateFiber;

    const stack_base = @intFromPtr(stack_bytes.ptr);
    var initial_rsp = stack_base + stack_bytes.len;
    initial_rsp = (initial_rsp & ~@as(usize, 15)) - 8; // This is to aling the stack pleas this is important for the calling convention

    errdefer {
        self.allocator.free(stack_bytes);
        self.allocator.destroy(fiber);
    }

    fiber.* = Fiber{
        .state = .Ready,
        .stack = stack_bytes,
        .id = self.next_id,
        .entry_fn = func,
        .next = null,
        .context = Context{
            .rsp = initial_rsp,
            .rip = @intFromPtr(&fiber_trampoline),
            .r12 = 0,
            .r13 = 0,
            .r14 = 0,
            .r15 = 0,
            .rbx = 0,
            .rbp = 0,
            .rdi = @intFromPtr(self),
        },
    };

    self.next_id += 1;

    return fiber;
}

fn destroy_fiber(self: *Scheduler, fiber: *Fiber) void {
    self.allocator.free(fiber.stack);
    self.allocator.destroy(fiber);
}
