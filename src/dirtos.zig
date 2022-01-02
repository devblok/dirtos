const scheduling = @import("sched.zig");
const arch = @import("arch/base.zig");
const riscv = @import("arch/riscv.zig");
const Task = @import("task.zig").Task;

const std = @import("std");
const Allocator = std.mem.Allocator;
const FixedBufferAllocator = std.heap.FixedBufferAllocator;

pub fn initialize(
    comptime num_tasks: usize,
    tasks: [num_tasks]*Task,
) *scheduling.Scheduler(tasks.len, arch.config.multicore) {
    const global = struct {
        var internal_heap: [256]u8 = undefined;
        var allocator = FixedBufferAllocator.init(&internal_heap);
        var scheduler: scheduling.Scheduler(num_tasks, arch.config.multicore) = .{};
    };

    arch.init();
    riscv.disablePLIC();
    // arch.enableInterrupts();
    arch.plicIrqMask(0);

    global.scheduler.init(tasks);
    return &global.scheduler;
}
