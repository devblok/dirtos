const assert = @import("std").debug.assert;

// Describes the possible states that a Task can be in.
pub const State = enum {

    // Task has been completed, waiting for next iteration.
    // This is also the initial state of any task.
    Suspended,

    // Task is ready to execute on a thread.
    Staged,

    // Task is currently executing on some thread.
    Running,

    // Task is waiting for some precondition to resolve.
    Blocked,

    // Task failed, it's execution stopped. Will not be scheduled.
    Failed,
};

// A shared item of contextual information that is useful
// for a scheduler to interact with and make descitions on.
pub const Context = struct {

    // Contains the function frame of the Task.
    frame: anyframe,

    // Describes the Task state.
    state: State,

    // If state is Failed, might contain an error explaining
    // the occurence and reason. (TODO: figure out what to do with null)
    err: ?anyerror,

    // Function that starts the task.
    runFn: fn (self: *Self) anyerror!void,

    const Self = @This();

    pub fn init(runFn: fn (self: *Self) anyerror!void) Self {
        return .{
            .frame = undefined,
            .state = .Suspended,
            .err = null,
            .runFn = runFn,
        };
    }

    pub fn run(self: *Self) anyerror!void {
        // Suspend immediately, register task information.
        suspend {
            self.frame = @frame();
            self.state = .Staged;
        }

        // We expect the rest to run on a another thread.
        return self.runFn(self);
    }
};

// A user define-able task that will be scheduled and executed in regular
// configurable intervals of time. The init function will be run only once
// at the beginning of a Task's lifetime. Meanwhile run will contain the actual
// code that will be scheduled to perform it's functions.
pub fn Task(
    comptime TaskContext: type,
    comptime setupFn: fn (ctx: *TaskContext) anyerror!void,
    comptime runFn: fn (ctx: *TaskContext) anyerror!void,
) type {
    return struct {
        ctx: TaskContext,
        schedCtx: Context,

        const Self = @This();

        pub fn init(ctx: TaskContext) Self {
            return .{
                .ctx = ctx,
                .schedCtx = Context.init(run),
            };
        }

        pub fn setup(self: *Self) anyerror!void {
            return setupFn(&self.ctx);
        }

        fn run(ctx: *Context) anyerror!void {
            const self = @fieldParentPtr(Self, "schedCtx", ctx);
            return runFn(&self.ctx);
        }

        pub fn context(self: *Self) *Context {
            return &self.schedCtx;
        }
    };
}

test "task is created with correct default context" {
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

    const ctx = task.context();

    var result = async ctx.run();
    try await result;
    assert(task.ctx.brownies == 35);
}
