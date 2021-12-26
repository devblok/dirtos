const std = @import("std");
const mem = std.mem;
const FileSource = std.build.FileSource;
const Target = std.Target;
const Builder = std.build.Builder;
const CrossTarget = std.zig.CrossTarget;

const Arch = struct {
    name: []const u8,
    boot_asm: [][]const u8,
    ld_script: ?FileSource,
    target: CrossTarget,
};

pub fn build(b: *std.build.Builder) void {
    const arch = getArchTarget(b);
    const mode = b.standardReleaseOptions();

    const elf = b.addExecutable("dirtos", "src/main.zig");
    elf.emit_asm = .emit;
    elf.setTarget(arch.target);

    for (arch.boot_asm) |assembly| {
        elf.addAssemblyFile(assembly);
    }

    if (arch.ld_script) |ld_script| {
        elf.setLinkerScriptPath(ld_script);
    }

    elf.setBuildMode(mode);
    elf.link_function_sections = true;
    elf.install();

    const raw = b.addInstallRaw(elf, "aitvaras.bin", .{});
    raw.step.dependOn(b.getInstallStep());
    b.step("bin", "Generate binary blob for flashing.").dependOn(&raw.step);
}

var sifive_e31_assemblies = [_][]const u8{
    "bsp/sifive-hifive1-revb/boot.S",
    "bsp/sifive-hifive1-revb/scrub.S",
    "bsp/sifive-hifive1-revb/isr.S",
};

const emulation: Arch = .{
    .name = "Emulation mode",
    .boot_asm = &[_][]const u8{},
    .ld_script = null,
    .target = .{},
};

const sifive_e31: Arch = .{
    .name = "HiFive 1 Rev B DevKit",
    .boot_asm = sifive_e31_assemblies[0..],
    .ld_script = .{ .path = "bsp/sifive-hifive1-revb/default.lds" },
    .target = .{
        .cpu_arch = .riscv32,
        .os_tag = .freestanding,
        .abi = .none,
        .cpu_model = CrossTarget.CpuModel{
            .explicit = &Target.riscv.cpu.sifive_e31,
        },
    },
};

var blue_pill_assemblies = [_][]const u8{"bsp/stm32-blue-pill/boot.S"};
const blue_pill: Arch = .{
    .name = "STM32 BluePill (STM32F103C8T6)",
    .boot_asm = blue_pill_assemblies[0..],
    .ld_script = .{ .path = "bsp/stm32-blue-pill/default.lds" },
    .target = .{
        .cpu_arch = .thumb,
        .os_tag = .freestanding,
        .abi = .none,
        .cpu_model = CrossTarget.CpuModel{
            .explicit = &Target.arm.cpu.cortex_m3,
        },
    },
};

fn getArchTarget(b: *Builder) Arch {
    const target = b.option([]const u8, "target", "Target device.") orelse return emulation;

    if (mem.eql(u8, target, "sifive-e31")) {
        return sifive_e31;
    } else if (mem.eql(u8, target, "blue-pill")) {
        return blue_pill;
    } else {
        return emulation;
    }
}
