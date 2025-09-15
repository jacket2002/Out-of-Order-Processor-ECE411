branch_test.s:
.align 4
.section .text
.globl _start
_start:
    li x1, 10
    li x2, 0
    li x3, 0

loop_start:
    addi x3, x3, 1
    blt x3, x1, loop_start

ppl_branch:
    addi x2, x3, 100 
    
    auipc x1, 0 


    addi x2, x2, 100 

    lui x5, 0x2eceb 
    addi x4, x5, 52 
    # sw x2, 0(x4) 
    # sh x2, 0(x5) 
    jal x7, _label2
_label1:

    addi x1, x0, 6
    addi x3, x1, 8
    jal x7, _label3

_label2:
    addi x1, x0, 11
    and  x2, x2, x1
    jal x7, _label1
_label3:
    add x2, x2, x7
    addi x1, x1, -1
    addi x4, x4, 40
    # sw x2, 0(x4)
    # lw x11, 0(x4)
    bne x1, x0, _label3


    slti x0, x0, -256 # this is the magic instruction to end the simulation