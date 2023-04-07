const kernel = @import("kernel.zig");

/// Invokes the scheduler to schedule another
/// task instead. If given a yield of 0,
/// the scheduler might immediately try to
/// reschedule the current task. Thus it might
/// have a negative performance cost for the
/// yieling task.
///
/// It's intended use case is for tasks to
/// provide opportunity for other (most likely higher priority)
/// tasks to do work. Used in spots where the task might stall,
/// causing other important tasks to miss their deadlines.
/// Yielding task is marked as Suspended by the scheduler.
pub fn yield(duration: u64) void {}

/// Ask the scheduler to block the current task. The scheduler
/// will, for all intents and purposes, ignore this task. This is
/// a low level call, the blocked task is intended to be unblocked
/// by another task or IRQ, when some precondition is complete.
///
/// This system is used to solve blocking IO. When a task has
/// no option but to wait for hardware, setting up a signal and
/// unblocking the task will allow other tasks in the system
/// to be scheduled. It is important, however, that the said event
/// actually happens, using this imposes a risk that task will
/// never wake up.
pub fn block() void {}
