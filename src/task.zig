const std = @import("std");
const assert = std.debug.assert;

pub const Task = struct {
    runFn: fn (*Task) Result,

    // Describes the possible states that a Task can be in.
    pub const Status = enum {

        // Task has been completed, waiting for next iteration.
        // This is also the initial state of any task.
        Suspended,

        // Task is ready to execute on a thread.
        Staged,

        // Task is currently executing on some thread.
        Running,

        // Task is waiting for some precondition to resolve.
        Blocked,
    };

    // Contains the result of task execution.
    pub const Result = struct {
        nextTime: u64,
    };

    pub fn run(self: *Task) Result {
        return self.runFn(self);
    }
};

const expect = std.testing.expect;

test "task is created with correct default context" {
    const BrownieCounter = struct {
        brownies: u8,
        task: Task,

        const Self = @This();

        pub fn init() Self {
            return .{ .brownies = 5, .task = .{
                .runFn = taskRun,
            } };
        }

        fn taskRun(task: *Task) Task.Result {
            const self = @fieldParentPtr(Self, "task", task);
            return self.run();
        }

        fn run(self: *Self) Task.Result {
            var idx: u32 = 0;
            while (idx < 5) : (idx += 1) {
                self.brownies += 6;
            }
            return .{ .nextTime = 50 };
        }
    };

    var counter = BrownieCounter.init();
    try expect(counter.brownies == 5);

    const ret = counter.run();
    try expect(counter.brownies == 35);
    try expect(ret.nextTime == 50);
}
