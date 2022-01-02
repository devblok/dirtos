const mem = @import("std").mem;

pub const config = struct {
    var multicore = false;
};

extern var _periph_gpio_start: u32;
extern var _periph_gpio_end: u32;

extern var _periph_plic_priority_start: u32;
extern var _periph_plic_priority_mask: u32;
extern var _periph_plic_claim_reg: u32;
extern var _periph_plic_hart0_enables: u32;

extern var _periph_uart_instance_count: u32;
extern var _periph_uart_0_start: u32;
extern var _periph_uart_1_start: u32;

extern var _prci_start: u32;

extern var __itim_source_start: u32;
extern var __itim_target_start: u32;
extern var __itim_target_end: u32;
extern var __itim_target_size: u32;

const UartInst = extern struct {
    tx_data: u32,
    rx_data: u32,
    tx_ctrl: u32,
    rx_ctrl: u32,
    irq_en: u32,
    irq_pen: u32,
    baud_div: u32,
};

const GpioInst = extern struct {
    input: u32,
    in_enable: u32,
    out_enable: u32,
    output: u32,
    pull_up_enable: u32,
    drive_strength: u32,
    rise_irq_enable: u32,
    rise_irq_pending: u32,
    fall_irq_enable: u32,
    fall_irq_pending: u32,
    high_irq_enable: u32,
    high_irq_pending: u32,
    low_irq_enable: u32,
    low_irq_pending: u32,
    output_xor: u32,
};

/// Platform level interrupt controller priotity map.
const PlicPriorityMap = extern struct {
    aon_watchdog_pri: u32,
    aon_rtc_pri: u32,
    uart_pri: [2]u32,
    qspi_pri: u32,
    spi_pri: [2]u32,
    gpio_pri: [32]u32,
    pwm_0_pri: [4]u32,
    pwm_1_pri: [4]u32,
    pwm_2_pri: [4]u32,
    i2c_pri: u32,
};

pub fn init() void {
    // TODO: Allocate the entire .fast segment into ITIM.

    const size = @ptrToInt(@ptrCast(*u32, &__itim_target_size));
    var dest = @ptrCast([*]u8, &__itim_target_start);
    var source = @ptrCast([*]u8, &__itim_source_start);

    @fence(.Acquire);
    mem.copy(u8, dest[0..size], source[0..size]);
}

pub fn wait() void {
    wfi();
}

fn wfi() void {
    asm volatile ("wfi");
}

pub fn gpioPinOutput(pin: u5, enable: bool) void {
    const reg = @ptrCast(*GpioInst, &_periph_gpio_start);

    if (enable) {
        _ = @atomicRmw(u32, &reg.out_enable, .Or, @as(u32, 1) << pin, .Acquire);
    } else {
        _ = @atomicRmw(u32, &reg.out_enable, .Xor, @as(u32, 1) << pin, .Acquire);
    }
}

pub fn gpioPinInput(pin: u5, enable: bool) void {
    const reg = @ptrCast(*GpioInst, &_periph_gpio_start);

    if (enable) {
        _ = @atomicRmw(u32, &reg.in_enable, .Or, @as(u32, 1) << pin, .Acquire);
    } else {
        _ = @atomicRmw(u32, &reg.in_enable, .Xor, @as(u32, 1) << pin, .Acquire);
    }
}

pub fn gpioPinRiseIrq(pin: u5, irq: ?*GpioVector) void {
    const reg = @ptrCast(*GpioInst, &_periph_gpio_start);

    if (irq) |vec| {
        gpioVectorTable[pin] = vec;
        _ = @atomicRmw(u32, &reg.rise_irq_enable, .Or, @as(u32, 1) << pin, .Acquire);
        plicIrqReg(pin + 8, true);
    } else {
        gpioVectorTable[pin] = null;
        _ = @atomicRmw(u32, &reg.rise_irq_enable, .Xor, @as(u32, 1) << pin, .Acquire);
        plicIrqReg(pin + 8, false);
    }
}

pub fn gpioPinToggle(pin: u5) void {
    var reg = @ptrCast(*GpioInst, &_periph_gpio_start);
    _ = @atomicRmw(u32, &reg.output, .Xor, @as(u32, 1) << pin, .Acquire);
}

pub fn gpioPinRead(pin: u5) bool {
    var reg = @ptrCast(*GpioInst, &_periph_gpio_start);
    var in: u32 = @atomicLoad(u32, &reg.in_enable, .Acquire);

    return if (in & (@as(u32, 1) << pin) == 0) true else false;
}

fn plicIrqReg(irq_src: u32, on: bool) void {
    const reg = @ptrCast(*[2]u32, &_periph_plic_hart0_enables); // TODO: Move away from hardcoded length.

    const idx = irq_src / 32;
    const off = @intCast(u5, irq_src % 32);

    if (on) {
        _ = @atomicRmw(u32, &reg[idx], .Or, @as(u32, 1) << off, .Acquire);
    } else {
        _ = @atomicRmw(u32, &reg[idx], .Xor, @as(u32, 1) << off, .Acquire);
    }
}

