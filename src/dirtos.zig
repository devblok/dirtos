const scheduling = @import("sched.zig");
const arch = @import("arch/base.zig");
const riscv = @import("arch/riscv.zig");

const std = @import("std");
const Allocator = std.mem.Allocator;
const FixedBufferAllocator = std.heap.FixedBufferAllocator;

const global = struct {
    var internal_heap: [256]u8 = undefined;
    var allocator: FixedBufferAllocator = undefined;
    var scheduler: scheduling.Scheduler = undefined;
};

pub fn initialize(comptime tasks: []scheduling.Entry) !*scheduling.Scheduler {
    arch.init();
    riscv.disablePLIC();
    // arch.enableInterrupts();
    arch.plicIrqMask(0);

    global.allocator = FixedBufferAllocator.init(&global.internal_heap);
    global.scheduler = try scheduling.Scheduler.init(&global.allocator.allocator(), tasks);

    return &global.scheduler;
}
