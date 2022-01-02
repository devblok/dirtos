const builtin = @import("builtin");
const Allocator = @import("std").mem.Allocator;

const arch = switch (builtin.target.cpu.arch) {
    .riscv32 => @import("./riscv.zig"),
    else => @compileError("unsupported"),
};

pub const init = arch.init;
pub const wait = arch.wait;
pub const config = arch.config;

/// Puts cpu to sleep for given number of CPU cycles.
pub fn sleep(loops: u32) void {
    @call(.{ .modifier = .never_inline }, arch.sleep, .{loops});
}

// Enable IRQ via MIE register.
pub const enableInterrupts = arch.enableInterrupts;

// TODO: Remove reliance on RISC-V.
pub const plicIrqMask = arch.plicIrqMask;

// GPIO setting functions.
pub const gpioPinInput = arch.gpioPinInput;
pub const gpioPinOutput = arch.gpioPinOutput;
pub const setGpioPlicPriority = arch.setGpioPlicPriority;
pub const gpioPinRiseIrq = arch.gpioPinRiseIrq;
pub const gpioPinRead = arch.gpioPinRead;
pub const gpioPinToggle = arch.gpioPinToggle;
pub const GpioVector = arch.GpioVector;

// UART functions.
pub const UartError = arch.UartError;
pub const uartInstanceCount = arch.uartInstanceCount;
pub const uartSetBaudRate = arch.uartSetBaudRate;
pub const uartReadByte = arch.uartReadByte;
pub const uartConfigure = arch.uartConfigure;
pub const uartWriteByte = arch.uartWriteByte;
