module decode_rename_unit
import params::*;
import rv32i_types::*;
(
    // output to RAT
    output logic [4:0]   rs1_arc,
    output logic [4:0]   rs2_arc,
    
    // output to freelist. 
    output logic [4:0]   rd_arc,
    
    input logic [3:0]  branch_pattern_out,
    input logic [1:0]  saturating_counter_out,
    input logic [31:0] pc_target_predict_out,

    input logic   [31:0] instruction, // from instruction queue
    input logic [31:0] pc,
    input logic read_ack, // if nothing is read from the queue, disregard the decoded instruction. 
    input logic frli_read_ack,

    input logic [PHYSICAL_REG_FILE_LENGTH-1:0] ps1, // from RAT
    input logic [PHYSICAL_REG_FILE_LENGTH-1:0] ps2,
    input logic ps1_valid,
    input logic ps2_valid,

    // note: BRAT should also make update of RAT on this cycle
    // BRAT should be cleared on flush
    output logic control_inst_checkpoint,
    // input  logic BRAT_full,      WHEN BRAT is full, stop read from FREE_LIST and INST_Q
    // output logic decode_stall,

    input logic [PHYSICAL_REG_FILE_LENGTH-1:0] d_reg_rename, // popped from the free list
    output id_dis_stage_reg_t id_dis_stage_reg_next
);

