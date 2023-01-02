pub const Op = enum(c_int) {
    /// Invokes the scheduler to schedule another
    /// task instead. The scheduler might decide to
    /// schedule the same thread, thus it does have
    /// a performance cost.
    ///
    /// It's intended use case is for uninterruptable
    /// tasks to provide opportunity for other tasks
    /// to do work. Used in spots where the task might stall.
    yield,

    /// Suspends the task for a set amount of time.
    /// Agruments:
    ///   - 4B int - time in nanoseconds.
    sleep,
};
