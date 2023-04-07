const std = @import("std");
const builtin = std.builtin;
const fmt = std.fmt;
const heap = std.heap;

const dirtos = @import("dirtos.zig");
const kernel = @import("kernel.zig");
const Task = dirtos.Task;
const Pin = @import("gpio.zig").Pin;
const Uart = @import("uart.zig").Uart;

const Heap = struct {
    var buffer: [1024]u8 = undefined;
    var allocator: heap.FixedBufferAllocator = undefined;

    pub fn init() void {
        allocator = heap.FixedBufferAllocator.init(&buffer);
    }
};

const Config = struct {
    const num_harts = 1;
    const blink_interval = 20000;
    const print_interval = 100000;
};

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
        return dirtos.clockCounter(0) + Config.blink_interval;
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
            return dirtos.clockCounter(0) + Config.print_interval;
        }

        self.setupOnce();

        if (self.uart.writer().write("Hello world!\n")) |written| {
            self.written_bytes += written;
        } else |err| {
            switch (err) {
                error.TxQueueFull => {},
                else => self.setError(err),
            }
        }
        return dirtos.clockCounter(0) + Config.print_interval;
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
    Heap.init();
    var blink = Blink.init(19);
    var print = Print.init(0);

    const task_list = [_]*Task{
        &blink.task,
        &print.task,
    };

    dirtos.initialize(Config.num_harts, task_list.len, task_list).threadRun();
    unreachable;
}

pub fn panic(msg: []const u8, stack: ?*builtin.StackTrace) noreturn {
    kernel.enableInterrupts(false, false, false);
    kernel.busySleep(10000);

    var uart = Uart.init(0, .{ .stop_bits = 1 }) catch unreachable;
    writeAll(msg, uart.writer());
    writeAll("\n", uart.writer());

    const str = fmt.allocPrint(Heap.allocator.allocator(), "{}\n", .{stack}) catch "Error allocating stacktrace string\n";
    writeAll(str, uart.writer());
    dirtos.errorState();
}

fn writeAll(msg: []const u8, writer: Uart.Writer) void {
    var total: usize = 0;
    while (total < msg.len) {
        if (writer.write(msg)) |written| {
            total += written;
        } else |_| {
            kernel.busySleep(10000);
        }
    }
}
