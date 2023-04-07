const time = @import("std").time;

pub const Op = enum(c_int) {
    /// Invokes the scheduler to schedule another
    /// task instead. The scheduler might decide to
    /// schedule the same thread, thus it does have
    /// a performance cost.
    ///
    /// It's intended use case is for tasks to
    /// provide opportunity for other (most likely higher priority)
    /// tasks to do work. Used in spots where the task might stall,
    /// causing other important tasks to miss their deadlines.
    /// Yielding task is marked as Suspended by the scheduler.
    yield,

    /// Suspends the task for a set amount of time.
    /// Agruments:
    ///   - 4B int - time in nanoseconds.
    sleep,

    /// Provides the hardware thread (or core) number. Needed for
    /// task scheduler self-awareness.
    /// Return: u32
    hardware_thread,

    /// Asks the scheduler to set the task to a Blocked state.
    /// Such a task is intended to be unblocked by IRQ signal.
    /// Arguments:
    ///   -
    blocking_op,
};

pub fn syscall(num: c_int, a1: c_int, _: c_int, _: c_int, _: c_int, _: c_int, _: c_int) void {
    switch (@as(Op, num)) {
        .yield => yield(),
        .sleep => sleep(@as(u64, a1)),
    }
}

fn yield() void {
    @panic("not implemented");
}

fn sleep(_: u64) void {
    @panic("not implemented");
}
