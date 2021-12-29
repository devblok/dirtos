const std = @import("std");
const sort = std.sort.sort;
const Task = @import("task.zig").Task;

pub const Entry = struct {
    priority: u8,
    ptr: *Task,

    fn sort(_: void, a: Entry, b: Entry) bool {
        return a.priority < b.priority;
    }
};

pub const Scheduler = struct {
    tasks: []Context,

    // A shared item of contextual information that is useful
    // for a scheduler to interact with and make descitions on.
    const Context = struct {
        ptr: *Task,
        frame: anyframe,
        status: Task.Status,
        next: u64,
    };

    pub fn init(comptime tasks: []Entry) Scheduler {
        comptime sort(Entry, tasks, {}, Entry.sort);

        var sorted_tasks = init: {
            const static = struct {
                var initial: [tasks.len]Context = undefined;
            };
            for (tasks) |t, i| {
                static.initial[i] = .{
                    .ptr = t.ptr,
                    .frame = undefined,
                    .status = .Suspended,
                    .next = 0,
                };
            }
            break :init static.initial;
        };

        return .{
            .tasks = sorted_tasks[0..],
        };
    }

    // Will schedule next task to run if able. Only one such function
    // must run at one time. Is designed to run in ISR context.
    pub fn schedule(self: *Scheduler) void {
        if (self.nextTaskWithStatus(.Suspended)) |idx| {
            if (self.isDueToStage(idx)) {
                _ = async self.stageTask(idx);
            }
        }
    }

    // Finds the highest priority available tasks to run and runs it until completion.
    pub fn runTask(self: *Scheduler) void {
        if (self.nextTaskWithStatus(.Staged)) |idx| {

            // If we manage to set the task into a running state, it's now safe
            // to resume the task on the thread that this method is running on.
            // We return the frame which can be awaited to collect the task result.
            if (@cmpxchgWeak(
                Task.Status,
                &self.tasks[idx].status,
                .Staged,
                .Running,
                .Acquire,
                .Monotonic,
            )) |_| {
                resume self.tasks[idx].frame;
            }
        }
    }

    // Checks if the task is ready to be scheduled.
    fn isDueToStage(self: *Scheduler, idx: u32) bool {
        return self.tasks[idx].next <= 0; // FIXME: has to check against current time.
    }

    // Prepares and submits the task frame for the hardware threads to execute.
    fn stageTask(self: *Scheduler, idx: u32) void {
        suspend {
            self.tasks[idx].frame = @frame();
            @atomicStore(Task.Status, &self.tasks[idx].status, .Staged, .Release);
        }
        var task = self.tasks[idx].ptr;
        self.finalize(idx, task.run());
    }

    // Stores the task results and resets status to Suspended.
    fn finalize(self: *Scheduler, idx: u32, result: Task.Result) void {
        var task = self.tasks[idx];
        task.next = result.next_time;
        @atomicStore(Task.Status, &task.status, .Suspended, .Release);
    }

    // Obtains the index of the next task with given status.
    fn nextTaskWithStatus(self: *Scheduler, status: Task.Status) ?u32 {
        for (self.tasks) |*ctx, idx| {
            const loaded = @atomicLoad(Task.Status, &ctx.status, .Acquire);
            if (loaded == status) {
                return @intCast(u32, idx);
            }
        }
        return null;
    }
};

const sched_test = struct {
    const expect = std.testing.expect;

    const BrownieCounter = struct {
        brownies: u8,
        task: Task,

        const Self = @This();

        pub fn init(start: u8) Self {
            return .{ .brownies = start, .task = .{
                .runFn = taskRun,
            } };
        }

        fn taskRun(t: *Task) Task.Result {
            const self = @fieldParentPtr(Self, "task", t);
            return self.run();
        }

        fn run(self: *Self) Task.Result {
            var idx: u32 = 0;
            while (idx < 5) : (idx += 1) {
                self.brownies += 6;
            }
            return .{ .next_time = 50 + self.brownies };
        }
    };
};

test "sorts at compile time" {
    comptime var counter1 = sched_test.BrownieCounter.init(5);
    comptime var counter2 = sched_test.BrownieCounter.init(8);

    comptime var tasks = [_]Entry{
        .{ .priority = 12, .ptr = &counter1.task },
        .{ .priority = 0, .ptr = &counter2.task },
    };

    const sched = Scheduler.init(tasks[0..]);

    try sched_test.expect(sched.tasks[0].ptr == &counter2.task);
    try sched_test.expect(sched.tasks[1].ptr == &counter1.task);
}

test "scheduling cases" {
    comptime var counter = sched_test.BrownieCounter.init(5);
    comptime var tasks = [_]Entry{
        .{ .priority = 12, .ptr = &counter.task },
    };

    var sched = Scheduler.init(tasks[0..]);
    try sched_test.expect(sched.tasks[0].status == .Suspended);

    sched.schedule();
    std.log.info("Status {}.", .{sched.tasks[0].status});
    try sched_test.expect(sched.tasks[0].status == .Staged);
    try sched_test.expect(counter.brownies == 5);

    sched.runTask();
    try sched_test.expect(sched.tasks[0].status == .Suspended);
    try sched_test.expect(sched.tasks[0].next == 85);
    try sched_test.expect(counter.brownies == 35);
}
