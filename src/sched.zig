const std = @import("std");
const sort = std.sort.sort;
const assert = std.debug.assert;
const Atomic = std.atomic.Atomic;
const Allocator = std.mem.Allocator;
const Task = @import("task.zig").Task;

pub const Entry = struct {
    priority: u8,
    ptr: *Task,

    fn sort(_: void, a: Entry, b: Entry) bool {
        return a.priority < b.priority;
    }
};

/// The main scheduler for this OS. It is completely unfair and will always
/// prefer higher priority tasks to run, if they're ready to.
/// It also relies on the async mechanism of Zig, meaning that the tasks
/// must behave and not hog cycles for too long, or else there's a risk of
/// other tasks not being scheduled in time.
pub fn Scheduler(
    comptime num_tasks: usize,
) type {
    return struct {
        tasks: [num_tasks]Context = undefined,
        async_frames: [num_tasks]@Frame(stageTask) = undefined,

        const Self = @This();

        /// A shared item of contextual information that is useful
        /// for a scheduler to interact with and make descitions on.
        const Context = struct {
            ptr: *Task,
            frame: anyframe,
            status: Atomic(Task.Status),
            next: u64,
        };

        pub fn init(comptime entries: []Entry) Self {
            assert(entries.len == num_tasks);

            comptime sort(Entry, entries, {}, Entry.sort);
            var self: Self = .{};
            for (self.tasks) |*task, idx| {
                task.* = .{
                    .ptr = entries[idx].ptr,
                    .frame = undefined,
                    .status = Atomic(Task.Status).init(.Suspended),
                    .next = 0,
                };
            }
            return self;
        }

        /// Will schedule next task to run if able. Only one such function
        /// must run at one time. Is designed to run in ISR context.
        pub fn schedule(self: *Self) linksection(".fast") void {
            if (self.nextTaskWithStatus(.Suspended)) |idx| {
                if (self.isDueToStage(idx)) {
                    self.async_frames[idx] = async self.stageTask(idx);
                }
            }
        }

        /// Finds the highest priority available tasks to run and runs it until completion
        /// or until the task blocks for some reason.
        pub fn tryRunNextTask(self: *Self) linksection(".fast") void {
            if (self.nextTaskWithStatus(.Staged)) |idx| {
                const task = &self.tasks[idx];

                // If we manage to set the task into a running state, it's now safe
                // to resume the task on the thread that this method is running on.
                // We return the frame which can be awaited to collect the task result.
                if (task.status.compareAndSwap(
                    .Staged,
                    .Running,
                    .AcqRel,
                    .Acquire,
                )) |_| {} else resume task.frame;
            }
        }

        /// Checks if the task is ready to be scheduled.
        fn isDueToStage(self: *Self, idx: u32) linksection(".fast") bool {
            return self.tasks[idx].next <= 0; // FIXME: has to check against current time.
        }

        /// Prepares and submits the task frame for the hardware threads to execute.
        fn stageTask(self: *Self, idx: u32) linksection(".fast") void {
            const task = &self.tasks[idx];
            suspend {
                task.frame = @frame();
                task.status.store(.Staged, .Release);
            }
            self.finalize(idx, task.ptr.run());
        }

        /// Stores the task results and resets status to Suspended.
        fn finalize(self: *Self, idx: u32, result: Task.Result) linksection(".fast") void {
            var task = &self.tasks[idx];
            task.next = result.next_time;
            task.status.store(.Suspended, .Release);
        }

        /// Obtains the index of the next task with given status.
        fn nextTaskWithStatus(self: *Self, status: Task.Status) linksection(".fast") ?u32 {
            for (self.tasks) |*ctx, idx| {
                const loaded = ctx.status.load(.Acquire);
                if (loaded == status) {
                    return @intCast(u32, idx);
                }
            }
            return null;
        }
    };
}

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

test "sorts tasks internally" {
    comptime var counter1 = sched_test.BrownieCounter.init(5);
    comptime var counter2 = sched_test.BrownieCounter.init(8);

    comptime var tasks = [_]Entry{
        .{ .priority = 12, .ptr = &counter1.task },
        .{ .priority = 0, .ptr = &counter2.task },
    };

    var sched = Scheduler(tasks.len).init(&tasks);
    try sched_test.expect(sched.tasks[0].ptr == &counter2.task);
    try sched_test.expect(sched.tasks[1].ptr == &counter1.task);
}

test "scheduling cases" {
    const g = struct {
        var counter = sched_test.BrownieCounter.init(5);
        var tasks = [_]Entry{
            .{ .priority = 12, .ptr = &counter.task },
        };
    };

    var sched = Scheduler(g.tasks.len).init(&g.tasks);

    // Scheduler starts with all tasks in suspended states.
    try sched_test.expect(sched.tasks[0].status.load(.Acquire) == .Suspended);

    // We test that task gets staged and prepared to run.
    sched.schedule();
    try sched_test.expect(sched.tasks[0].status.load(.Acquire) == .Staged);
    try sched_test.expect(g.counter.brownies == 5);

    // Task must run until completion and get suspended.
    sched.tryRunNextTask();
    try sched_test.expect(sched.tasks[0].status.load(.Acquire) == .Suspended);
    try sched_test.expect(sched.tasks[0].next == 85);
    try sched_test.expect(g.counter.brownies == 35);
}
