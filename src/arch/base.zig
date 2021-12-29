const builtin = @import("builtin");
const arch = switch (builtin.target.cpu) {
    .riscv => @import("./riscv.zig"),
    else => @compileError("unsupported"),
};

pub const page_allocator = if (builtin.target.isWasm())
    Allocator{
        .ptr = undefined,
        .vtable = &WasmPageAllocator.vtable,
    }
else if (builtin.target.os.tag == .freestanding)
    root.os.heap.page_allocator
else
    Allocator{
        .ptr = undefined,
        .vtable = &PageAllocator.vtable,
    };
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
