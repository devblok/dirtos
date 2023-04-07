const builtin = @import("builtin");
const Allocator = @import("std").mem.Allocator;

const arch = switch (builtin.target.cpu.arch) {
    .riscv32 => @import("./riscv.zig"),
    else => @compileError("unsupported"),
};

pub const init = arch.init;
pub const wait = arch.wait;
pub const config = arch.config;

// Clock related functions.
pub const clockCounter = arch.clintGetCycleCount;
pub const setInterruptOnClock = arch.clintSetTimeCmp;
pub const setupSchedulerIsr = arch.setupSchedulerIsr;

/// Puts cpu to sleep for given number of CPU cycles.
pub fn sleep(loops: u32) void {
    @call(.{ .modifier = .never_inline }, arch.sleep, .{loops});
}

pub const getCoreID = arch.getHartID;

// Enable IRQ via MIE register.
pub const enableInterrupts = arch.enableInterrupts;

// TODO: Remove reliance on RISC-V.
pub const plicIrqMask = arch.plicIrqMask;

/// Function to obtain the current operating frequency.
pub const operatingFrequency = arch.operatingFrequency;

// GPIO setting functions.
pub const gpioPinInput = arch.gpioPinInput;
pub const gpioPinOutput = arch.gpioPinOutput;
pub const setGpioPlicPriority = arch.setGpioPlicPriority;
pub const gpioPinRiseIrq = arch.gpioPinRiseIrq;
pub const gpioPinRead = arch.gpioPinRead;
pub const gpioPinToggle = arch.gpioPinToggle;
pub const Vector = arch.Vector;

// UART errors.
pub const UartError = arch.UartError;
pub const UartWriteError = arch.UartWriteError;
pub const UartReadError = arch.UartReadError;

// UART functions.
pub const uartInstanceCount = arch.uartInstanceCount;
pub const uartSetBaudRate = arch.uartSetBaudRate;
pub const uartConfigure = arch.uartConfigure;
pub const uartReadBuffer = arch.uartReadBuffer;
pub const uartWriteBuffer = arch.uartWriteBuffer;
