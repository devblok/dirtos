.section .init

.option push
.option norelax

.global _isr
_isr:

    /*li t0, 0xFFFFFFFF
    la t1, _gpio_out_en
    sw t0, 0(t1)*/

    /*li t0, 0xFFFFFFFF
    la t1, _gpio_out_val
    sw t0, 0(t1)*/


    csrw mscratch, sp
    la sp, _isr_sp

    csrr a0, mepc
    csrr a1, mcause
    csrr a2, mhartid
    csrr a3, mstatus
    call _kernel_isr

    csrr sp, mscratch
    mret

.option pop