// decode_stage_reg contain : which reservation station, required input for reservation station, immediate

    // break apart the instruction
    logic[4:0] rs1_s, rs2_s, rd_s;

    logic[2:0] funct3;
    logic[6:0] funct7;
    logic[6:0] opcode;
    logic [31:0] i_imm, s_imm, b_imm, u_imm, j_imm;
    logic valid_inst;

    assign funct3 = instruction[14:12];
    assign funct7 = instruction[31:25];
    assign opcode = instruction[6:0];
    assign i_imm  = {{21{instruction[31]}}, instruction[30:20]};
    assign s_imm  = {{21{instruction[31]}}, instruction[30:25], instruction[11:7]};
    assign b_imm  = {{20{instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0};
    assign u_imm  = {instruction[31:12], 12'h000};
    assign j_imm  = {{12{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:21], 1'b0};
    assign rs1_s  = instruction[19:15];
    assign rs2_s  = instruction[24:20];
    assign rd_s   = instruction[11:7];

    always_comb begin
        if (read_ack) begin
            rs1_arc = rs1_s;
            rs2_arc = rs2_s;
            rd_arc = (opcode == op_b_store || opcode == op_b_br)? '0: rd_s;
        end else begin
            rs1_arc = '0;
            rs2_arc = '0;
            rd_arc = '0;
        end
    end

    assign valid_inst = (read_ack && frli_read_ack ) || ((rd_arc=='0) &&read_ack) ? '1 : '0;
    
    always_comb begin
        if (valid_inst) begin
            control_inst_checkpoint = '0;
            if (opcode == op_b_br || opcode == op_b_jal || opcode == op_b_jalr) control_inst_checkpoint = '1;
        end
        else control_inst_checkpoint = '0;
    end

    always_comb begin
        id_dis_stage_reg_next.valid = valid_inst;
        id_dis_stage_reg_next.func_unit = alu_fu;
        id_dis_stage_reg_next.arch_d_reg = instruction[11:7]; // actual dest_reg, needed by dispatch for ROB
        id_dis_stage_reg_next.phys_d_reg = |rd_arc ? d_reg_rename : '0; // this is the physical register index which is written into by functional unit. 
        id_dis_stage_reg_next.phys_r1 = ps1; // these are the physical regs that will contain the mapped phys_regs 
        id_dis_stage_reg_next.phys_r2 = ps2;
        id_dis_stage_reg_next.phys_r1_valid = ps1_valid; // flags indicating that this physical register DOES NOT have the value needed to issue, MUST WAIT on CDB broadcast
        id_dis_stage_reg_next.phys_r2_valid = ps2_valid; 
        id_dis_stage_reg_next.imm_operand = '0; // needed by reg-imm insts, AUIPC, BR, JALR, JAL, LUI
        id_dis_stage_reg_next.use_imm = '0;
        id_dis_stage_reg_next.pc_val = pc; // needed by AUIPC, JALR, JAL, and BR
        id_dis_stage_reg_next.alu_op = alu_op_add; // needed by ALU to determine what operation to output. 
        id_dis_stage_reg_next.cmpop = branch_f3_beq;
        id_dis_stage_reg_next.mul_op = m_mul;
        id_dis_stage_reg_next.branch_inst = '1; 
        id_dis_stage_reg_next.cmp_or_alu = '0;
        id_dis_stage_reg_next.jalr_flag = '0;
        id_dis_stage_reg_next.jal_flag = '0;

        id_dis_stage_reg_next.load_store = '0; // load->0, store->1
        id_dis_stage_reg_next.load_type = load_f3_lb;
        id_dis_stage_reg_next.store_type = store_f3_sb;

        id_dis_stage_reg_next.branch_pattern = branch_pattern_out;
        id_dis_stage_reg_next.saturating_counter = saturating_counter_out;
        id_dis_stage_reg_next.pc_target_predict = pc_target_predict_out;
        
        // RVFI
        id_dis_stage_reg_next.rvfi_inst = instruction;
        id_dis_stage_reg_next.rvfi_pc_val = pc;
        id_dis_stage_reg_next.rvfi_rs1_s = rs1_s;
        id_dis_stage_reg_next.rvfi_rs2_s = rs2_s;
        id_dis_stage_reg_next.rvfi_rd_s = rd_s;
        id_dis_stage_reg_next.rvfi_mem_rmask = '0;
        id_dis_stage_reg_next.rvfi_mem_wmask = '0;
        unique case (opcode)
            op_b_lui: begin
                id_dis_stage_reg_next.imm_operand = u_imm;
                id_dis_stage_reg_next.phys_r1 = '0; // mark the r1 as invalid in order to use all 0's.
                id_dis_stage_reg_next.phys_r2 = '0;
                id_dis_stage_reg_next.phys_r1_valid = '1;
                id_dis_stage_reg_next.phys_r2_valid = '1;
                id_dis_stage_reg_next.use_imm = '1; 
                id_dis_stage_reg_next.rvfi_rs1_s = '0;
                id_dis_stage_reg_next.rvfi_rs2_s = '0;
            end

            op_b_auipc: begin
                id_dis_stage_reg_next.func_unit = br_fu;
                id_dis_stage_reg_next.imm_operand = u_imm; // auipc is U-type. 
                id_dis_stage_reg_next.branch_inst = '0;
                id_dis_stage_reg_next.cmp_or_alu = '0; // use the ALU result on CDB. 
                id_dis_stage_reg_next.phys_r1_valid = '1;
                id_dis_stage_reg_next.phys_r2_valid = '1;
                id_dis_stage_reg_next.use_imm = '1; // technically not needed b/c branch func unit defaults to using PC and imm. 
                id_dis_stage_reg_next.rvfi_rs1_s = '0;
                id_dis_stage_reg_next.rvfi_rs2_s = '0;
            end

            op_b_load: begin
                id_dis_stage_reg_next.func_unit = mem_fu;
                id_dis_stage_reg_next.imm_operand = i_imm;
                id_dis_stage_reg_next.load_store = '0;
                id_dis_stage_reg_next.phys_r2_valid = '1; // no need for r2
                unique case(funct3)
                    load_f3_lb  : id_dis_stage_reg_next.load_type = load_f3_lb;
                    load_f3_lh  : id_dis_stage_reg_next.load_type = load_f3_lh;
                    load_f3_lw  : id_dis_stage_reg_next.load_type = load_f3_lw;
                    load_f3_lbu : id_dis_stage_reg_next.load_type = load_f3_lbu;
                    load_f3_lhu : id_dis_stage_reg_next.load_type = load_f3_lhu;

                    default     : id_dis_stage_reg_next.load_type = load_f3_lb;       
                endcase
                id_dis_stage_reg_next.rvfi_rs2_s = '0;
            end

            op_b_store: begin
                id_dis_stage_reg_next.func_unit = mem_fu;
                id_dis_stage_reg_next.imm_operand = s_imm;
                id_dis_stage_reg_next.load_store = '1; 
                id_dis_stage_reg_next.phys_d_reg = '0; // no destination register, our regfile and free list already check for x0 and p0
                id_dis_stage_reg_next.arch_d_reg = '0;
                unique case(funct3)
                    store_f3_sb : id_dis_stage_reg_next.store_type = store_f3_sb;
                    store_f3_sh : id_dis_stage_reg_next.store_type = store_f3_sh;
                    store_f3_sw : id_dis_stage_reg_next.store_type = store_f3_sw;
                    default : id_dis_stage_reg_next.store_type = store_f3_sb;
                endcase

                id_dis_stage_reg_next.rvfi_rd_s = '0;
    
            end

            op_b_jal: begin
                id_dis_stage_reg_next.func_unit = ctrl_fu;
                id_dis_stage_reg_next.phys_r1_valid = '1;
                id_dis_stage_reg_next.phys_r2_valid = '1;
                id_dis_stage_reg_next.jal_flag = '1;
                id_dis_stage_reg_next.imm_operand = j_imm;
                id_dis_stage_reg_next.cmp_or_alu = '0;
                id_dis_stage_reg_next.rvfi_rs2_s  = '0;
                id_dis_stage_reg_next.rvfi_rs1_s  = '0;
            end

            op_b_jalr: begin
                id_dis_stage_reg_next.func_unit = ctrl_fu;
                id_dis_stage_reg_next.jalr_flag = '1;
                id_dis_stage_reg_next.imm_operand = i_imm;
                id_dis_stage_reg_next.phys_r2 = '0;
                id_dis_stage_reg_next.phys_r2_valid = '1;
                id_dis_stage_reg_next.cmp_or_alu = '0; 
                id_dis_stage_reg_next.rvfi_rs2_s  = '0;
            end

            op_b_br : begin
                id_dis_stage_reg_next.func_unit = ctrl_fu; 
                id_dis_stage_reg_next.arch_d_reg = '0; // no target. 
                id_dis_stage_reg_next.phys_d_reg = '0;
                id_dis_stage_reg_next.imm_operand = b_imm;
                id_dis_stage_reg_next.rvfi_rd_s = '0;
                unique case(funct3)
                    branch_f3_beq  : id_dis_stage_reg_next.cmpop = branch_f3_beq;
                    branch_f3_bne  : id_dis_stage_reg_next.cmpop = branch_f3_bne;
                    branch_f3_blt  : id_dis_stage_reg_next.cmpop = branch_f3_blt;
                    branch_f3_bge  : id_dis_stage_reg_next.cmpop = branch_f3_bge;
                    branch_f3_bltu : id_dis_stage_reg_next.cmpop = branch_f3_bltu;
                    branch_f3_bgeu : id_dis_stage_reg_next.cmpop = branch_f3_bgeu;
                    default: id_dis_stage_reg_next.cmpop = branch_f3_beq;
                endcase
            end

            op_b_imm: begin
                id_dis_stage_reg_next.rvfi_rs2_s = '0;
                id_dis_stage_reg_next.imm_operand = i_imm; // all insts use I-type immediate, and will all use RS1 and some operation against immediate
                id_dis_stage_reg_next.use_imm = '1;
                id_dis_stage_reg_next.phys_r2_valid = '1;
                unique case (funct3)
                    arith_f3_add: id_dis_stage_reg_next.alu_op = alu_op_add;
                    arith_f3_sll: id_dis_stage_reg_next.alu_op = alu_op_sll;
                    arith_f3_slt: begin
                        id_dis_stage_reg_next.cmpop = branch_f3_blt;
                        id_dis_stage_reg_next.func_unit = br_fu;
                        id_dis_stage_reg_next.branch_inst = '0; // use the CMP result on CDB
                        id_dis_stage_reg_next.cmp_or_alu = '1;
                    end
                    arith_f3_sltu: begin
                        id_dis_stage_reg_next.cmpop = branch_f3_bltu;
                        id_dis_stage_reg_next.func_unit = br_fu;
                        id_dis_stage_reg_next.branch_inst = '0; // use the CMP result on CDB
                        id_dis_stage_reg_next.cmp_or_alu = '1;
                    end
                    arith_f3_xor: id_dis_stage_reg_next.alu_op = alu_op_xor;
                    arith_f3_sr: begin
                        if (funct7[5]) id_dis_stage_reg_next.alu_op = alu_op_sra;
                        else id_dis_stage_reg_next.alu_op = alu_op_srl;
                    end
                    arith_f3_or: id_dis_stage_reg_next.alu_op = alu_op_or;
                    arith_f3_and: id_dis_stage_reg_next.alu_op = alu_op_and;
                    default: id_dis_stage_reg_next.alu_op = alu_op_add;
                    
                endcase
                id_dis_stage_reg_next.rvfi_rs2_s  = '0;
            end

            op_b_reg: begin
                id_dis_stage_reg_next.use_imm = '0;
                if (funct7[0] != 1'b1) begin // reg-reg (not multiply, divide, or rem)
                    unique case (funct3)
                        arith_f3_add: begin
                            if (funct7[5]) begin
                                id_dis_stage_reg_next.alu_op = alu_op_sub;
                            end else begin
                                id_dis_stage_reg_next.alu_op = alu_op_add;
                            end
                        end
                        arith_f3_sll: id_dis_stage_reg_next.alu_op = alu_op_sll;
                        arith_f3_slt: begin
                            id_dis_stage_reg_next.cmpop = branch_f3_blt;
                            id_dis_stage_reg_next.func_unit = br_fu;
                            id_dis_stage_reg_next.branch_inst = '0;
                            id_dis_stage_reg_next.cmp_or_alu = '1;
                        end
                        arith_f3_sltu: begin
                            id_dis_stage_reg_next.cmpop = branch_f3_bltu;
                            id_dis_stage_reg_next.func_unit = br_fu;
                            id_dis_stage_reg_next.branch_inst = '0;
                            id_dis_stage_reg_next.cmp_or_alu = '1;
                        end
                        arith_f3_xor: id_dis_stage_reg_next.alu_op = alu_op_xor;
                        arith_f3_sr: begin
                            if (funct7[5]) id_dis_stage_reg_next.alu_op = alu_op_sra;
                            else id_dis_stage_reg_next.alu_op = alu_op_srl;
                        end
                        arith_f3_or: id_dis_stage_reg_next.alu_op = alu_op_or;
                        arith_f3_and: id_dis_stage_reg_next.alu_op = alu_op_and;
                        default: id_dis_stage_reg_next.alu_op = alu_op_add;
                    endcase
                end else begin // reg-reg (multiply, divide, or rem)
                    id_dis_stage_reg_next.func_unit = mult_fu;
                    unique case (funct3)
                        arith_f3_add: id_dis_stage_reg_next.mul_op = m_mul;
                        arith_f3_sll: id_dis_stage_reg_next.mul_op = m_mulh;
                        arith_f3_slt: id_dis_stage_reg_next.mul_op = m_mulhsu;
                        arith_f3_sltu: id_dis_stage_reg_next.mul_op = m_mulhu;
                        arith_f3_xor: id_dis_stage_reg_next.mul_op = m_div;
                        arith_f3_sr: id_dis_stage_reg_next.mul_op = m_divu;
                        arith_f3_or: id_dis_stage_reg_next.mul_op = m_rem;
                        arith_f3_and: id_dis_stage_reg_next.mul_op = m_remu;
                        default: id_dis_stage_reg_next.alu_op = alu_op_add;
                    endcase
                end
            end

            default : begin
                id_dis_stage_reg_next.valid = '0;
                id_dis_stage_reg_next.use_imm = '0; // needs because LINT is obese. 
            end
        endcase
    end




endmodule : decode_rename_unit
