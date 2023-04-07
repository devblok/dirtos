const std = @import("std");
const Allocator = std.mem.Allocator;
const FixedBufferAllocator = std.heap.FixedBufferAllocator;

const kernel = @import("kernel.zig");
const Pin = @import("gpio.zig").Pin;

// FIXME: Dirty hack until the scheduler is completed.
pub const clockCounter = kernel.clockCounter;

pub const Task = kernel.Task;

const global = struct {
    var frequency: u32 = undefined;
};

pub fn initialize(
    comptime num_harts: u32,
    comptime num_tasks: usize,
    tasks: [num_tasks]*kernel.Task,
) *kernel.Scheduler(num_harts, tasks.len, kernel.Configuration.multicore) {
    const Scheduler = kernel.Scheduler(num_harts, num_tasks, kernel.Configuration.multicore);

    const local = struct {
        var scheduler: Scheduler = .{};
        var schedulerIsr: Scheduler.Isr = undefined;
    };

    kernel.initialize();
    global.frequency = kernel.operatingFrequency();

    local.scheduler = Scheduler.init(tasks, 5000);
    local.schedulerIsr = Scheduler.Isr.init(&local.scheduler);
    kernel.setupSchedulerIsr(&local.schedulerIsr.vector);
    kernel.enableInterrupts(false, true, false);

    return &local.scheduler;
}

pub fn errorState() noreturn {
    // Disable all.
    kernel.enableInterrupts(false, false, false);

    var redLed = Pin.init(22, .{ .mode = .DigitalOutput });
    while (true) {
        redLed.toggle();
        kernel.busySleep(20000);
    }
}