pub fn setGpioPlicPriority(pin: u5, priority: u32) void {
    var prio_map = @ptrCast(*PlicPriorityMap, &_periph_plic_priority_start);
    @atomicStore(u32, &prio_map.gpio_pri[pin], priority, .Release);
}

pub fn disablePLIC() void {
    const size = comptime @sizeOf(PlicPriorityMap);
    const prio_map = @ptrCast(*[size]u32, &_periph_plic_priority_start);

    var idx: u32 = 0;
    while (idx < size) : (idx += 1) {
        prio_map[idx] = 0;
    }
}

pub fn togglePin(n: u5) void {
    var reg = @ptrCast(*GpioInst, &_periph_gpio_start);
    reg.output = reg.output ^ @as(u32, 1) << n;
}

// TODO: linksection(".fast")
pub fn sleep(loops: u32) void {
    var idx: u32 = 0;
    while (idx < loops) : (idx += 1) {
        asm volatile ("nop");
    }
}

// The interrupt codes that might be parsed from mcause.
const InterruptCode = enum {
    MachineSoftware,
    MachineTimer,
    MachineExternal,
    Unknown,
};

// Fault codes that can be parsed from mcause.
const FaultCode = enum {
    InstrAddrMisaligned,
    InstrAccFault,
    IllegalInstruction,
    Breakpoint,
    LoadAddrMisaligned,
    LoadAccFault,
    StoreAmoAddrMisaligned,
    StoreAmoAccFault,
    EnvCallUserMode,
    EnvCallMachineMode,
    Unknown,
};

comptime {
    @export(vectorBase, .{ .name = "_kernel_isr" });
}

pub fn enableInterrupts() void {
    const val: u32 = 0x0808;
    _ = asm volatile (
        \\ csrw mie, a0
        :
        : [val] "{a0}" (val)
        : "memory", "a0"
    );
}

/// The base ISR that should be specified in the mtvec register.
/// Params: epc, cause, hart_id, status
fn vectorBase(_: u32, cause: u32, _: u32, _: u32) callconv(.C) void {
    if (isIrq(cause)) {
        switch (parseIrqCode(cause)) {
            .MachineExternal => plicIrqHandle(),
            else => asm volatile ("nop"), // TODO: Handle the rest of the instructions.
        }
    } else {
        // TODO: Implement fault handling. Blink a red LED or something.
        // switch (parseFaultCode(cause)) ...
        asm volatile ("nop");
    }
}

/// Parses the cause to determine if this is an IRQ or a fault.
fn isIrq(cause: u32) bool {
    return cause & 0x80_00_00_00 != 0;
}

/// Parses the IRQ code from the mcause register information.
fn parseIrqCode(cause: u32) InterruptCode {
    return switch (cause ^ 0x80_00_00_00) {
        3 => .MachineSoftware,
        7 => .MachineTimer,
        11 => .MachineExternal,
        else => .Unknown,
    };
}

/// Parses the fault code from the mcause resiter information.
fn parseFaultCode(cause: u32) FaultCode {
    return switch (cause) {
        0 => .InstrAddrMisaligned,
        1 => .InstrAccFault,
        2 => .IllegalInstruction,
        3 => .Breakpoint,
        4 => .LoadAddrMisaligned,
        5 => .LoadAccFault,
        6 => .StoreAmoAddrMisaligned,
        7 => .StoreAmoAccFault,
        8 => .EnvCallUserMode,
        11 => .EnvCallMachineMode,
        else => .Unknown,
    };
}

fn plicIrqHandle() void {
    const irq_src = plicIrqClaim();
    defer plicIrqComplete(irq_src);

    switch (irq_src) {
        8...39 => gpioIrqHandle(irq_src - 8),
        else => asm volatile ("nop"), // TODO: Handle the rest of the IRQs.
    }
}

fn plicIrqClaim() u32 {
    const claim = @ptrCast(*u32, &_periph_plic_claim_reg);
    return @atomicLoad(u32, claim, .Acquire);
}

fn plicIrqComplete(irq_src: u32) void {
    const claim = @ptrCast(*u32, &_periph_plic_claim_reg);
    @atomicStore(u32, claim, irq_src, .Release);
}

/// Sets the priority mask register in the PLIC, to mask none, some or all IRQs.
pub fn plicIrqMask(mask: u5) void {
    var reg = @ptrCast(*u32, &_periph_plic_priority_mask);
    @atomicStore(u32, reg, @as(u32, mask), .Release);
}

fn gpioIrqHandle(pin: u32) void {
    defer gpioIrqComplete(pin);
    if (gpioVectorTable[pin]) |vec| {
        vec.isr();
    }
}

