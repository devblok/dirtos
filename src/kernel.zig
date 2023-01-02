const syscall = @import("kernel/syscall.zig");
const arch = @import("kernel/arch/base.zig");

// FIXME: Another dirty hack.
const riscv = @import("kernel/arch/riscv.zig");

// FIXME: Dirty hack until scheduler is completed.
pub const clockCounter = arch.clockCounter;
pub const operatingFrequency = arch.operatingFrequency;

pub const enableInterrupts = arch.enableInterrupts;
pub const busySleep = arch.sleep;
pub const setupSchedulerIsr = arch.setupSchedulerIsr;

pub const Task = @import("kernel/task.zig").Task;
pub const Scheduler = @import("kernel/sched.zig").Scheduler;

pub const Configuration = arch.config;
pub const Vector = arch.Vector;

pub fn initialize() void {
    arch.init();
    riscv.disablePLIC();
    arch.plicIrqMask(0);
}
