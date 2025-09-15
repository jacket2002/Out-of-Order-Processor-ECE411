test.s:
.align 4
.section .text
.globl _start
_start:
    auipc x1, 0 #000
    addi x2, x3, 100 #004
    lui x5, 0x2eceb #008
    addi x4, x5, 53 #00c
    sb x2, 0(x4) #024 
    sh x2, 0(x5) #028
    sw x2, 4(x5)
    lb x6, 0(x4)
    lh x7, 0(x5)
    lw x8, 4(x5)
    lhu x9, 0(x5)
    lbu x10, 0(x4)
    lui x1, 0x1eceb
    addi    x5, x1, 0            # Add immediate: x5 = 100
    addi    x6, x0, 12
    sw      x6, 8(x5)             # Store word: store x6 at address x5 + 32
    lw      x6, 8(x5)              # Load word: load from address x5 + 8 into x6

    slli    x7, x6, 2              # Shift left logical immediate: x7 = x6 << 2 #10
    srli    x8, x7, 1              # Shift right logical immediate: x8 = x7 >> 1 #14
    xor     x9, x8, x7             # XOR: x9 = x8 ^ x7 #18
    and     x10, x9, x5            # AND: x10 = x9 & x5
    addi    x11, x10, -50          # Add immediate: x11 = x10 - 50
    ori     x12, x5, 0x123          # OR immediate: x12 = x5 | 0x123
    slt     x13, x12, x11           # Set less than: x13 = (x12 < x11)
    sll     x14, x13, x6            # Shift left logical: x14 = x13 << x6
    add     x15, x14, x5            # Add: x15 = x14 + x5
    andi    x16, x15, 0x111         # AND immediate: x16 = x15 & 0xabc
    lbu     x17, 8(x5)     # Load byte unsigned: load from memory at address 0x1eceb000 + x5
    sb      x17, 11(x6)     # Store byte: store x17 at address 0x1eceb004 + x6
    sltu    x21, x6, x8             # Set less than unsigned: x21 = (x6 < x8)
    lhu     x22, 10(x5)     # Load halfword unsigned: load from address 0x1eceb100 + x9
    sh      x22, -4(x5)    # Store halfword: store x22 at address 0x1eceb200 + x10
    addi    x23, x0, 0x100          # Add immediate: x23 = 0 + 0x100
    slti    x25, x12, 0x100         # Set less than immediate: x25 = (x12 < 0x100)
    auipc   x26, 0x99         # Add upper immediate to PC: x26 = PC + 0x1eceb000

    auipc x1, 0 #000
    addi x2, x3, 100 #004
    lui x5, 0x2eceb #008
    addi x4, x5, 53 #00c
    sb x2, 0(x4) #024 
    sh x2, 0(x5) #028
    sw x2, 4(x5)
    lb x6, 0(x4)
    lh x7, 0(x5)
    lw x8, 4(x5)
    lhu x9, 0(x5)
    lbu x10, 0(x4)
    lui x1, 0x1eceb
    addi    x5, x1, 0            # Add immediate: x5 = 100
    addi    x6, x0, 12
    sw      x6, 8(x5)             # Store word: store x6 at address x5 + 32
    lw      x6, 8(x5)              # Load word: load from address x5 + 8 into x6

    slli    x7, x6, 2              # Shift left logical immediate: x7 = x6 << 2 #10
    srli    x8, x7, 1              # Shift right logical immediate: x8 = x7 >> 1 #14
    xor     x9, x8, x7             # XOR: x9 = x8 ^ x7 #18
    and     x10, x9, x5            # AND: x10 = x9 & x5
    addi    x11, x10, -50          # Add immediate: x11 = x10 - 50
    ori     x12, x5, 0x123          # OR immediate: x12 = x5 | 0x123
    slt     x13, x12, x11           # Set less than: x13 = (x12 < x11)
    sll     x14, x13, x6            # Shift left logical: x14 = x13 << x6
    add     x15, x14, x5            # Add: x15 = x14 + x5
    andi    x16, x15, 0x111         # AND immediate: x16 = x15 & 0xabc
    lbu     x17, 8(x5)     # Load byte unsigned: load from memory at address 0x1eceb000 + x5
    sb      x17, 11(x6)     # Store byte: store x17 at address 0x1eceb004 + x6
    sltu    x21, x6, x8             # Set less than unsigned: x21 = (x6 < x8)
    lhu     x22, 10(x5)     # Load halfword unsigned: load from address 0x1eceb100 + x9
    sh      x22, -4(x5)    # Store halfword: store x22 at address 0x1eceb200 + x10
    addi    x23, x0, 0x100          # Add immediate: x23 = 0 + 0x100
    slti    x25, x12, 0x100         # Set less than immediate: x25 = (x12 < 0x100)
    auipc   x26, 0x99         # Add upper immediate to PC: x26 = PC + 0x1eceb000

    auipc x1, 0 #000
    addi x2, x3, 100 #004
    lui x5, 0x2eceb #008
    addi x4, x5, 53 #00c
    sb x2, 0(x4) #024 
    sh x2, 0(x5) #028
    sw x2, 4(x5)
    lb x6, 0(x4)
    lh x7, 0(x5)
    lw x8, 4(x5)
    lhu x9, 0(x5)
    lbu x10, 0(x4)
    lui x1, 0x1eceb
    addi    x5, x1, 0            # Add immediate: x5 = 100
    addi    x6, x0, 12
    sw      x6, 8(x5)             # Store word: store x6 at address x5 + 32
    lw      x6, 8(x5)              # Load word: load from address x5 + 8 into x6

    slli    x7, x6, 2              # Shift left logical immediate: x7 = x6 << 2 #10
    srli    x8, x7, 1              # Shift right logical immediate: x8 = x7 >> 1 #14
    xor     x9, x8, x7             # XOR: x9 = x8 ^ x7 #18
    and     x10, x9, x5            # AND: x10 = x9 & x5
    addi    x11, x10, -50          # Add immediate: x11 = x10 - 50
    ori     x12, x5, 0x123          # OR immediate: x12 = x5 | 0x123
    slt     x13, x12, x11           # Set less than: x13 = (x12 < x11)
    sll     x14, x13, x6            # Shift left logical: x14 = x13 << x6
    add     x15, x14, x5            # Add: x15 = x14 + x5
    andi    x16, x15, 0x111         # AND immediate: x16 = x15 & 0xabc
    lbu     x17, 8(x5)     # Load byte unsigned: load from memory at address 0x1eceb000 + x5
    sb      x17, 11(x6)     # Store byte: store x17 at address 0x1eceb004 + x6
    sltu    x21, x6, x8             # Set less than unsigned: x21 = (x6 < x8)
    lhu     x22, 10(x5)     # Load halfword unsigned: load from address 0x1eceb100 + x9
    sh      x22, -4(x5)    # Store halfword: store x22 at address 0x1eceb200 + x10
    addi    x23, x0, 0x100          # Add immediate: x23 = 0 + 0x100
    slti    x25, x12, 0x100         # Set less than immediate: x25 = (x12 < 0x100)
    auipc   x26, 0x99         # Add upper immediate to PC: x26 = PC + 0x1eceb000



    # forwarding test
    addi x2, x3, 100 #000
    lui x5, 0x2eceb  #004
    sw x2, 0(x5)     #008
    lw x4, 0(x5)     #00c
    addi x6, x4, 1   #010
    addi x7, x4, 16  #014
    lui x10, 0x2eceb #018
    lui x11, 0x2eceb #018
    lui x12, 0x2eceb #018

    # branch program
    lui x1, 0x1eceb #0
    addi x3, x0, 0 #4
    addi x2, x0, 10 #8
