const assert = @import("std").debug.assert;

// Describes the possible states that a Task can be in.
pub const State = enum {

    // Task has been completed, waiting for next iteration.
    // This is also the initial state of any task.
    Suspended,

    // Task is currently executing on some thread.
    Running,

    // Task is waiting for some precondition to resolve.
    Blocked,

    // Task failed, it's execution stopped. Will not be scheduled.
    Failed,
};

// A shared item of contextual information that is useful
// for a scheduler to interact with and make descitions on.
pub const TaskContext = struct {

    // Contains the function frame of the Task.
    frame: anyframe = undefined,

    // Describes the Task state.
    state: State = .Suspended,

    // If state is Failed, will contain an error explaining
    // the occurence and reason.
    err: anyerror = undefined,
};

// A user define-able task that will be scheduled and executed in regular
// configurable intervals of time. The init function will be run only once
// at the beginning of a Task's lifetime. Meanwhile run will contain the actual
// code that will be scheduled to perform it's functions.
pub fn Task(
    comptime Context: type,
    comptime setupFn: fn (ctx: *Context) anyerror!void,
    comptime runFn: fn (ctx: *Context) anyerror!void,
) type {
    return struct {
        ctx: Context,
        tCtx: TaskContext,

        const Self = @This();

        pub fn init(ctx: Context) Self {
            return .{
                .ctx = ctx,
                .tCtx = .{
                    .frame = undefined,
                    .state = .Suspended,
                    .err = undefined,
                },
            };
        }

        pub fn setup(self: *Self) anyerror!void {
            return setupFn(&self.ctx);
        }

        pub fn run(self: *Self) anyerror!void {
            return runFn(&self.ctx);
        }

        pub fn context(self: *Self) *TaskContext {
            return &self.tCtx;
        }
    };
}

test "Task is created with correct default context" {
    const MyTaskContext = struct {
        brownies: u8,

        const Self = @This();

        fn setup(self: *Self) anyerror!void {
            self.brownies = 5;
        }

        fn run(self: *Self) anyerror!void {
            var idx: u32 = 0;
            while (idx < 5) : (idx += 1) {
                self.brownies += 6;
            }
        }
    };
    const MyTask = Task(MyTaskContext, MyTaskContext.setup, MyTaskContext.run);

    var task: MyTask = MyTask.init(.{
        .brownies = 0,
    });
    try task.setup();
    assert(task.ctx.brownies == 5);

    try task.run();
    assert(task.ctx.brownies == 35);
}
