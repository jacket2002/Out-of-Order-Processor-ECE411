// This class generates random valid RISC-V instructions to test your
// RISC-V cores.

class RandInst;
    // You will increment this number as you generate more random instruction
    // types. Once finished, NUM_TYPES should be 9, for each opcode type in
    // rv32i_opcode.
    /*
    CP2: 
        REG-REG 0110011
        REG-IMM 0010011
        LUI     0110111

    CP3 WILL INCLUDE THE REST, i.e. AUIPC, BR, JAL, JALR, LOADS, AND STORES. 9 TOTAL JUST LIKE VERIF
    */
    localparam NUM_TYPES = 8;

    // Note that the `instr_t` type is from ../pkg/types.sv, there are TODOs
    // you must complete there to fully define `instr_t`.
    rand instr_t instr;
    rand bit [NUM_TYPES-1:0] instr_type;

    // Make sure we have an even distribution of instruction types.
    constraint solve_order_c { solve instr_type before instr; }

    // Hint/TODO: you will need another solve_order constraint for funct3
    // to get 100% coverage with 500 calls to .randomize().
    rand bit [2:0] funct3;
    constraint solve_order_funct3_c {solve funct3 before instr; }

    // Pick one of the instruction types.
    constraint instr_type_c {
        $countones(instr_type) == 1; // Ensures one-hot.
    }

    rand bit [9:0] m_vs_i; // this will skew our generation to 90% non-mult, non-div, non-rem
    constraint instr_m_ext {
        $countones(m_vs_i) == 1;
    }

    // Constraints for actually generating instructions, given the type.
    // Again, see the instruction set listings to see the valid set of
    // instructions, and constrain to meet it. Refer to ../pkg/types.sv
    // to see the typedef enums.

    constraint instr_c {
        instr.r_type.funct3 == funct3;
        // Reg-imm instructions
        instr_type[0] -> { // means if we get the one hot where LSB is 1, then we need to constrain as such:
            instr.i_type.opcode == op_b_imm; // this one hot means reg-imm
            // Implies syntax: if funct3 is arith_f3_sr, then funct7 must be
            // one of two possibilities.
            instr.i_type.funct3 == arith_f3_sr -> {
                // Use r_type here to be able to constrain funct7.
                instr.r_type.funct7 inside {base, variant};
            }

            // This if syntax is equivalent to the implies syntax above
            // but also supports an else { ... } clause.
            if (instr.i_type.funct3 == arith_f3_sll) {
                instr.r_type.funct7 == base;
            }
        }

        // Reg-reg instructions 7'b0110011 (Can be either I-extension or M-extension)
        instr_type[1] -> {
            instr.r_type.opcode == op_b_reg;
            if (m_vs_i[9]) { // if the last bit is one, constrain to multiply inst.
                instr.r_type.funct7 == mul_div_rem; 
                // everything else can be randomized
            } else {
                instr.r_type.funct3 == arith_f3_add -> {
                    instr.r_type.funct7 inside {base, variant};
                }

                instr.r_type.funct3 == arith_f3_sll -> {
                    instr.r_type.funct7 == base;
                }

                instr.r_type.funct3 == arith_f3_slt -> {
                    instr.r_type.funct7 == base;
                }

                instr.r_type.funct3 == arith_f3_sltu -> {
                    instr.r_type.funct7 == base;
                }

                instr.r_type.funct3 == arith_f3_xor -> {
                    instr.r_type.funct7 == base;
                }

                instr.r_type.funct3 == arith_f3_sr -> {
                    instr.r_type.funct7 inside {base, variant};
                }

                instr.r_type.funct3 == arith_f3_or -> {
                    instr.r_type.funct7 == base;
                }

                instr.r_type.funct3 == arith_f3_and -> {
                    instr.r_type.funct7 == base;
                }
            }
        }

        // load upper immediate instructions 7'b0110111
        instr_type[2] -> {
            instr.j_type.opcode == op_b_lui;
        }

        // BELOW ARE CP3 INSTRUCTIONS
        // Store instructions -- these are easy to constrain! 7'b0100011
        instr_type[3] -> {
            instr.s_type.opcode == op_b_store;
            instr.s_type.funct3 inside {store_f3_sb, store_f3_sh, store_f3_sw};

            instr.s_type.funct3 == store_f3_sb -> {
                instr.s_type.rs1 == 5'b00000;
                instr.s_type.imm_s_bot[4:2] == '0;
            }
            instr.s_type.funct3 == store_f3_sh -> {
                instr.s_type.rs1 == 5'b00000;
                instr.s_type.imm_s_bot[0] == 1'b0;
                instr.s_type.imm_s_bot[4:2] == '0;
            }
            instr.s_type.funct3 == store_f3_sw -> {
                instr.s_type.rs1 == 5'b00000;
                instr.s_type.imm_s_bot[1:0] == 2'b00;
                instr.s_type.imm_s_bot[4:2] == '0;
            }
        }

        // // Load instructions 7'b0000011
        instr_type[4] -> {
            instr.i_type.opcode == op_b_load;
            // TODO: Constrain funct3 as well.
            instr.i_type.funct3 inside {load_f3_lb, load_f3_lh, load_f3_lw, load_f3_lbu, load_f3_lhu};
            instr.i_type.funct3 == load_f3_lb -> {
                instr.i_type.rs1 == 5'b00000;
                instr.i_type.i_imm[11:2] == '0;
            }
            instr.i_type.funct3 == load_f3_lbu -> {
                instr.i_type.rs1 == 5'b00000;
                instr.i_type.i_imm[11:2] == '0;
            }
            
            instr.i_type.funct3 == load_f3_lh -> {
                instr.i_type.rs1 == 5'b00000;
                instr.i_type.i_imm[0] == 1'b0;
                instr.i_type.i_imm[11:2] == '0;
            }

            instr.i_type.funct3 == load_f3_lhu -> {
                instr.i_type.rs1 == 5'b00000;
                instr.i_type.i_imm[0] == 1'b0;
                instr.i_type.i_imm[11:2] == '0;
            }

            instr.i_type.funct3 == load_f3_lw -> {
                instr.i_type.rs1 == 5'b00000;
                instr.i_type.i_imm[1:0] == 2'b00;
                instr.i_type.i_imm[11:2] == '0;
            }
        }

        // Branch instructions 7'b1100011
        instr_type[5] -> {
            instr.b_type.opcode == op_b_br;
            instr.b_type.funct3 inside {branch_f3_beq, branch_f3_bne, branch_f3_blt, branch_f3_bge, branch_f3_bltu, branch_f3_bgeu};
            instr.word[8] == 1'b0;
        }
    
        // // Jump-and-Link Register Instructions  7'b1100111
        // instr_type[5] -> {
        //     instr.i_type.opcode == op_b_jalr;
        //     instr.i_type.funct3 == 3'b000;
        // }

        // Jump-and-Link Instructions 7'b1101111
        instr_type[6] -> {
            instr.j_type.opcode == op_b_jal;
            instr.word[21] == 1'b0;
        }

        // add upper immediate PC Instructions 7'b0010111
        instr_type[7] -> {
            instr.j_type.opcode == op_b_auipc;
        }

        
    }

    `include "../../hvl/vcs/instr_cg.svh"

    // Constructor, make sure we construct the covergroup.
    function new();
        instr_cg = new();
    endfunction : new

    // Whenever randomize() is called, sample the covergroup. This assumes
    // that every time you generate a random instruction, you send it into
    // the CPU.
    function void post_randomize();
        instr_cg.sample(this.instr);
    endfunction : post_randomize

    // A nice part of writing constraints is that we get constraint checking
    // for free -- this function will check if a bit vector is a valid RISC-V
    // instruction (assuming you have written all the relevant constraints).
    function bit verify_valid_instr(instr_t inp);
        bit valid = 1'b0;
        this.instr = inp;
        for (int i = 0; i < NUM_TYPES; ++i) begin
            this.instr_type = 1 << i;
            if (this.randomize(null)) begin
                valid = 1'b1;
                break;
            end
        end
        return valid;
    endfunction : verify_valid_instr

endclass : RandInst
