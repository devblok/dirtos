const Pin = @import("gpio.zig").Pin;
const Task = @import("task.zig").Task;
const Uart = @import("uart.zig").Uart;
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

    fn setupOnce(self: *Blink) void {
        if (!self.did_init) {
            self.pin = Pin.init(self.pin_no, .{ .mode = .DigitalOutput });
            self.did_init = true;
        }
    }

    fn taskRun(task: *Task) Task.Result {
        const self = @fieldParentPtr(Blink, "task", task);
        return .{ .next_time = self.run() };
    }

    fn run(self: *Blink) u64 {
        self.setupOnce();
        self.pin.toggle();
        return arch.clockCounter(0) + 20000;
    }
};

const Print = struct {
    task: Task,
    instance: u32,
    written_bytes: u64,

    uart: Uart,
    did_init: bool,

    has_error: bool,
    error_val: anyerror,

    pub fn init(instance: u32) Print {
        return .{
            .task = .{ .runFn = taskRun },
            .instance = instance,
            .written_bytes = 0,
            .uart = undefined,
            .did_init = false,
            .has_error = false,
            .error_val = undefined,
        };
    }

    fn taskRun(task: *Task) Task.Result {
        const self = @fieldParentPtr(Print, "task", task);
        return .{ .next_time = self.run() };
    }

    fn run(self: *Print) u64 {
        if (self.has_error) {
            return arch.clockCounter(0) + 100000;
        }

        self.setupOnce();

        if (self.uart.write("Hello world!\n")) |written| {
            self.written_bytes += written;
        } else |err| {
            switch (err) {
                error.TxQueueFull => {},
                else => self.setError(err),
            }
        }
        return arch.clockCounter(0) + 100000;
    }

    fn setupOnce(self: *Print) void {
        if (self.did_init) return;
        if (Uart.init(self.instance, .{ .stop_bits = 1 })) |inst| {
            self.uart = inst;
        } else |err| {
            self.setError(err);
        }
    }

    fn setError(self: *Print, err: anyerror) void {
        self.has_error = true;
        self.error_val = err;
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
    var print_task = Print.init(0);

    const task_list = [_]*Task{
        &blink_task.task,
        &print_task.task,
    };

    var scheduler = dirtos.initialize(task_list.len, task_list);
    while (!scheduler.tryRunNextTask()) {
        scheduling.waitForWork();
    }
    return error.Halt;
}

fn errorState() noreturn {
    // Disable all.
    arch.enableInterrupts(false, false, false);

    var redLed = Pin.init(22, .{ .mode = .DigitalOutput });
    while (true) {
        redLed.toggle();
        arch.sleep(20000);
    }
}
