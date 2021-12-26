.section .init.start
.global _start
_start:
    .cfi_startproc
    .cfi_undefined ra

    /* Configure global pointer register */
.option push
.option norelax
    la gp, __global_pointer$
.option pop

    la t0, 1f
    csrw mtvec, t0
    la t0, __chicken_bit
    beqz t0, 1f
    csrwi 0x7C1, 0    

.align 4
1:    
    /* Setting up the callconv C environment */
    .weak _custom_stack_start
    la sp, _custom_stack_start
 
    /* Align stack */
    bne sp, zero, 1f
    la sp, _sp

1:

    la ra, __before_start
    beqz ra, 1f
    jalr ra

1:

/*.option push
.option norelax
    li t0, 0xFFFFFFFF
    la t1, _gpio_out_en
    sw t0, 0(t1)

    li t0, 0xFFFFFFFF
    la t1, _gpio_out_val
    sw t0, 0(t1)

.option pop
/*

    /* Register ISR handler */
    la t0, _isr
    csrw mtvec, t0    

    /* Enable interrupts */
    /*csrwi mie, 0010000000000000b*/
    li t0, 0x00000800
    /*csrw mie, t0*/

    li t0, 0x00000008
    csrw mstatus, t0
    
    /* Start the zig code */
    csrr a0, mhartid
    li a1, 0
    li a2, 0
    call _kernel_start

1:
    /* Spin endlessly if _start exits */   
    j 1b

    .cfi_endproc
    .end
