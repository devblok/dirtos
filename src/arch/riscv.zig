const std = @import("std");
const mem = std.mem;
const Atomic = std.atomic.Atomic;

pub const config = struct {
    pub const multicore = false;
};

const aon_map = struct {
    extern var _aon_domain_start: u32;
    extern var _aon_domain_end: u32;
    extern var _aon_domain_wdogcfg: u32;
    extern var _aon_domain_wdogcount: u32;
    extern var _aon_domain_wdogs: u32;
    extern var _aon_domain_wdogfeed: u32;
    extern var _aon_domain_wdogkey: u32;
    extern var _aon_domain_wdogcmp0: u32;
    extern var _aon_domain_rtccfg: u32;
    extern var _aon_domain_rtccountlo: u32;
    extern var _aon_domain_rtccounthi: u32;
    extern var _aon_domain_rtcs: u32;
    extern var _aon_domain_rtccmp0: u32;
    extern var _aon_domain_lfrosccfg: u32;
    extern var _aon_domain_lfclkmux: u32;
    extern var _aon_domain_backup_start: u32;
    extern var _aon_domain_backup_count: u32;
    extern var _aon_domain_pmuwakeup_start: u32;
    extern var _aon_domain_pmuwakeup_count: u32;
    extern var _aon_domain_pmusleep_start: u32;
    extern var _aon_domain_pmusleep_count: u32;
    extern var _aon_domain_pmuie: u32;
    extern var _aon_domain_pmucause: u32;
    extern var _aon_domain_pmusleep: u32;
    extern var _aon_domain_pmukey: u32;
    extern var _aon_domain_SiFiveBandgap: u32;
    extern var _aon_domain_aoncfg: u32;
};

const clint_map = struct {
    extern var _clint_start: u32;
    extern var _clint_hart0_msip: u32;
    extern var _clint_hart0_mtimecmp: u64;
    extern var _clint_hart0_mtime: u64;
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
    input: Atomic(u32),
    in_enable: Atomic(u32),
    out_enable: Atomic(u32),
    output: Atomic(u32),
    pull_up_enable: Atomic(u32),
    drive_strength: Atomic(u32),
    rise_irq_enable: Atomic(u32),
    rise_irq_pending: Atomic(u32),
    fall_irq_enable: Atomic(u32),
    fall_irq_pending: Atomic(u32),
    high_irq_enable: Atomic(u32),
    high_irq_pending: Atomic(u32),
    low_irq_enable: Atomic(u32),
    low_irq_pending: Atomic(u32),
    output_xor: Atomic(u32),
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
    const size = @ptrToInt(@ptrCast(*u32, &__itim_target_size));
    var dest = @ptrCast([*]u8, &__itim_target_start);
    var source = @ptrCast([*]u8, &__itim_source_start);

    @fence(.Acquire);
    mem.copy(u8, dest[0..size], source[0..size]);
}

pub const wait = wfi();

fn wfi() void {
    asm volatile ("wfi");
}

pub fn gpioPinOutput(pin: u5, enable: bool) void {
    const reg = @ptrCast(*GpioInst, &_periph_gpio_start);

    if (enable) {
        _ = reg.out_enable.bitSet(pin, .Acquire);
    } else {
        _ = reg.out_enable.bitReset(pin, .Acquire);
    }
}

pub fn gpioPinInput(pin: u5, enable: bool) void {
    const reg = @ptrCast(*GpioInst, &_periph_gpio_start);
    if (enable) {
        _ = reg.in_enable.bitSet(pin, .Acquire);
    } else {
        _ = reg.in_enable.bitReset(pin, .Acquire);
    }
}

pub fn gpioPinRiseIrq(pin: u5, irq: ?*Vector) void {
    const reg = @ptrCast(*GpioInst, &_periph_gpio_start);

    if (irq) |vec| {
        gpioVectorTable[pin] = vec;
        _ = reg.rise_irq_enable.bitSet(pin, .Acquire);
        plicIrqReg(pin + 8, true);
    } else {
        gpioVectorTable[pin] = null;
        _ = reg.rise_irq_enable.bitReset(pin, .Acquire);
        plicIrqReg(pin + 8, false);
    }
}

