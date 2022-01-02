const Pin = @import("gpio.zig").Pin;
const Task = @import("task.zig").Task;
const scheduling = @import("sched.zig");
const arch = @import("arch/base.zig");
const dirtos = @import("dirtos.zig");

const Blink = struct {
    task: Task,
    pin: Pin,
    pin_no: u5,
    did_init: bool,

    pub fn init(pin_no: u5) Blink {
        return .{
            .task = .{ .runFn = taskRun },
            .pin = undefined,
            .pin_no = pin_no,
            .did_init = false,
        };
    }

    fn taskRun(task: *Task) Task.Result {
        const self = @fieldParentPtr(Blink, "task", task);
        return .{ .next_time = self.run() };
    }

    fn run(self: *Blink) u64 {
        if (!self.did_init) {
            self.pin = Pin.init(self.pin_no, .{ .mode = .DigitalOutput });
            self.did_init = true;
        } else {
            self.pin.toggle();
            arch.sleep(100000); // For now delay only.
        }

        return 0; // TODO: Must be current time + next toggle.
    }
};

comptime {
    @export(start, .{ .name = "_kernel_start", .section = ".init" });
}

fn start() callconv(.C) noreturn {
    arch.sleep(20000);
    main() catch errorState();
    unreachable;
}

fn main() !void {
    var blink_task = Blink.init(19);
    const task_list = [_]*Task{
        &blink_task.task,
    };
    var scheduler = dirtos.initialize(task_list.len, task_list);
    while (true) {
        scheduler.schedule();
        scheduler.tryRunNextTask();
    }
}

fn errorState() noreturn {
    // TODO: Blink red LED. For now sleep forever.
    while (true) {
        arch.sleep(20000);
    }
}
