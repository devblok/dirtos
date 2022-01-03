OUTPUT_ARCH("riscv")

ENTRY(_start)

MEMORY
{
    itim (rwx)  : ORIGIN = 0x8000000,  LENGTH = 0x2000
    ram  (rw)   : ORIGIN = 0x80000000, LENGTH = 0x4000
    rom  (rx)   : ORIGIN = 0x20010000, LENGTH = 0x6a120
}

PHDRS 
{
    init PT_LOAD;
    text PT_LOAD;
    fast PT_LOAD;
    data PT_LOAD;
}

STACK_SIZE = 0x400;
ISR_STACK_SIZE = 0x200;

SECTIONS
{
    _aon_domain_start = 0x10000000;
    _aon_domain_end = 0x10000FFF;
    _aon_domain_wdogcfg = _aon_domain_start;
    _aon_domain_wdogcount = _aon_domain_start + 0x08;
    _aon_domain_wdogs = _aon_domain_start + 0x10;
    _aon_domain_wdogfeed = _aon_domain_start + 0x18;
    _aon_domain_wdogkey = _aon_domain_start + 0x1C;
    _aon_domain_wdogcmp0 = _aon_domain_start + 0x20;
    _aon_domain_rtccfg = _aon_domain_start + 0x40;
    _aon_domain_rtccountlo = _aon_domain_start + 0x48;
    _aon_domain_rtccounthi = _aon_domain_start + 0x4C;
    _aon_domain_rtcs = _aon_domain_start + 0x50;
    _aon_domain_rtccmp0 = _aon_domain_start + 0x60;
    _aon_domain_lfrosccfg = _aon_domain_start + 0x70;
    _aon_domain_lfclkmux = _aon_domain_start + 0x7C;
    _aon_domain_backup_start = _aon_domain_start + 0x80;
    _aon_domain_backup_count = 16; /* Should be 32, investigate other memory maps */
    _aon_domain_pmuwakeup_start = _aon_domain_start + 0x100;
    _aon_domain_pmuwakeup_count = 8;
    _aon_domain_pmusleep_start = _aon_domain_start + 0x120;
    _aon_domain_pmusleep_count = 8;
    _aon_domain_pmuie = _aon_domain_start + 0x140;
    _aon_domain_pmucause = _aon_domain_start + 0x144;
    _aon_domain_pmusleep = _aon_domain_start + 0x148;
    _aon_domain_pmukey = _aon_domain_start + 0x14C;
    _aon_domain_SiFiveBandgap = _aon_domain_start + 0x210;
    _aon_domain_aoncfg = _aon_domain_start + 0x300;

    _clint_start = 0x2000000;
    _clint_hart0_msip = _clint_start;
    _clint_hart0_mtimecmp = _clint_start + 0x4000;
    _clint_hart0_mtime = _clint_start + 0xBFF8;
    _clint_end = 0x200c000;

    _periph_gpio_start = 0x10012000;
    _periph_gpio_end = 0x10011FFF;

    _gpio_out_en = _periph_gpio_start + 0x08;
    _gpio_out_val = _periph_gpio_start + 0x0C;

    _periph_plic_priority_start = 0x0C000004;
    _periph_plic_priority_end = 0x0C0000D0;

    _periph_plic_priority_mask = 0x0C200000;

    _periph_plic_pending_start = 0x0C001000;
    _periph_plic_pending_end = 0x0C001004;

    _periph_plic_hart0_enables = 0x0C002000;

    _periph_plic_claim_reg = 0x0C200004;

    _periph_uart_instance_count = 2;
    _periph_uart_0_start = 0x10013000;
    _periph_uart_1_start = 0x10023000;

    _prci_start = 0x10008000;

    __boot_hart = 0;

    __chicken_bit = 1;
    __eccscrub_bit = 0;

    __dtim_mem_start = 0x80000000;
    __dtim_mem_end = 0x80000000 + 0x4000;
    __itim_mem_start = 0x8000000;
    __itim_mem_end = 0x8000000 + 0x2000;

    .init :
    {
        KEEP(*(.init.start))
        KEEP(*(.init*))
    } > rom : init

    .text :
    {
        KEEP(*(.vectors .vectors.*))
        *(.text*)
        *(.rodata*)
        _etext = .;
    } > rom : text

    /* ITIM (hot code) memory section */
    .fast :
    {
        . = ALIGN(8);
        _sfast = .;
        *(.fast .fast.*);
        . = ALIGN(8);
        _efast = .;
    } > itim AT > rom : fast

    PROVIDE( __itim_source_start = LOADADDR(.fast) );
    PROVIDE( __itim_target_start = ADDR(.fast) );
    PROVIDE( __itim_target_end = ADDR(.fast) + SIZEOF(.fast) );
    PROVIDE( __itim_target_size = SIZEOF(.fast) );
    
    .bss (NOLOAD) :
    {
        _sbss = .;
        *(.bss .bss.*)
        *(COMMON)
        _ebss = .;
    } > ram

    .stack (NOLOAD) :
    {
        . = ALIGN(16);
        _stack_start = .;
        . += STACK_SIZE;
        PROVIDE( _sp = . );
        . = ALIGN(16);
        _stack_end = .;
    } > ram

    .isrstack (NOLOAD) :
    {
        . = ALIGN(16);
        _isr_stack_start = .;
        . += ISR_STACK_SIZE;
        PROVIDE( _isr_sp = . );
        . = ALIGN(16);
        _isr_stack_end = .;
    } > ram

    .data :
    {
        . = ALIGN(8);
        _sdata = .;
        *(.data*);
        . = ALIGN(8);
        PROVIDE( __global_pointer$ = . + 0x800 );
        *(.sdata .sdata.* .sdata2.*)
        _edata = .;
    } > ram AT > rom : data

    _end = .;

    /DISCARD/ :
    {
        *(.eh_frame .eh_frame.*)
    }
}