pub fn gpioPinToggle(pin: u5) void {
    var reg = @ptrCast(*GpioInst, &_periph_gpio_start);
    _ = reg.output.bitToggle(pin, .Acquire);
}

pub fn gpioPinRead(pin: u5) bool {
    var reg = @ptrCast(*GpioInst, &_periph_gpio_start);
    var in: u32 = @atomicLoad(u32, &reg.in_enable, .Acquire);

    return if (in & (@as(u32, 1) << pin) == 0) true else false;
}

fn plicIrqReg(irq_src: u32, on: bool) void {
    const reg = @ptrCast(*[2]Atomic(u32), &_periph_plic_hart0_enables); // TODO: Move away from hardcoded length.

    const idx = irq_src / 32;
    const off = @intCast(u5, irq_src % 32);

    if (on) {
        _ = reg[idx].bitSet(off, .Acquire);
    } else {
        _ = reg[idx].bitReset(off, .Acquire);
    }
}

pub fn setGpioPlicPriority(pin: u5, priority: u32) void {
    var prio_map = @ptrCast(*PlicPriorityMap, &_periph_plic_priority_start);
    @atomicStore(u32, &prio_map.gpio_pri[pin], priority, .Release);
}

pub fn setRtcPlicPriority(priority: u32) void {
    var prio_map = @ptrCast(*PlicPriorityMap, &_periph_plic_priority_start);
    @atomicStore(u32, &prio_map.aon_rtc_pri, priority, .Release);
}

pub fn disablePLIC() void {
    const size = comptime @sizeOf(PlicPriorityMap);
    const prio_map = @ptrCast(*[size]u32, &_periph_plic_priority_start);

    var idx: u32 = 0;
    while (idx < size) : (idx += 1) {
        prio_map[idx] = 0;
    }
}

pub fn sleep(loops: u32) void {
    var idx: u32 = 0;
    while (idx < loops) : (idx += 1) {
        asm volatile ("nop");
    }
}

pub fn clintGetCycleCount(hart: u32) u64 {
    const mtime = @ptrCast([*]volatile u64, &clint_map._clint_hart0_mtime);
    return mtime[hart];
}

pub fn clintSetTimeCmp(hart: u32, cycles: u64) void {
    const mtimecmp = @ptrCast([*]volatile u64, &clint_map._clint_hart0_mtimecmp);
    mtimecmp[hart] = cycles;
}

pub fn clintSetTimerIrq(vec: *Vector) void {
    clintTimerVector = vec;
}

pub fn rtcConfigure(scale: u3, continious: bool, irq_on: bool) void {
    const aon = @ptrCast(*Atomic(u32), &aon_map._aon_domain_rtccfg);

    const value: u32 = if (continious) flag(u32, 12) | scale else scale;
    _ = aon.store(value, .Release);

    if (irq_on) plicIrqReg(2, true);
}

pub fn rtcSetNextIrq(ticks: u32) void {
    const cmp = @ptrCast(*Atomic(u32), &aon_map._aon_domain_rtccmp0);
    _ = cmp.store(ticks, .Release);
}

