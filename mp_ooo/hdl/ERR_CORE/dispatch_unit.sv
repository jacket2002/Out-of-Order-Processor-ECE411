module dispatch_unit
import rv32i_types::*;
import params::*;
(
    // input   logic           clk,
    // input   logic           rst,
    input   id_dis_stage_reg_t decode_stage_reg,

    input   logic [ROB_PTR_WIDTH : 0] rob_write_ptr, 

    input   logic [MEM_QUEUE_PTR_WIDTH : 0] lsq_write_ptr,
    // input   [ROB_PTR_WIDTH : 0] rob_read_ptr,
    input   cdb_entry_t     cdb_entry_mult, cdb_entry_alu, cdb_entry_br, cdb_entry_mem,
    input   logic   rs_alu_full,
    input   logic   rs_mult_full,
    input   logic   rs_br_full,
    // input   logic   rs_mem_full,
    input   logic   rs_load_full,
    input   logic   store_queue_full,
    input   logic   rs_addr_full,
    input   logic   rob_full,

    input   logic [STORE_QUEUE_DEPTH-1:0] older_store_map,
    input   logic [LOAD_RS_INDEX_BITS-1:0] dispatch_load_idx,
    input   logic [STORE_QUEUE_PTR_WIDTH-1:0] store_queue_idx,
    input   logic   control_queue_full,
    input   logic [CONTROL_Q_DEPTH-1:0] control_bit_map,

    output  logic   dispatch_stall_out,

    output  logic   rob_write,   // work as write enable for reservation station
    output  logic   branch_write,
    output  logic   alu_write,
    output  logic   mul_write,

    // output  logic   mem_write,
    output  logic   load_write,
    output  logic   store_write,
    output  logic   control_write,
    
    output  alu_rs_entry_t alu_rs_entry,
    output  mul_rs_entry_t mul_rs_entry,
    output  branch_rs_entry_t branch_rs_entry,
    // output  mem_rs_entry_t    mem_rs_entry,
    output  load_rs_entry_t load_rs_entry,
    output  store_queue_entry_t store_queue_entry,
    output  addr_rs_entry_t addr_rs_entry,
    output  control_rs_entry_t control_rs_entry,
    output  rob_entry_t rob_entry,

    // rvfi
    output logic [4:0] rvfi_rs1_s, rvfi_rs2_s, rvfi_rd_s,
    output logic [31:0] rvfi_inst, rvfi_pc_val
    // output logic rvfi_rob_write_dispatch,
    // output logic [ROB_PTR_WIDTH:0] rvfi_rob_write_ptr_dispatch
);

    logic [PHYSICAL_REG_FILE_LENGTH-1:0] phys_d_reg_cdbM, phys_d_reg_cdbA, phys_d_reg_cdbB, phys_d_reg_cdbMem;
    logic valid;
    alu_ops_t  alu_op;
    m_extension_f3_t mul_op;
    logic [31:0] imm_operand;
    logic use_imm;
    logic [PHYSICAL_REG_FILE_LENGTH-1:0] phys_r1, phys_r2;
    logic phys_r1_valid, phys_r2_valid;
    branch_f3_t cmpop;
    logic [31:0] pc;
    logic [PHYSICAL_REG_FILE_LENGTH-1:0] phys_d_reg;
    logic [4:0] arch_d_reg;
    logic phys_r1_valid_modified, phys_r2_valid_modified;
    logic dispatch_stall;
    logic branch_inst;
    logic cmp_or_alu;
    logic jalr_flag, jal_flag;
    logic valid_cdbA, valid_cdbB, valid_cdbM, valid_cdbMem;
    func_unit_t func_unit; 
    logic load_store;
    load_f3_t load_type;
    store_f3_t store_type;

    // rvfi
    assign rvfi_rs1_s = decode_stage_reg.rvfi_rs1_s;
    assign rvfi_rs2_s = decode_stage_reg.rvfi_rs2_s;
    assign rvfi_rd_s = decode_stage_reg.rvfi_rd_s;
    assign rvfi_inst = decode_stage_reg.rvfi_inst;
    assign rvfi_pc_val = decode_stage_reg.rvfi_pc_val;

    // actual signals
    assign phys_d_reg_cdbM  = cdb_entry_mult.phys_d_reg;
    assign phys_d_reg_cdbA  = cdb_entry_alu.phys_d_reg;
    assign phys_d_reg_cdbB  = cdb_entry_br.phys_d_reg;
    assign phys_d_reg_cdbMem= cdb_entry_mem.phys_d_reg;
    assign valid_cdbM       = cdb_entry_mult.valid;
    assign valid_cdbA       = cdb_entry_alu.valid;
    assign valid_cdbB       = cdb_entry_br.valid;
    assign valid_cdbMem     = cdb_entry_mem.valid;

    assign valid            = decode_stage_reg.valid;
    assign alu_op           = decode_stage_reg.alu_op;
    assign mul_op           = decode_stage_reg.mul_op;
    assign imm_operand      = decode_stage_reg.imm_operand;
    assign use_imm          = decode_stage_reg.use_imm;
    assign phys_r1          = decode_stage_reg.phys_r1;
    assign phys_r2          = decode_stage_reg.phys_r2;
    assign phys_r1_valid    = decode_stage_reg.phys_r1_valid;
    assign phys_r2_valid    = decode_stage_reg.phys_r2_valid;
    assign cmpop            = decode_stage_reg.cmpop;
    assign pc               = decode_stage_reg.pc_val;
    assign phys_d_reg       = decode_stage_reg.phys_d_reg;
    assign arch_d_reg       = decode_stage_reg.arch_d_reg;
    assign branch_inst      = decode_stage_reg.branch_inst;
    assign cmp_or_alu       = decode_stage_reg.cmp_or_alu;
    assign jalr_flag        = decode_stage_reg.jalr_flag;
    assign jal_flag        = decode_stage_reg.jal_flag;
    assign func_unit        = decode_stage_reg.func_unit;
    assign load_store       = decode_stage_reg.load_store;
    assign load_type        = decode_stage_reg.load_type;
    assign store_type       = decode_stage_reg.store_type;
    
    assign phys_r1_valid_modified = ( (valid_cdbM && phys_d_reg_cdbM == phys_r1) || (valid_cdbA && phys_d_reg_cdbA == phys_r1) 
        || (valid_cdbB && phys_d_reg_cdbB == phys_r1) || (valid_cdbMem && phys_d_reg_cdbMem == phys_r1))? '1 : phys_r1_valid;
    assign phys_r2_valid_modified = ( (valid_cdbM && phys_d_reg_cdbM == phys_r2) || (valid_cdbA && phys_d_reg_cdbA == phys_r2) 
        || (valid_cdbB && phys_d_reg_cdbB == phys_r2) || (valid_cdbMem && phys_d_reg_cdbMem == phys_r2))? '1 : phys_r2_valid;
    assign dispatch_stall_out = dispatch_stall;

    always_comb begin
        dispatch_stall = '0;
        rob_write = '0;
        branch_write = '0;
        alu_write = '0;
        mul_write = '0;
        control_write = '0;
        store_write = '0;
        load_write = '0;
        if (valid) begin
            if (rob_full) begin
                dispatch_stall = '1;
            end else begin
                unique case (func_unit) 
                    alu_fu:     begin 
                        if (!rs_alu_full) begin alu_write = '1; rob_write = '1;  end
                        else begin dispatch_stall = '1; end
                    end
                    mult_fu:    begin 
                        if (!rs_mult_full) begin mul_write = '1; rob_write = '1; end
                        else begin dispatch_stall = '1; end
                    end
                    br_fu:      begin 
                        if (!rs_br_full) begin branch_write = '1; rob_write = '1; end
                        else begin dispatch_stall = '1; end
                    end
                    ctrl_fu:    begin
                        if (!control_queue_full) begin control_write = '1;   rob_write = '1; end
                        else begin dispatch_stall = '1; end
                    end
                    mem_fu:     begin
                        if (!rs_load_full && load_store == '0) begin 
                            load_write = '1;   
                            rob_write = '1; 
                        end else if (!store_queue_full && load_store == '1) begin
                            store_write = '1;
                            rob_write = '1;
                        end
                        if (!rs_addr_full) begin
                            if (!rs_load_full && load_store == '0) begin
                                load_write = '1;
                            end else if (!store_queue_full && load_store == '1) begin
                                store_write = '1;
                            end else begin
                                dispatch_stall = '1;
                            end
                        end
                        else begin dispatch_stall = '1; end
                    end
                    default:    begin dispatch_stall = '1; rob_write = '1; branch_write = '1; alu_write = '1; mul_write = '1; end
                    // default: dispatch_stall = '0;
                endcase
            end
        end
    end

    always_comb begin
        alu_rs_entry.finished = '0;
        alu_rs_entry.alu_op = alu_op;
        alu_rs_entry.imm = imm_operand;
        alu_rs_entry.use_imm = use_imm;
        alu_rs_entry.phys_d_reg = phys_d_reg;
        alu_rs_entry.arch_d_reg = arch_d_reg;
        alu_rs_entry.phys_r1 = phys_r1;
        alu_rs_entry.phys_r2 = phys_r2;
        
        alu_rs_entry.phys_r1_valid = phys_r1_valid_modified;
        alu_rs_entry.phys_r2_valid = phys_r2_valid_modified;

        alu_rs_entry.rob_idx = rob_write_ptr;
        alu_rs_entry.control_bit_map = control_bit_map;

        branch_rs_entry.finished = '0;
        branch_rs_entry.cmpop   = cmpop;
        branch_rs_entry.imm     = imm_operand;
        branch_rs_entry.use_imm = use_imm;
        branch_rs_entry.pc      = pc;
        branch_rs_entry.phys_d_reg = phys_d_reg;
        branch_rs_entry.arch_d_reg = arch_d_reg;
        branch_rs_entry.phys_r1 = phys_r1;
        branch_rs_entry.phys_r2 = phys_r2;
        branch_rs_entry.phys_r1_valid = phys_r1_valid_modified;
        branch_rs_entry.phys_r2_valid = phys_r2_valid_modified;
        branch_rs_entry.branch_inst = branch_inst;
        branch_rs_entry.cmp_or_alu = cmp_or_alu;
        branch_rs_entry.jalr_flag = jalr_flag;
        branch_rs_entry.jal_flag = jal_flag;
        branch_rs_entry.rob_idx = rob_write_ptr;
        branch_rs_entry.control_bit_map = control_bit_map;

        control_rs_entry.cmpop   = cmpop;
        control_rs_entry.imm     = imm_operand;
        control_rs_entry.use_imm = use_imm;
        control_rs_entry.pc      = pc;
        control_rs_entry.phys_d_reg = phys_d_reg;
        control_rs_entry.arch_d_reg = arch_d_reg;
        control_rs_entry.phys_r1 = phys_r1;
        control_rs_entry.phys_r2 = phys_r2;
        control_rs_entry.phys_r1_valid = phys_r1_valid_modified;
        control_rs_entry.phys_r2_valid = phys_r2_valid_modified;
        control_rs_entry.branch_inst = branch_inst;
        control_rs_entry.cmp_or_alu = cmp_or_alu;
        control_rs_entry.jalr_flag = jalr_flag;
        control_rs_entry.jal_flag = jal_flag;
        control_rs_entry.rob_idx = rob_write_ptr;
        control_rs_entry.control_bit_map = control_bit_map;
        control_rs_entry.lsq_idx = lsq_write_ptr;
        control_rs_entry.store_bitmap = older_store_map;
        control_rs_entry.branch_pattern = decode_stage_reg.branch_pattern;
        control_rs_entry.saturating_counter = decode_stage_reg.saturating_counter;
        control_rs_entry.pc_target_predict = decode_stage_reg.pc_target_predict;

        // mem_rs_entry.load_store = load_store;
        // mem_rs_entry.load_type = load_type;
        // mem_rs_entry.store_type = store_type; 
        // mem_rs_entry.imm = imm_operand;
        // mem_rs_entry.arch_d_reg = arch_d_reg;
        // mem_rs_entry.phys_d_reg = phys_d_reg;
        // mem_rs_entry.phys_r1 = phys_r1;
        // mem_rs_entry.phys_r2 = phys_r2;
        // mem_rs_entry.phys_r1_valid = phys_r1_valid_modified;
        // mem_rs_entry.phys_r2_valid = phys_r2_valid_modified;
        // mem_rs_entry.rob_idx = rob_write_ptr;

        addr_rs_entry.finished = '0;
        addr_rs_entry.load_store = load_store;
        addr_rs_entry.load_type = load_type;
        addr_rs_entry.store_type = store_type;
        addr_rs_entry.imm = imm_operand;
        addr_rs_entry.arch_d_reg = arch_d_reg;
        addr_rs_entry.phys_d_reg = phys_d_reg;
        addr_rs_entry.phys_r1 = phys_r1;
        addr_rs_entry.phys_r2 = phys_r2; 
        addr_rs_entry.phys_r1_valid = phys_r1_valid_modified;
        addr_rs_entry.phys_r2_valid = phys_r2_valid_modified;
        addr_rs_entry.load_rs_idx = dispatch_load_idx;
        addr_rs_entry.store_q_idx = store_queue_idx; 
        addr_rs_entry.rob_idx = rob_write_ptr;
        addr_rs_entry.control_bit_map = control_bit_map;

        load_rs_entry.finished = '0;
        load_rs_entry.rmask = '0;
        load_rs_entry.addr = '0;
        load_rs_entry.arch_d_reg = arch_d_reg;
        load_rs_entry.phys_d_reg = phys_d_reg;
        load_rs_entry.rob_idx = rob_write_ptr;
        load_rs_entry.store_bitmap = older_store_map;
        load_rs_entry.valid_addr = '0;
        load_rs_entry.load_type = load_f3_lb;
        load_rs_entry.rs1_v = '0;
        load_rs_entry.control_bit_map = control_bit_map;
        load_rs_entry.req_sent = '0;
        load_rs_entry.garbage_dmem = '0;

        store_queue_entry.wmask = '0;
        store_queue_entry.phys_r2 = phys_r2;
        store_queue_entry.phys_r2_valid = phys_r2_valid_modified; 
        store_queue_entry.rob_idx = rob_write_ptr;
        store_queue_entry.addr = '0;
        store_queue_entry.valid_addr = '0;
        store_queue_entry.store_type = store_f3_sb;
        store_queue_entry.rs1_v = '0;
        store_queue_entry.control_bit_map = control_bit_map;

        mul_rs_entry.finished = '0;
        mul_rs_entry.mul_op   = mul_op;
        mul_rs_entry.phys_d_reg = phys_d_reg;
        mul_rs_entry.arch_d_reg = arch_d_reg;
        mul_rs_entry.phys_r1 = phys_r1;
        mul_rs_entry.phys_r2 = phys_r2;
        mul_rs_entry.phys_r1_valid = phys_r1_valid_modified;
        mul_rs_entry.phys_r2_valid = phys_r2_valid_modified;
        mul_rs_entry.rob_idx = rob_write_ptr;
        mul_rs_entry.control_bit_map = control_bit_map;

        rob_entry.ready_to_commit = '0;
        rob_entry.phys_d_reg      = phys_d_reg; // this is phys_d_reg in id_dis_stage_reg_t
        rob_entry.arch_d_reg      = arch_d_reg; 
        
    end



endmodule : dispatch_unit
