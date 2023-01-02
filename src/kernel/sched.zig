const std = @import("std");
const sort = std.sort.sort;
const assert = std.debug.assert;
const Atomic = std.atomic.Atomic;
const Allocator = std.mem.Allocator;

const arch = @import("arch/base.zig");
const Task = @import("task.zig").Task;

pub const Error = error{
    Halt, // Scheduler must halt.
};

/// The main scheduler for this OS. It is completely unfair and will always
/// prefer higher priority tasks to run, if they're ready to.
/// It also relies on the async mechanism of Zig, meaning that the tasks
/// must behave and not hog cycles for too long, or else there's a risk of
/// other tasks not being scheduled in time.
///
/// Tasks are given at compile time in decreasing order of priority.
pub fn Scheduler(
    comptime num_tasks: usize,
    comptime use_lr_sc: bool, // Some MCUs cannot do atomic compare and swap.
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

        pub fn init(self: *Self, entries: [num_tasks]*Task) void {
            for (self.tasks) |*t, i| {
                t.* = .{
                    .ptr = entries[i],
                    .frame = undefined,
                    .status = Atomic(Task.Status).init(.Suspended),
                    .next = 0,
                };
            }
        }

        /// Will schedule next task to run if able. Only one such function
        /// must run at one time. Is designed to run in ISR context.
        /// Returns the requested cycle count (time) of the next scheduler run.
        pub fn schedule(self: *Self) linksection(".fast") u64 {
            if (self.nextTaskWithStatus(.Suspended)) |idx| {
                if (self.isDueToStage(idx)) {
                    self.async_frames[idx] = async self.stageTask(idx);
                }
            }

            // Determine when the next scheduler run should happen.
            var lowest: u64 = arch.clockCounter(0) + 5000; // FIXME: Default should be configurable.
            for (self.tasks) |*t| {
                if (t.status.load(.Acquire) == .Suspended and t.next < lowest) lowest = t.next;
            }
            return lowest;
        }

        /// Finds the highest priority available tasks to run and runs it until completion
        /// or until the task blocks for some reason. Returned boolean is a halt condition
        /// indication. If true is returned, wait loop should be exited.
        pub fn tryRunNextTask(self: *Self) linksection(".fast") bool {
            if (self.nextTaskWithStatus(.Staged)) |idx| {
                const task = &self.tasks[idx];
                // const frame = &self.async_frames[idx];

                // If we manage to set the task into a running state, it's now safe
                // to resume the task on the thread that this method is running on.
                // We return the frame which can be awaited to collect the task result.
                var run = false;

                if (use_lr_sc) {
                    if (task.status.compareAndSwap(
                        .Staged,
                        .Running,
                        .AcqRel,
                        .Acquire,
                    )) |_| {} else run = true;
                } else {
                    const status = task.status.load(.Acquire);
                    if (status == .Staged) {
                        task.status.store(.Running, .Release);
                        run = true;
                    }
                }

                if (run) resume task.frame;
            }
            return false; // TODO: True is impossible right now.
        }

        pub fn threadRun(self: *Self) void {
            while (!self.tryRunNextTask()) {
                Self.waitForWork();
            }
        }

        /// Checks if the task is ready to be scheduled.
        fn isDueToStage(self: *Self, idx: u32) linksection(".fast") bool {
            return self.tasks[idx].next <= arch.clockCounter(0);
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

        /// Architecture dependant waiting routine that is used when there
        /// is no work available at the time.
        fn waitForWork() linksection(".fast") void {
            arch.wait();
        }

        pub const Isr = struct {
            vector: arch.Vector,
            scheduler: *Self,

            pub fn init(scheduler: *Self) Isr {
                return .{
                    .vector = .{ .vector = isr },
                    .scheduler = scheduler,
                };
            }

            fn isr(vector: *arch.Vector) linksection(".fast") void {
                const self = @fieldParentPtr(Isr, "vector", vector);
                const nextRequested = self.scheduler.schedule();
                arch.setInterruptOnClock(0, nextRequested);
            }
        };
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

test "scheduling cases" {
    const g = struct {
        var counter = sched_test.BrownieCounter.init(5);
        const tasks = [_]*Task{
            &counter.task,
        };
    };

    var sched: Scheduler(g.tasks.len, true) = .{};
    sched.init(g.tasks);

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
