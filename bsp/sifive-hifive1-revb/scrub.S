.section .init

.option push
.option norelax

/* Function to zero-scrub specified memory
 * a0 : start address for zero-scrub
 * a1 : size memory region size in bytes
 */
.global mem_scrub
.type mem_scrub, @function
mem_scrub:

    /* Disable machine interrupts,
    restore previous mstatus value at exit */
    li      a3, 8
    csrrc   t1, mstatus, a3

#if __riscv_xlen == 32
    addi    t0, x0, 4
1:
    blt     a1, t0, 2f
    andi    a2, a0, 3
    beqz    a2, 3f
2:
    sb      x0, 0(a0)
    addi    a0, a0, 1
    addi    a1, a1, -1
    bgtz    a1, 1b
    csrw    mstatus, t1
    ret
3:
    sw      x0, 0(a0)
    addi    a0, a0, 4
    addi    a1, a1, -4
    bgtz    a1, 1b
    csrw    mstatus, t1
    ret
#else
    addi    t0, x0, 8
1:
    blt     a1, t0, 2f
    andi    a2, a0, 7
    beqz    a2, 3f
2:
    sb      x0, 0(a0)
    addi    a0, a0, 1
    addi    a1, a1, -1
    bgtz    a1, 1b
    csrw    mstatus, t1
    ret
3:
    sd      x0, 0(a0)
    addi    a0, a0, 8
    addi    a1, a1, -8
    bgtz    a1, 1b
    csrw    mstatus, t1
    ret
#endif

.type __memory_scrub, @function
__memory_scrub:
/* Zero out specified memory regions */
1:
#if __riscv_xlen == 32
    sw      x0, 0(t1)
    addi    t1, t1, 4
    blt     t1, t2, 1b
#else
    sd      x0, 0(t1)
    addi    t1, t1, 8
    blt     t1, t2, 1b
#endif
    ret

/*
 * Initialize memories to zero
 * This must be called before setting up any stack(s)
 */
.weak __eccscrub_bit
.global __before_start
.type __before_start, @function
__before_start:
    /* Save caller ra */
    mv      s0, ra

    la      t0, __eccscrub_bit
    beqz    t0, skip_scrub

    la      t0, __boot_hart
    csrr    a5, mhartid

    /* Disable machine interrupts to be safe */
    li      a3, 8
    csrc    mstatus, a3

    /* Zero out per hart stack */
    mv      t1, sp
    la      t2, STACK_SIZE
    add     t2, t2, sp
    beq     t1, t2, 1f
    jal     __memory_scrub
1:
    bne     a5, t0, skip_scrub

    /* Zero out data segment */
    la      t1, __dtim_mem_start
    la      t2, __dtim_mem_end
    beq     t1, t2, 1f
    jal     __memory_scrub
1:
    /* Zero out itim memory */
    la      t1, __itim_mem_start
    la      t2, __itim_mem_end
    beq     t1, t2, skip_scrub
    jal     __memory_scrub

skip_scrub:
    /* Restore caller ra */
    mv      ra, s0
    ret

.option pop
