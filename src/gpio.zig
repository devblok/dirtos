const arch = @import("./arch/base.zig");

/// Describes a hardware pin.
pub const Pin = struct {
    n: u5,
    mode: PinMode,

    const Self = @This();

    const Options = struct {
        mode: PinMode,
        irq_prio: u8 = 0,
        rise_irq: ?*arch.Vector = null,
        fall_irq: ?*arch.Vector = null,
        high_irq: ?*arch.Vector = null,
        low_irq: ?*arch.Vector = null,
    };

    const PinMode = enum {
        NotConfigured,
        DigitalInput,
        DigitalOutput,
        AnalogInput,
        AnalogOutput,
        Alternative,
    };

    /// Returns a hardware pin of given ID.
    pub fn init(pin: u5, opts: Options) Self {
        configure(pin, opts);
        return .{
            .n = pin,
            .mode = opts.mode,
        };
    }

    fn configure(n: u5, o: Options) void {
        switch (o.mode) {
            .DigitalInput => arch.gpioPinInput(n, true),
            .DigitalOutput => arch.gpioPinOutput(n, true),
            .AnalogInput => {},
            .AnalogOutput => {},
            .Alternative => {},
            .NotConfigured => {},
        }

        if (o.rise_irq) |irq| {
            arch.gpioPinRiseIrq(n, irq);
        }

        if (o.irq_prio > 0) {
            arch.setGpioPlicPriority(n, o.irq_prio);
        }
    }

    pub fn toggle(self: *const Self) void {
        arch.gpioPinToggle(self.n);
    }

    pub fn deinit(self: *const Self) void {

        // TODO: repeat for the rest of ISRs.
        arch.gpioPinRiseIrq(self.n, null);

        switch (self.mode) {
            .DigitalInput => arch.gpioPinInput(self.n, false),
            .DigitalOutput => arch.gpioPinOutput(self.n, false),
            .AnalogInput => {},
            .AnalogOutput => {},
            .Alternative => {},
            .NotConfigured => {},
        }
    }
};

pub fn PinIsr(comptime Context: type) type {
    return struct {
        ctx: Context,
        isr: fn (*Context) void,
        vector: arch.Vector,

        const Self = @This();

        pub fn init(ctx: Context, vector: fn (*Context) void) Self {
            return .{
                .ctx = ctx,
                .isr = vector,
                .vector = .{ .vector = isr },
            };
        }

        fn isr(vector: *arch.Vector) void {
            const self = @fieldParentPtr(Self, "vector", vector);
            self.isr(&self.ctx);
        }
    };
}
