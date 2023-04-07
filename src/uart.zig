const io = @import("std").io;
const arch = @import("./kernel/arch/base.zig");

pub const Error = error{NoSuchInstance} || arch.UartError;

pub const Uart = struct {
    instance: u32,
    baud_rate: u32,

    const Self = @This();
    pub const Reader = io.Reader(*Self, arch.UartReadError, read);
    pub const Writer = io.Writer(*Self, arch.UartWriteError, write);

    const Options = struct {
        baud_rate: u32 = 115200,
        stop_bits: u32 = 0,
        tx_watermark: u32 = 0, // Defaults to not triggerring.
        rx_watermark: u32 = 7, // Defaults to not triggerring.
    };

    pub fn init(instance: u32, opts: Options) Error!Self {
        if (instance >= arch.uartInstanceCount()) return error.NoSuchInstance;
        try arch.uartConfigure(instance, opts.baud_rate, opts.stop_bits, opts.tx_watermark, opts.rx_watermark);
        return Self{
            .instance = instance,
            .baud_rate = opts.baud_rate,
        };
    }

    pub fn reader(self: *Self) Reader {
        return .{ .context = self };
    }

    pub fn writer(self: *Self) Writer {
        return .{ .context = self };
    }

    fn read(self: *Self, buffer: []u8) arch.UartReadError!usize {
        // TODO: Do initial read, if incomplete:
        //   - setup signal (must unblock task)
        //   - block task in scheduler
        //   - suspend the task
        return try arch.uartReadBuffer(self.instance, buffer);
    }

    fn write(self: *Self, buffer: []const u8) arch.UartWriteError!usize {
        // TODO: Do initial write, if incomplete:
        //   - setup the signal (must unblock task when fired)
        //   - block task in scheduler
        //   - suspend the task
        return try arch.uartWriteBuffer(self.instance, buffer);
    }
};
