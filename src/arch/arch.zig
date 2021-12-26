const riscv = @import("./riscv.zig");

/// Puts cpu to sleep for given number of CPU cycles.
pub fn sleep(loops: u32) void {
    @call(.{ .modifier = .never_inline }, riscv.sleep, .{loops});
}

// Enable IRQ via MIE register.
pub const enableInterrupts = riscv.enableInterrupts;

// TODO: Remove reliance on RISC-V.
pub const plicIrqMask = riscv.plicIrqMask;

// GPIO setting functions.
pub const gpioPinInput = riscv.gpioPinInput;
pub const gpioPinOutput = riscv.gpioPinOutput;
pub const setGpioPlicPriority = riscv.setGpioPlicPriority;
pub const gpioPinRiseIrq = riscv.gpioPinRiseIrq;
pub const gpioPinRead = riscv.gpioPinRead;
pub const gpioPinToggle = riscv.gpioPinToggle;
pub const GpioVector = riscv.GpioVector;

// UART functions.
pub const UartError = riscv.UartError;
pub const uartInstanceCount = riscv.uartInstanceCount;
pub const uartSetBaudRate = riscv.uartSetBaudRate;
pub const uartReadByte = riscv.uartReadByte;
pub const uartConfigure = riscv.uartConfigure;
pub const uartWriteByte = riscv.uartWriteByte;
