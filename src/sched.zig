const assert = @import("std").debug.assert;
const task = @import("task.zig");

const Entry = struct {
    priotiry: u32,
    context: *task.Context,
};

pub fn Scheduler(
    comptime tasks: []Entry,
) type {
    return struct {
        tasks: []Entry,
    };
}

test "sorts at compile time" {
    const Brownies = struct {
        count: u32,

        const Self = @This();

        pub fn setup(self: *Self) anyerror!void {
            self.count = 1;
        }

        pub fn run(self: *Self) anyerror!void {
            self.count += 5;
        }
    };
    const MyTask = task.Task(Brownies, Brownies.setup, Brownies.run);

    var testTask = MyTask.init(.{
        .count = 0,
    });
    assert(testTask.ctx.count == 0);

    try testTask.setup();
    assert(testTask.ctx.count == 1);

    // TODO: Complete compile time sorting of tasks.
}
