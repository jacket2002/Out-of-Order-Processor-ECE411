mem_test.s:
.align 4
.section .text
.globl _start
_start:
    li x1, 10
    li x2, 0
    li x3, 0

    auipc x4, 0 # br_fu, write 1eceb00c. 
    lui x5, 0x2eceb # alu_fu
    sw x4, 0(x5)
    lw x4, 0(x5)
    slti x0, x0, -256