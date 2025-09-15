.align 4
.section .text
.globl _start
_start:
    # slti x0, x0, -256
    li x1, 10
    li x2, 0
    li x3, 0

    auipc x4, 0 # br_fu, write 1eceb00c. 
    lui x5, 0x1ffff # alu_fu
    
    sw x4, 0(x5) # mem_fu, write 1eceb00c into 2eceb000

    lw x4, 20(x5) # mem_fu
    lw x5, 20(x5) # mem_fu, load 2eceb000 into x5.
    lb x4, 24(x5) # load byte from 2eceb004 into x4.
    lh x4, 28(x5)
    
    lw x6, 20(x5)
    lhu x7, 20(x5)
    lbu x7, 21(x5)

    sw x4, 16(x5) # mem_fu
    sb x4, 18(x5)
    sh x4, 20(x5)

    slti x0, x0, -256