pub fn rtcGetTickCount() u32 {
    const cs = @ptrCast(*Atomic(u32), &aon_map._aon_domain_rtcs);
    return cs.load(.Acquire);
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

pub fn enableInterrupts(software: bool, timer: bool, external: bool) void {
    var val: u32 = 0;

    if (software) val |= 0x0008;
    if (timer) val |= 0x0080;
    if (external) val |= 0x0800;

    _ = asm volatile (
        \\ csrw mie, a0
        :
        : [val] "{a0}" (val)
        : "memory", "a0"
    );
}

/// The base ISR that should be specified in the mtvec register.
/// Params: epc, cause, hart_id, status
fn vectorBase(_: u32, cause: u32, _: u32, _: u32) linksection(".fast") callconv(.C) void {
    if (isIrq(cause)) {
        switch (parseIrqCode(cause)) {
            .MachineExternal => plicIrqHandle(),
            .MachineTimer => clintTimerIrqHandle(),
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

fn clintTimerIrqHandle() void {
    if (clintTimerVector) |vec| {
        vec.isr();
    }
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
    _ = reg.rise_irq_pending.bitSet(@intCast(u5, pin), .Release);
}

pub const Vector = struct {
    vector: fn (*Self) void,

    const Self = @This();

    pub fn isr(self: *Self) void {
        self.vector(self);
    }
};

var gpioVectorTable = [_]?*Vector{null} ** 32;
var clintTimerVector: ?*Vector = null;

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
    hfrosccfg: Atomic(u32),
    hfxosccfg: Atomic(u32),
    pllcfg: Atomic(u32),
    plloutdiv: Atomic(u32),
    procmoncfg: Atomic(u32),
};

fn flag(comptime T: type, comptime bit: comptime_int) T {
    return @as(T, 1) << bit;
}

fn maxValue(comptime T: type) T {
    return @as(T, 1) << 8 * @sizeOf(T) - 1;
}

fn bits(comptime T: type, comptime from: comptime_int, comptime to: comptime_int) T {
    const length = from - to;
    const shift = @sizeOf(T) - length;
    return maxValue(T) << shift >> shift << from;
}

fn hfroscFrquency(prci: *PrciInst) u32 {
    // Get the required values.
    const hfrosc = prci.hfrosccfg.load(.Acquire);
    const trim = hfrosc & bits(u32, 16, 20);
    const div = hfrosc & bits(u32, 0, 5) + 1;

    // Get the trim frequency.
    const freq = trim * 1_125_000;

    // Final divide and return.
    return freq / div;
}

/// Calculates and returns the current operating frequency of the MCU hart.
/// FIXME: Needs to be verified carefully. Unchecked. No tests.
pub fn operatingFrequency() u32 {
    const prci = @ptrCast(*PrciInst, &_prci_start);

    const pll = prci.pllcfg.load(.Acquire);

    // NOTE: if pllref is:
    // 		1 - Get external oscilator freq.
    // 		0 - Get and calculate internal oscilator freq.
    // 	if pllbypass is:
    // 		1 - skip pll calc regardless
    // 		0 - if pllref is on, calculate PLL
    // 	if pllsel is:
    // 		1 - we use PLL (or bypassed).
    // 		0 - Use internal clock directly.

    const pllref_on = (pll & flag(u32, 17)) != 0;
    const pllsel_on = (pll & flag(u32, 16)) != 0;
    const pllbypass_on = (pll & flag(u32, 18)) != 0;

    // If internal oscilator is selected to drive the output directly,
    // get it's frequency and return the result immediately.
    if (!pllsel_on) {
        return hfroscFrquency(prci);
    }

    // PLL is used. If the external oscilator is used the frequency is fixed,
    // otherwise calculate the internal oscilator frquency and use that.
    // The external oscilator is intended to be high precision.
    const in_freq = if (pllref_on) 16 * 1_000_000 else hfroscFrquency(prci);

    // If PLL is bypassed, no further calculation is needed.
    if (pllbypass_on) return in_freq;

    // Get PLL scaler values.
    const pll_r = (pll & 0x00_03) + 1;
    const pll_f = 2 * (((pll & 0x01_F0) >> 4) + 1);
    const pll_q = (pll & 0x06_00) >> 10;

    // Calculate the true pllq and the output frequency.
    const q_val = @as(u32, 1) << @truncate(u5, pll_q);
    const pll_out = ((in_freq / pll_r) * pll_f) / q_val;

    // If final divider is enabled, calculate final frequency.
    const pll_div = prci.plloutdiv.load(.Acquire);
    if (pll_div & flag(u32, 8) == 0) {
        const pllOutDiv = pll_div & 0x00_1F;
        return pll_out / pllOutDiv;
    }

    return pll_out;
}

pub fn rtcFrequency() u32 {
    const lfoscmux = @ptrCast(*Atomic(u32), &aon_map._aon_domain_lfclkmux);
    const alt_clk_on = lfoscmux.load(.Acquire) & flag(u32, 0) != 0;
    return if (alt_clk_on) 32_768 else lfoscFrequency();
}

fn lfoscFrequency() u32 {
    const lfosccfg = @ptrCast(*Atomic(u32), &aon_map._aon_domain_lfrosccfg);
    const cfg = lfosccfg.load(.Acquire);
    const trim = cfg & bits(u32, 16, 20);
    const div = cfg & bits(u32, 0, 5) + 1;
}
