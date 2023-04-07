.section .init

.option push
.option norelax

.global _isr
_isr:

    /* Switch stacks to ISR stack. */
    csrw mscratch, sp
    la sp, _isr_sp

    /* Save argument registers. */
    addi sp, sp, -60
    sw a0, 0(sp)
    sw a1, 4(sp)
    sw a2, 8(sp)
    sw a3, 12(sp)
    sw a4, 16(sp)
    sw a5, 20(sp)
    sw a6, 24(sp)
    sw a7, 28(sp)
    sw s0, 32(sp)
    sw s1, 36(sp)
    sw s2, 40(sp)
    sw s3, 44(sp)
    sw s4, 48(sp)
    sw s5, 52(sp)
    sw s6, 56(sp)
    sw s7, 60(sp)

    csrr a0, mepc
    csrr a1, mcause
    csrr a2, mhartid
    csrr a3, mstatus
    call _kernel_isr

    /* Restore argument registers. */
    lw a0, 0(sp)
    lw a1, 4(sp)
    lw a2, 8(sp)
    lw a3, 12(sp)
    lw a4, 16(sp)
    lw a5, 20(sp)
    lw a6, 24(sp)
    lw a7, 28(sp)
    lw s0, 32(sp)
    lw s1, 36(sp)
    lw s2, 40(sp)
    lw s3, 44(sp)
    lw s4, 48(sp)
    lw s5, 52(sp)
    lw s6, 56(sp)
    lw s7, 60(sp)
    addi sp, sp, 60
    
    /* Restore normal stack. */
    csrr sp, mscratch
    mret

.option pop
