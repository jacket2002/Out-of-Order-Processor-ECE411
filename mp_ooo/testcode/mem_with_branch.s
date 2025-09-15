branch_test.s:
.align 4
.section .text
.globl _start
_start:
    li x1, 5
    li x2, 0
    li x3, 0

    lui x4, 0x2eceb
    sw x1, 0(x4) # store 10 into 0x2eceb000

loop_start:
    lw x5, 0(x4)
    addi x5, x5, -1
    sw x5, 0(x4)
    bgt x5, x2, loop_start
    
    slti x0, x0, -256 # this is the magic instruction to end the simulation