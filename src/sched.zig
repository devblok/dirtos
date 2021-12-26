const std = @import("std");
const sort = std.sort.sort;
const task = @import("task.zig");

const Entry = struct {
    priority: u32,
    context: *task.Context,

    fn sort(_: void, a: Entry, b: Entry) bool {
        return a.priority < b.priority;
    }
};

pub const Scheduler = struct {
    tasks: []const Entry,

    const Self = @This();

    pub fn init(comptime tasks: []Entry) Self {
        comptime sort(Entry, tasks, {}, Entry.sort);
        return .{
            .tasks = tasks,
        };
    }
};

const expect = std.testing.expect;

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

    comptime var testTask = MyTask.init(.{
        .count = 0,
    });

    comptime var testTask2 = MyTask.init(.{
        .count = 1,
    });

    comptime var tasks = [_]Entry{
        .{ .priority = 12, .context = testTask.context() },
        .{ .priority = 0, .context = testTask2.context() },
    };

    const sched = Scheduler.init(tasks[0..]);

    try expect(sched.tasks[0].priority == 0);
    try expect(sched.tasks[1].priority == 12);
}
