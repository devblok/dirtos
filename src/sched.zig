const std = @import("std");
const sort = std.sort.sort;
const task = @import("task.zig");

const Entry = struct {
    priority: u8,
    context: *const task.Task,

    fn sort(_: void, a: Entry, b: Entry) bool {
        return a.priority < b.priority;
    }
};

pub const Scheduler = struct {
    states: []task.State,
    statuses: []task.Status,
    tasks: []*const task.Task,

    const Self = @This();

    pub fn init(comptime tasks: []Entry) Self {
        comptime sort(Entry, tasks, {}, Entry.sort);

        var sorted = init: {
            var initial: [tasks.len]*const task.Task = undefined;
            for (tasks) |t, i| {
                initial[i] = t.context;
            }
            break :init initial;
        };

        var states = [_]task.State{.{ .frame = undefined }} ** tasks.len;
        var statuses = [_]task.Status{task.Status.Suspended} ** tasks.len;
        return .{
            .tasks = sorted[0..],
            .states = states[0..],
            .statuses = statuses[0..],
        };
    }
};

const expect = std.testing.expect;

test "sorts at compile time" {
    const BrownieCounter = struct {
        brownies: u8,
        task: task.Task,

        const Self = @This();

        pub fn init(start: u8) Self {
            return .{ .brownies = start, .task = .{
                .runFn = taskRun,
            } };
        }

        fn taskRun(t: *task.Task) u32 {
            const self = @fieldParentPtr(Self, "task", t);
            return self.run();
        }

        fn run(self: *Self) u32 {
            var idx: u32 = 0;
            while (idx < 5) : (idx += 1) {
                self.brownies += 6;
            }
            return 50 + self.brownies;
        }
    };

    comptime var counter1 = BrownieCounter.init(5);
    comptime var counter2 = BrownieCounter.init(8);

    comptime var tasks = [_]Entry{
        .{ .priority = 12, .context = &counter1.task },
        .{ .priority = 0, .context = &counter2.task },
    };

    const sched = Scheduler.init(tasks[0..]);

    try expect(sched.tasks[0] == &counter2.task);
}
