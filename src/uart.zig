const arch = @import("./arch/arch.zig");

pub const Error = error{NoSuchInstance} || arch.UartError;

pub const Uart = struct {
    instance: u32,
    baud_rate: u32,

    const Self = @This();

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

    pub fn readByte(self: *Self) Error!u8 {
        return try arch.uartReadByte(self.instance);
    }

    pub fn write(self: *const Self, bytes: []const u8) Error!u64 {
        var written: u64 = 0;
        for (bytes) |byte| {
            try arch.uartWriteByte(self.instance, byte);
            written += 1;
        }
        return written;
    }
};
