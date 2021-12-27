const std = @import("std");
const sort = std.sort.sort;
const task = @import("task.zig");

const Entry = struct {
    priority: u8,
    context: *task.Task,

    fn sort(_: void, a: Entry, b: Entry) bool {
        return a.priority < b.priority;
    }
};

pub const Scheduler = struct {
    states: []State,
    tasks: []*task.Task,

    // A shared item of contextual information that is useful
    // for a scheduler to interact with and make descitions on.
    const State = struct {

        // Contains the function frame of the Task.
        frame: @Frame(Scheduler.runTask),

        // The next time this task should be scheduled.
        next: u32,

        // Current status of the task.
        status: task.Status,
    };

    pub fn init(comptime tasks: []Entry) Scheduler {
        comptime sort(Entry, tasks, {}, Entry.sort);

        var sortedTasks = init: {
            var initial: [tasks.len]*task.Task = undefined;
            for (tasks) |t, i| {
                initial[i] = t.context;
            }
            break :init initial;
        };

        var states = [_]State{.{
            .frame = undefined,
            .next = 0,
            .status = .Suspended,
        }} ** tasks.len;

        return .{
            .tasks = sortedTasks[0..],
            .states = states[0..],
        };
    }

    // Will schedule next task to run if able. Only one such function
    // must run at one time. Is designed to run in ISR context.
    pub fn schedule(self: *Scheduler) void {
        if (self.nextTaskWithStatus(.Suspended)) |t| {
            if (self.isDueToStage(t)) {
                self.states[t].frame = async self.runTask(t);
            }
        }
    }

    // Will take first staged task in priority order. Should be run by
    // the executing thread or threads. Can be run concurrently.
    pub fn takeoverTask(self: *Scheduler) ?u32 {
        if (self.nextTaskWithStatus(.Staged)) |idx| {

            // If we manage to set the task into a running state, it's now safe
            // to resume the task on the thread that this method is running on.
            // We return the frame which can be awaited to collect the task result.
            const result = @cmpxchgWeak(task.Status, &self.statuses[idx], .Staged, .Running, .Acquire, .Unordered);
            if (result) |_| {
                resume self.states[idx].frame;
                return idx;
            }
        }
        return null;
    }

    pub fn finishTask(self: *Scheduler, idx: u32) void {
        const result = await self.states[idx].frame;
        self.states[idx].next = result;
        const status = &self.states[idx].status;
        @atomicStore(task.Status, status, .Suspended, .Release);
    }

    fn isDueToStage(self: *Scheduler, idx: u32) bool {
        return self.states[idx].next <= 0; // FIXME: has to check against current time.
    }

    fn runTask(self: *Scheduler, idx: u32) u32 {
        suspend {
            @atomicStore(task.Status, &self.states[idx].status, task.Status.Staged, .Release);
        }
        var t = self.tasks[idx];
        return t.runFn(t);
    }

    // Obtains the index of the next task with given status.
    fn nextTaskWithStatus(self: *Scheduler, status: task.Status) ?u32 {
        for (self.states) |*s, i| {
            const loaded = @atomicLoad(task.Status, &s.status, .Acquire);
            if (loaded == status) {
                return @intCast(u32, i);
            }
        }
        return null;
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
    try expect(sched.tasks[1] == &counter1.task);
}

test "stages a task" {
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

    comptime var counter = BrownieCounter.init(5);
    comptime var tasks = [_]Entry{
        .{ .priority = 12, .context = &counter.task },
    };

    var sched = Scheduler.init(tasks[0..]);
    try expect(sched.states[0].status == .Suspended);

    sched.schedule();
    sched.finishTask(0);
    try expect(sched.states[0].status == .Staged);
}