.beginAdd:
    addi x3, x3, 1 #C
    bne x3, x2, .beginAdd #10


    # jal
    lui x2, 0x1eceb
    jal x3, jumpAddr
    nop
    nop
    nop
    nop
    nop
jumpAddr:
    addi x4, x0, 100

    # jalr 
    lui x2, 0x1eceb #00
    addi x2, x2, 16 #04
    jalr x3, x2, 0 #08
    addi x4, x0, 54 #0c
    addi x9, x4, 40 #10
    sw x9, 0(x2) #14

    addi x2, x2, 100
    lui x3, 0x1eceb 
    sw x2, 0(x3)
    addi x6, x2, 4
    lw x5, 0(x3)
    add x7, x5, x6
    slti x0, x0, -256 # 014 this is the magic instruction to end the simulation

auipc x1, 0 #000
    addi x2, x3, 100 #004
    lui x5, 0x2eceb #008
    addi x4, x5, 53 #00c
    sb x2, 0(x4) #024 
    sh x2, 0(x5) #028
    sw x2, 4(x5)
    lb x6, 0(x4)
    lh x7, 0(x5)
    lw x8, 4(x5)
    lhu x9, 0(x5)
    lbu x10, 0(x4)
    lui x1, 0x1eceb
    addi    x5, x1, 0            # Add immediate: x5 = 100
    addi    x6, x0, 12
    sw      x6, 8(x5)             # Store word: store x6 at address x5 + 32
    lw      x6, 8(x5)              # Load word: load from address x5 + 8 into x6

    slli    x7, x6, 2              # Shift left logical immediate: x7 = x6 << 2 #10
    srli    x8, x7, 1              # Shift right logical immediate: x8 = x7 >> 1 #14
    xor     x9, x8, x7             # XOR: x9 = x8 ^ x7 #18
    and     x10, x9, x5            # AND: x10 = x9 & x5
    addi    x11, x10, -50          # Add immediate: x11 = x10 - 50
    ori     x12, x5, 0x123          # OR immediate: x12 = x5 | 0x123
    slt     x13, x12, x11           # Set less than: x13 = (x12 < x11)
    sll     x14, x13, x6            # Shift left logical: x14 = x13 << x6
    add     x15, x14, x5            # Add: x15 = x14 + x5
    andi    x16, x15, 0x111         # AND immediate: x16 = x15 & 0xabc
    lbu     x17, 8(x5)     # Load byte unsigned: load from memory at address 0x1eceb000 + x5
    sb      x17, 11(x6)     # Store byte: store x17 at address 0x1eceb004 + x6
    sltu    x21, x6, x8             # Set less than unsigned: x21 = (x6 < x8)
    lhu     x22, 10(x5)     # Load halfword unsigned: load from address 0x1eceb100 + x9
    sh      x22, -4(x5)    # Store halfword: store x22 at address 0x1eceb200 + x10
    addi    x23, x0, 0x100          # Add immediate: x23 = 0 + 0x100
    slti    x25, x12, 0x100         # Set less than immediate: x25 = (x12 < 0x100)
    auipc   x26, 0x99         # Add upper immediate to PC: x26 = PC + 0x1eceb000
    auipc x1, 0 #000
    addi x2, x3, 100 #004
    lui x5, 0x2eceb #008
    addi x4, x5, 53 #00c
    sb x2, 0(x4) #024 
    sh x2, 0(x5) #028
    sw x2, 4(x5)
    lb x6, 0(x4)
    lh x7, 0(x5)
    lw x8, 4(x5)
    lhu x9, 0(x5)
    lbu x10, 0(x4)
    lui x1, 0x1eceb
    addi    x5, x1, 0            # Add immediate: x5 = 100
    addi    x6, x0, 12
    sw      x6, 8(x5)             # Store word: store x6 at address x5 + 32
    lw      x6, 8(x5)              # Load word: load from address x5 + 8 into x6

    slli    x7, x6, 2              # Shift left logical immediate: x7 = x6 << 2 #10
    srli    x8, x7, 1              # Shift right logical immediate: x8 = x7 >> 1 #14
    xor     x9, x8, x7             # XOR: x9 = x8 ^ x7 #18
    and     x10, x9, x5            # AND: x10 = x9 & x5
    addi    x11, x10, -50          # Add immediate: x11 = x10 - 50
    ori     x12, x5, 0x123          # OR immediate: x12 = x5 | 0x123
    slt     x13, x12, x11           # Set less than: x13 = (x12 < x11)
    sll     x14, x13, x6            # Shift left logical: x14 = x13 << x6
    add     x15, x14, x5            # Add: x15 = x14 + x5
    andi    x16, x15, 0x111         # AND immediate: x16 = x15 & 0xabc
    lbu     x17, 8(x5)     # Load byte unsigned: load from memory at address 0x1eceb000 + x5
    sb      x17, 11(x6)     # Store byte: store x17 at address 0x1eceb004 + x6
    sltu    x21, x6, x8             # Set less than unsigned: x21 = (x6 < x8)
    lhu     x22, 10(x5)     # Load halfword unsigned: load from address 0x1eceb100 + x9
    sh      x22, -4(x5)    # Store halfword: store x22 at address 0x1eceb200 + x10
    addi    x23, x0, 0x100          # Add immediate: x23 = 0 + 0x100
    slti    x25, x12, 0x100         # Set less than immediate: x25 = (x12 < 0x100)
    auipc   x26, 0x99         # Add upper immediate to PC: x26 = PC + 0x1eceb000
    auipc x1, 0 #000
    addi x2, x3, 100 #004
    lui x5, 0x2eceb #008
    addi x4, x5, 53 #00c
    sb x2, 0(x4) #024 
    sh x2, 0(x5) #028
    sw x2, 4(x5)
    lb x6, 0(x4)
    lh x7, 0(x5)
    lw x8, 4(x5)
    lhu x9, 0(x5)
    lbu x10, 0(x4)
    lui x1, 0x1eceb
    addi    x5, x1, 0            # Add immediate: x5 = 100
    addi    x6, x0, 12
    sw      x6, 8(x5)             # Store word: store x6 at address x5 + 32
    lw      x6, 8(x5)              # Load word: load from address x5 + 8 into x6

    slli    x7, x6, 2              # Shift left logical immediate: x7 = x6 << 2 #10
    srli    x8, x7, 1              # Shift right logical immediate: x8 = x7 >> 1 #14
    xor     x9, x8, x7             # XOR: x9 = x8 ^ x7 #18
    and     x10, x9, x5            # AND: x10 = x9 & x5
    addi    x11, x10, -50          # Add immediate: x11 = x10 - 50
    ori     x12, x5, 0x123          # OR immediate: x12 = x5 | 0x123
    slt     x13, x12, x11           # Set less than: x13 = (x12 < x11)
    sll     x14, x13, x6            # Shift left logical: x14 = x13 << x6
    add     x15, x14, x5            # Add: x15 = x14 + x5
    andi    x16, x15, 0x111         # AND immediate: x16 = x15 & 0xabc
    lbu     x17, 8(x5)     # Load byte unsigned: load from memory at address 0x1eceb000 + x5
    sb      x17, 11(x6)     # Store byte: store x17 at address 0x1eceb004 + x6
    sltu    x21, x6, x8             # Set less than unsigned: x21 = (x6 < x8)
    lhu     x22, 10(x5)     # Load halfword unsigned: load from address 0x1eceb100 + x9
    sh      x22, -4(x5)    # Store halfword: store x22 at address 0x1eceb200 + x10
    addi    x23, x0, 0x100          # Add immediate: x23 = 0 + 0x100
    slti    x25, x12, 0x100         # Set less than immediate: x25 = (x12 < 0x100)
    auipc   x26, 0x99         # Add upper immediate to PC: x26 = PC + 0x1eceb000
    auipc x1, 0 #000
    addi x2, x3, 100 #004
    lui x5, 0x2eceb #008
    addi x4, x5, 53 #00c
    sb x2, 0(x4) #024 
    sh x2, 0(x5) #028
    sw x2, 4(x5)
    lb x6, 0(x4)
    lh x7, 0(x5)
    lw x8, 4(x5)
    lhu x9, 0(x5)
    lbu x10, 0(x4)
    lui x1, 0x1eceb
    addi    x5, x1, 0            # Add immediate: x5 = 100
    addi    x6, x0, 12
    sw      x6, 8(x5)             # Store word: store x6 at address x5 + 32
    lw      x6, 8(x5)              # Load word: load from address x5 + 8 into x6

    slli    x7, x6, 2              # Shift left logical immediate: x7 = x6 << 2 #10
    srli    x8, x7, 1              # Shift right logical immediate: x8 = x7 >> 1 #14
    xor     x9, x8, x7             # XOR: x9 = x8 ^ x7 #18
    and     x10, x9, x5            # AND: x10 = x9 & x5
    addi    x11, x10, -50          # Add immediate: x11 = x10 - 50
    ori     x12, x5, 0x123          # OR immediate: x12 = x5 | 0x123
    slt     x13, x12, x11           # Set less than: x13 = (x12 < x11)
    sll     x14, x13, x6            # Shift left logical: x14 = x13 << x6
    add     x15, x14, x5            # Add: x15 = x14 + x5
    andi    x16, x15, 0x111         # AND immediate: x16 = x15 & 0xabc
    lbu     x17, 8(x5)     # Load byte unsigned: load from memory at address 0x1eceb000 + x5
    sb      x17, 11(x6)     # Store byte: store x17 at address 0x1eceb004 + x6
    sltu    x21, x6, x8             # Set less than unsigned: x21 = (x6 < x8)
    lhu     x22, 10(x5)     # Load halfword unsigned: load from address 0x1eceb100 + x9
    sh      x22, -4(x5)    # Store halfword: store x22 at address 0x1eceb200 + x10
    addi    x23, x0, 0x100          # Add immediate: x23 = 0 + 0x100
    slti    x25, x12, 0x100         # Set less than immediate: x25 = (x12 < 0x100)
    auipc   x26, 0x99         # Add upper immediate to PC: x26 = PC + 0x1eceb000
    auipc x1, 0 #000
    addi x2, x3, 100 #004
    lui x5, 0x2eceb #008
    addi x4, x5, 53 #00c
    sb x2, 0(x4) #024 
    sh x2, 0(x5) #028
    sw x2, 4(x5)
    lb x6, 0(x4)
    lh x7, 0(x5)
    lw x8, 4(x5)
    lhu x9, 0(x5)
    lbu x10, 0(x4)
    lui x1, 0x1eceb
    addi    x5, x1, 0            # Add immediate: x5 = 100
    addi    x6, x0, 12
    sw      x6, 8(x5)             # Store word: store x6 at address x5 + 32
    lw      x6, 8(x5)              # Load word: load from address x5 + 8 into x6

    slli    x7, x6, 2              # Shift left logical immediate: x7 = x6 << 2 #10
    srli    x8, x7, 1              # Shift right logical immediate: x8 = x7 >> 1 #14
    xor     x9, x8, x7             # XOR: x9 = x8 ^ x7 #18
    and     x10, x9, x5            # AND: x10 = x9 & x5
    addi    x11, x10, -50          # Add immediate: x11 = x10 - 50
    ori     x12, x5, 0x123          # OR immediate: x12 = x5 | 0x123
    slt     x13, x12, x11           # Set less than: x13 = (x12 < x11)
    sll     x14, x13, x6            # Shift left logical: x14 = x13 << x6
    add     x15, x14, x5            # Add: x15 = x14 + x5
    andi    x16, x15, 0x111         # AND immediate: x16 = x15 & 0xabc
    lbu     x17, 8(x5)     # Load byte unsigned: load from memory at address 0x1eceb000 + x5
    sb      x17, 11(x6)     # Store byte: store x17 at address 0x1eceb004 + x6
    sltu    x21, x6, x8             # Set less than unsigned: x21 = (x6 < x8)
    lhu     x22, 10(x5)     # Load halfword unsigned: load from address 0x1eceb100 + x9
    sh      x22, -4(x5)    # Store halfword: store x22 at address 0x1eceb200 + x10
    addi    x23, x0, 0x100          # Add immediate: x23 = 0 + 0x100
    slti    x25, x12, 0x100         # Set less than immediate: x25 = (x12 < 0x100)
    auipc   x26, 0x99         # Add upper immediate to PC: x26 = PC + 0x1eceb000

