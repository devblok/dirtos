const scheduling = @import("sched.zig");
const arch = @import("arch/base.zig");
const riscv = @import("arch/riscv.zig");

const std = @import("std");
const Allocator = std.mem.Allocator;
const FixedBufferAllocator = std.heap.FixedBufferAllocator;

const global = struct {
    var fast_buffer: [256]u8 linksection(".fast") = undefined;
    var allocator: FixedBufferAllocator linksection(".fast") = undefined;
    var scheduler: scheduling.Scheduler linksection(".fast") = undefined;
};

pub fn initialize(comptime tasks: []scheduling.Entry) !*scheduling.Scheduler {
    arch.init();
    riscv.disablePLIC();
    // arch.enableInterrupts();
    arch.plicIrqMask(0);

    global.allocator = FixedBufferAllocator.init(&global.fast_buffer);
    global.scheduler = try scheduling.Scheduler.init(&global.allocator.allocator(), tasks);

    return &global.scheduler;
}
