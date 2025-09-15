.align 4
.section .text
.globl _start
_start:
    li x1, 10
    li x2, 0
    li x3, 0
    li x7, 0
    lui x8, 7
    add x10, x7, x8

    li x7, 0xAFD
    lui x8, 6
    add x6, x7, x8


    auipc x4, 0 # br_fu, write 1eceb00c. 
    lui x5, 0x2eceb # alu_fu
    sw x4, 0(x5) # mem_fu, write 1eceb00c into 2eceb000
    mul x8, x10, x6
    lw x4, 0(x8) # mem_fu, load 2eceb004 into x4. # order a 
    sw x6, 0(x5)
    

    slti x0, x0, -256