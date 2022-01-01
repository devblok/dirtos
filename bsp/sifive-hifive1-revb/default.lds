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
