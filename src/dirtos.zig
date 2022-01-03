const scheduling = @import("sched.zig");
const arch = @import("arch/base.zig");
const riscv = @import("arch/riscv.zig");
const Task = @import("task.zig").Task;

const std = @import("std");
const Allocator = std.mem.Allocator;
const FixedBufferAllocator = std.heap.FixedBufferAllocator;

const global = struct {
    var frequency: u32 = undefined;
};

pub fn initialize(
    comptime num_tasks: usize,
    tasks: [num_tasks]*Task,
) *scheduling.Scheduler(tasks.len, arch.config.multicore) {
    const RtosScheduler = scheduling.Scheduler(num_tasks, arch.config.multicore);

    const SchedulerIsr = struct {
        vector: arch.Vector,
        scheduler: *RtosScheduler,

        const Self = @This();

        pub fn init(scheduler: *RtosScheduler) Self {
            return .{
                .vector = .{ .vector = isr },
                .scheduler = scheduler,
            };
        }

        fn isr(vector: *arch.Vector) void {
            const self = @fieldParentPtr(Self, "vector", vector);
            self.scheduler.schedule();

            const currentCycles = riscv.clintGetCycleCount(0);
            riscv.clintSetTimeCmp(0, currentCycles + 50000);
        }
    };

    const local = struct {
        var scheduler: RtosScheduler = .{};
        var schedulerIsr: SchedulerIsr = undefined;
    };

    arch.init();
    riscv.disablePLIC();
    arch.plicIrqMask(0);

    global.frequency = arch.operatingFrequency();
    local.scheduler.init(tasks);
    local.schedulerIsr = SchedulerIsr.init(&local.scheduler);

    riscv.clintSetTimerIrq(&local.schedulerIsr.vector);
    riscv.clintSetTimeCmp(0, riscv.clintGetCycleCount(0));
    arch.enableInterrupts(false, true, false);

    return &local.scheduler;
}
