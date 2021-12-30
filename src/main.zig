const FixedBufferAllocator = @import("std").heap.FixedBufferAllocator;
const Pin = @import("gpio.zig").Pin;
const Task = @import("task.zig").Task;
const sched = @import("sched.zig");
const riscv = @import("arch/riscv.zig");
const arch = @import("arch/base.zig");

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
        } else {
            self.pin.toggle();
            arch.sleep(20000); // For now delay only.
        }

        return 0; // TODO: Must be current time + next toggle.
    }
};

// TODO: Some of this stuff needs to be hidden from the user.
// It's not straightforward to set up the chip + it needs to
// be platform specific.
const global = struct {
    var heap_buffer: [512]u8 = undefined;
    var blink_task = Blink.init(19);
    var task_list = [_]sched.Entry{
        .{ .priority = 0, .ptr = &blink_task.task },
    };
};

comptime {
    @export(start, .{ .name = "_kernel_start", .section = ".init" });
}

fn start() callconv(.C) noreturn {
    riscv.disablePLIC();
    // arch.enableInterrupts();
    arch.plicIrqMask(0);

    main() catch {
        errorState();
    };

    unreachable;
}

fn main() !void {
    arch.sleep(1000000);

    var fixed_alloc = FixedBufferAllocator.init(&global.heap_buffer);
    var scheduler = try sched.Scheduler.init(
        &fixed_alloc.allocator(),
        global.task_list[0..],
    );
    defer scheduler.deinit(global.allocator.allocator());

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
