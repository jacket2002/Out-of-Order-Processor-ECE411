.align 4
.section .text
.globl _start
_start:
    li x9, 8
    lui x5, 0x92492      # Load upper 20 bits (x5 = 0x92492000)
    addi x5, x5, 0x493   # Add the lower 12 bits (x5 = 0x92492493)
    mulh x6, x9, x5
    slti x0, x0, -256
