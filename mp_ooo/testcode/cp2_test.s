cp2_test.s:
.align 4
.section .text
.globl _start
_start:
    li x1, 10
    li x2, 20
    li x3, 30
    li x4, 40
    li x5, 50
    li x6, 60
    li x7, 70
    li x8, 18
    li x9, 19
    li x10, 20
    li x11, 21
    li x12, 22
    li x13, 23
    li x14, 24
    li x15, 25
    li x16, 26
    li x17, 10
    li x18, 20
    li x19, 30
    li x20, 40
    li x21, 50
    li x22, 60
    li x23, 70
    li x24, 18
    li x25, 19
    li x26, 20
    li x27, 21
    li x28, 22
    li x29, 23
    li x30, 24
    li x31, 25


    li x1, 10
    li x2, 20
    li x3, 30
    li x4, 40
    li x5, 50
    li x6, 60
    li x7, 70
    li x8, 18
    li x9, 19
    li x10, 20
    li x11, 21
    li x12, 22
    li x13, 23
    li x14, 24
    li x15, 25
    li x16, 26
    li x17, 10
    li x18, 20
    li x19, 30
    li x20, 40
    li x21, 50
    li x22, 60
    li x23, 70
    li x24, 18
    li x25, 19
    li x26, 20
    li x27, 21
    li x28, 22
    li x29, 23
    li x30, 24
    li x31, 25
    li x1, 10
    li x2, 20
    li x3, 30
    li x4, 40
    li x5, 50
    li x6, 60
    li x7, 70
    li x8, 18
    li x9, 19
    li x10, 20
    li x11, 21
    li x12, 22
    li x13, 23
    li x14, 24
    li x15, 25
    li x16, 26
    li x17, 10
    li x18, 20
    li x19, 30
    li x20, 40
    li x21, 50
    li x22, 60
    li x23, 70
    li x24, 18
    li x25, 19
    li x26, 20
    li x27, 21
    li x28, 22
    li x29, 23
    li x30, 24
    li x31, 25
    li x1, 10
    li x2, 20
    li x3, 30
    li x4, 40
    li x5, 50
    li x6, 60
    li x7, 70
    li x8, 18
    li x9, 19
    li x10, 20
    li x11, 21
    li x12, 22
    li x13, 23
    li x14, 24
    li x15, 25
    li x16, 26
    li x17, 10
    li x18, 20
    li x19, 30
    li x20, 40
    li x21, 50
    li x22, 60
    li x23, 70
    li x24, 18
    li x25, 19
    li x26, 20
    li x27, 21
    li x28, 22
    li x29, 23
    li x30, 24
    li x31, 25

    add x19, x19, x19
    add x19, x19, x19
    add x19, x19, x19
    add x19, x19, x19
    add x19, x19, x19
    add x19, x19, x19
    add x19, x19, x19
    add x19, x19, x19
    
  

# why not commited??
    li x17, 27
    li x18, 28

    div x3, x1, x1


    addi x1, x20, 100
    addi x2, x21, 1
    mul x3, x1, x2 #050
    mul x3, x1, x2 #054
    mul x5, x3, x3 #058
    mul x6, x5, x1 #5c
    
    mul x6, x6, x1 #060 lost
    mul x6, x6, x2 #064
    remu x10, x6, x5 #068
    mul x6, x6, x0 #06c lost
    
    mul x3, x1, x2 #050
    mul x3, x1, x2 #054
    mul x5, x3, x3 #058
    mul x6, x5, x1 #5c
    
    mul x6, x6, x1 #060 lost
    mul x6, x6, x2 #064
    remu x10, x6, x5 #068
    mul x6, x6, x0 #06c lost

    mul x3, x1, x2 #050
    mul x3, x1, x2 #054
    mul x5, x3, x3 #058
    mul x6, x5, x1 #5c
    
    mul x6, x6, x1 #060 lost
    mul x6, x6, x2 #064
    remu x10, x6, x5 #068
    mul x6, x6, x0 #06c lost
    
    addi x4, x3, 0

    # # these instructions should  resolve before the multiply
    add x4, x5, x6
    xor x7, x8, x9
    sll x10, x11, x12
    and x13, x14, x15
    add x14, x15, x16



    li x1, 10
    and x2, x1, x1

    slti x0, x0, -256