fn gpioIrqComplete(pin: u32) void {
    const reg = @ptrCast(*GpioInst, &_periph_gpio_start);
    @atomicStore(u32, &reg.rise_irq_pending, @as(u32, 1) << @intCast(u5, pin), .Release);
}

pub const GpioVector = struct {
    vector: fn (*Self) void,

    const Self = @This();

    pub fn isr(self: *Self) void {
        self.vector(self);
    }
};

var gpioVectorTable = [_]?*GpioVector{null} ** 32;

pub fn uartInstanceCount() usize {
    return @ptrToInt(&_periph_uart_instance_count);
}

pub const UartError = error{
    BadInstance,
    BadBaudRate,
    InstanceBusy,
    RxQueueEmpty,
    TxQueueFull,
    InvalidStopBitCount,
    InvalidTxWatermark,
    InvalidRxWatermark,
};

fn uartInstance(inst: u32) UartError!*UartInst {
    return switch (inst) {
        1 => @ptrCast(*UartInst, &_periph_uart_0_start),
        2 => @ptrCast(*UartInst, &_periph_uart_1_start),
        else => error.BadInstance,
    };
}

pub fn uartConfigure(inst: u32, baud: u32, stop_bits: u32, txcnt: u32, rxcnt: u32) UartError!void {
    const reg = try uartInstance(inst);

    try uartSetBaudRate(reg, baud);

    var txctrl: u32 = 1;
    switch (stop_bits) {
        1 => {},
        2 => txctrl |= 2,
        else => return error.InvalidStopBitCount,
    }

    if (txcnt > 7) {
        return error.InvalidTxWatermark;
    } else {
        txctrl |= txcnt << 16;
    }
    @atomicStore(u32, &reg.tx_ctrl, txctrl, .Release);

    var rxctrl: u32 = 1;
    if (rxcnt > 7) {
        return error.InvalidRxWatermark;
    } else {
        rxctrl |= rxcnt << 16;
    }
    @atomicStore(u32, &reg.rx_ctrl, rxctrl, .Release);
}

fn uartSetBaudRate(inst: *UartInst, baud: u32) UartError!void {
    if (baud == 115200) return; // 115200 is configured on reset by default.

    const uartDiv = operatingFrequency() / baud - 1;
    @atomicStore(u32, &inst.baud_div, uartDiv, .Release);
}

pub fn uartReadByte(instance: u32) UartError!u8 {
    const reg = try uartInstance(instance);
    const val = @atomicLoad(u32, &reg.rx_data, .Acquire);

    // The last bit is set if queue is empty, so check if we're out of bounds.
    return if (val > 256) error.RxQueueEmpty else @intCast(u8, val);
}

pub fn uartWriteByte(instance: u32, byte: u8) UartError!void {
    const reg = try uartInstance(instance);
    const prev = @atomicRmw(u32, &reg.tx_data, .Max, byte, .Acquire);
    if (prev > 256) return error.TxQueueFull;
}

const PrciInst = extern struct {
    hfrosccfg: u32,
    hfxosccfg: u32,
    pllcfg: u32,
    plloutdiv: u32,
    procmoncfg: u32,
};

/// Calculates and returns the current operating freuency of the CPU.
/// FIXME: Needs to be verified carefully. Unchecked. No tests.
fn operatingFrequency() u32 {
    const prci = @ptrCast(*PrciInst, &_prci_start);

    const pll = @atomicLoad(u32, &prci.pllcfg, .Acquire);
    const pllDiv = @atomicLoad(u32, &prci.plloutdiv, .Acquire);

    // TODO: calculate the other oscillator.
    const pllRef = if (pll & 0x00_02_00_00 == 0) unreachable else calcRingOscFreq(prci);

    var pllOut: u32 = 0;
    if (pll & 0x00_04_00_00 == 0) {
        const pllR = (pll & 0x00_03) + 1;
        const pllF = 2 * (((pll & 0x01_F0) >> 4) + 1);
        const pllQ = (pll & 0x06_00) >> 10;

        var idx: u32 = 0;
        var qVal: u32 = 1;
        while (idx < pllQ) : (idx += 1) qVal *= 2;

        pllOut = ((pllRef / pllR) * pllF) / qVal;
    } else {
        pllOut = pllRef;
    }

    if (pllDiv & 0x01_00 == 0) {
        const pllOutDiv = pllDiv & 0x00_1F;
        return pllOut / pllOutDiv;
    } else {
        return pllOut;
    }
}

fn calcInternalOscFreq(prci: *PrciInst) u32 {
    const val = @atomicLoad(u32, &prci.hfrosccfg, .Acquire);
    return val;
}

fn calcRingOscFreq(prci: *PrciInst) u32 {
    const val = @atomicLoad(u32, &prci.hfxosccfg, .Acquire);
    return val;
}
