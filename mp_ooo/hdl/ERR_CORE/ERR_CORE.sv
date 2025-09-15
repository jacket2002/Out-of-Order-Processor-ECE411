module ERR_CORE
import params::*;
import rv32i_types::*;
(

    input logic clk,
    input logic rst,

    // mem signals
    output logic [31:0] imem_addr, dmem_addr, dmem_wdata,
    output logic [3:0] imem_rmask, dmem_rmask, dmem_wmask,

    input logic [31:0] imem_rdata, dmem_rdata,
    input logic imem_resp, dmem_resp
);
logic [31:0] instruction;
logic read_ack;
logic read;
logic [31:0] pc;
// RAT signals
logic [PHYSICAL_REG_FILE_LENGTH-1:0] ps1;
logic [PHYSICAL_REG_FILE_LENGTH-1:0] ps2;
logic ps1_valid;
logic ps2_valid;

logic valid_hist_entry;
logic [61:0] local_hist_table_read_data;

logic [25:0] pc_tag;   // first 26 bits of pc, (4 bits for index)
logic [3:0]  branch_pattern;
logic [1:0]  saturating_counter;
logic [31:0] pc_target_predict;
logic [3:0]  branch_pattern_out;
logic [1:0]  saturating_counter_out;
logic [31:0] pc_target_predict_out;

// free list signals
logic [PHYSICAL_REG_FILE_LENGTH-1:0] renamed_dest_reg;
logic queue_full_free_list, queue_empty_free_list; // these 4 signals probably not needed.
logic read_ack_free_list, write_ack_free_list;


// decode signal
logic [4:0] rs1_arc;
logic [4:0] rs2_arc;
logic [4:0] rd_arc;
logic control_inst_checkpoint;


// dispatch unit signals
logic dispatch_stall;
logic ROB_write;
logic alu_write;
logic branch_write;
logic mul_write;
logic mem_write;
alu_rs_entry_t alu_rs_entry;
mul_rs_entry_t mul_rs_entry;
branch_rs_entry_t branch_rs_entry;
addr_rs_entry_t addr_rs_entry;
load_rs_entry_t load_rs_entry;
store_queue_entry_t store_queue_entry;
rob_entry_t rob_entry;
logic   control_write;
control_rs_entry_t control_rs_entry;



// ROB signals
logic ROB_read_ack;

rob_entry_t ROB_read_data;
logic [ROB_PTR_WIDTH:0] ROB_write_ptr, ROB_read_ptr;
logic ROB_full, ROB_empty, ROB_write_ack;


// RRF signals
logic [PHYSICAL_REG_FILE_LENGTH-1:0] old_RRF_phys;
logic   [PHYSICAL_REG_FILE_LENGTH-1:0]  rrf_data [32];
logic rs_alu_full;
logic rs_mul_full;
logic rs_br_full;
logic rs_addr_full;
logic rs_load_full;
logic store_queue_full;

// CDB ALU
cdb_entry_t CDB_entry_alu;

logic [PHYSICAL_REG_WIDTH - 1:0] rs1_alu;
logic [PHYSICAL_REG_WIDTH - 1:0] rs2_alu;

// CDB muld
cdb_entry_t CDB_entry_mult;
logic [PHYSICAL_REG_WIDTH - 1:0] rs1_mul;
logic [PHYSICAL_REG_WIDTH - 1:0] rs2_mul;

// CDB branch
cdb_entry_t CDB_entry_br;
logic [PHYSICAL_REG_WIDTH - 1:0] rs1_br;
logic [PHYSICAL_REG_WIDTH - 1:0] rs2_br;
logic [31:0] pc_target_b;
logic branch_en_b;

logic   control_queue_full;
logic [CONTROL_Q_DEPTH-1:0] control_bit_map;
logic [CONTROL_Q_PTR_WIDTH : 0]   control_read_ptr;
logic [MEM_QUEUE_PTR_WIDTH : 0]   lsq_write_ptr_on_flush;
logic [STORE_QUEUE_DEPTH-1:0]     store_q_bitmap_on_flush;

logic flush_by_branch_b;
logic [31:0] pc_target_on_flush;
logic [3:0] new_branch_pattern;
logic [1:0] new_saturating_counter;
logic [3:0] local_hist_table_write_idx;
logic [61:0] local_hist_table_write_data;

// CDB mem
cdb_entry_t CDB_entry_mem;
logic [PHYSICAL_REG_WIDTH - 1:0] rs1_mem;
logic [PHYSICAL_REG_WIDTH - 1:0] rs2_mem;
logic [PHYSICAL_REG_WIDTH - 1:0] rs2_mem_forward;

logic load_write;
logic store_write;
logic [STORE_QUEUE_DEPTH-1:0] older_store_map;
logic [LOAD_RS_INDEX_BITS-1:0] dispatch_load_idx;
logic [STORE_QUEUE_PTR_WIDTH-1:0] store_queue_idx;
logic [MEM_QUEUE_PTR_WIDTH : 0]   lsq_write_ptr_rec;
logic SQ_read_ack_out;
logic [MEM_QUEUE_PTR_WIDTH : 0] SQ_read_ptr;
logic ROB_store_commit_flag;

// Phys reg file signals
logic   [31:0]  rs1_v_alu, rs2_v_alu, rs1_v_mul, rs2_v_mul, rs1_v_br, rs2_v_br, rs1_v_mem, rs2_v_mem, rs2_v_mem_forward;

// unused so far
// logic CDB_valid; 
// logic [4:0] CDB_logical_d_reg;
// logic [PHYSICAL_REG_FILE_LENGTH-1:0] CDB_phys_d_reg;
logic mem_queue_empty;

// RVFI signals
logic [4:0] rvfi_rs1_s, rvfi_rs2_s, rvfi_rd_s;
logic [31:0] rvfi_inst, rvfi_pc_val;
logic rvfi_rob_write_dispatch;
logic [ROB_PTR_WIDTH:0] rvfi_rob_write_ptr_dispatch;

// RVFI alu
logic [31:0] rvfi_rs1_rdata_a, rvfi_rs2_rdata_a;
logic [31:0] rvfi_rd_wdata_a;
logic [ROB_PTR_WIDTH:0] rvfi_issue_execute_rob_ptr_a;
logic rvfi_inst_finished_a;

// RVFI mult
logic [31:0] rvfi_rs1_rdata_m, rvfi_rs2_rdata_m;
logic [31:0] rvfi_rd_wdata_m;
logic [ROB_PTR_WIDTH:0] rvfi_issue_execute_rob_ptr_m;
logic rvfi_inst_finished_m;

// RVFI branch
logic [31:0] rvfi_rs1_rdata_b, rvfi_rs2_rdata_b;
logic [31:0] rvfi_rd_wdata_b;
logic [ROB_PTR_WIDTH:0] rvfi_issue_execute_rob_ptr_b;
logic rvfi_inst_finished_b;

logic [ROB_PTR_WIDTH:0] rvfi_ROB_read_ptr;
logic rvfi_commit;
logic [63:0] rvfi_order;
RVFI_entry_t RVFI_data;
logic [31:0] rvfi_pc_wdata; 

// RVFI mem
logic [31:0] rvfi_rs1_rdata_mem, rvfi_rs2_rdata_mem;
logic [31:0] rvfi_rd_wdata_mem;
logic [ROB_PTR_WIDTH:0] rvfi_issue_execute_rob_ptr_mem; 
logic rvfi_inst_finished_mem;
logic [3:0] rvfi_mem_wmask, rvfi_mem_rmask;
logic [31:0] rvfi_mem_addr, rvfi_mem_rdata, rvfi_mem_wdata;

logic [31:0] rvfi_store_rs1_rdata_mem, rvfi_store_rs2_rdata_mem;
logic [31:0] rvfi_store_rd_wdata_mem;
logic rvfi_store_inst_finished_mem;
logic [ROB_PTR_WIDTH:0] rvfi_store_issue_execute_rob_ptr_mem;
logic [3:0] rvfi_store_mem_wmask, rvfi_store_mem_rmask;
logic [31:0] rvfi_store_mem_addr, rvfi_store_mem_rdata, rvfi_store_mem_wdata;

// stage regs:
id_dis_stage_reg_t id_dis_stage_reg, id_dis_stage_reg_next;

logic valid_cdbA, valid_cdbB, valid_cdbM, valid_cdbMem;
logic [PHYSICAL_REG_FILE_LENGTH-1:0] phys_d_reg_cdbM, phys_d_reg_cdbA, phys_d_reg_cdbB, phys_d_reg_cdbMem;
logic [PHYSICAL_REG_FILE_LENGTH-1:0] phys_r1, phys_r2;

logic flush_by_branch, branch_resolved;
logic [31:0] new_pc_target;

// BRAT signals
logic   BRAT_full;
logic   [FREE_LIST_PTR_WIDTH : 0] free_list_rd_ptr_out, free_list_rd_ptr_in;
logic   [PHYSICAL_REG_FILE_LENGTH-1:0] RAT_internal_map_in [32];
logic   [PHYSICAL_REG_FILE_LENGTH-1:0] RAT_internal_map_out [32];
logic   [31:0] RAT_internal_valid_map_in, RAT_internal_valid_map_out;

assign read = !dispatch_stall && !queue_empty_free_list && !BRAT_full;

assign valid_cdbM       = CDB_entry_mult.valid;
assign valid_cdbA       = CDB_entry_alu.valid;
assign valid_cdbB       = CDB_entry_br.valid;
assign valid_cdbMem     = CDB_entry_mem.valid;

assign phys_d_reg_cdbM  = CDB_entry_mult.phys_d_reg;
assign phys_d_reg_cdbA  = CDB_entry_alu.phys_d_reg;
assign phys_d_reg_cdbB  = CDB_entry_br.phys_d_reg;
assign phys_d_reg_cdbMem = CDB_entry_mem.phys_d_reg;

assign phys_r1          = id_dis_stage_reg.phys_r1;
assign phys_r2          = id_dis_stage_reg.phys_r2;

always_ff @ (posedge clk) begin
    if (rst|flush_by_branch) begin
        id_dis_stage_reg <= '0;
    end else if (dispatch_stall ) begin
        id_dis_stage_reg <= id_dis_stage_reg;

        if ((valid_cdbM && phys_d_reg_cdbM == phys_r1) || (valid_cdbA && phys_d_reg_cdbA == phys_r1) 
        || (valid_cdbB && phys_d_reg_cdbB == phys_r1) || (valid_cdbMem && phys_d_reg_cdbMem == phys_r1))
        id_dis_stage_reg.phys_r1_valid <= '1;

        if ((valid_cdbM && phys_d_reg_cdbM == phys_r2) || (valid_cdbA && phys_d_reg_cdbA == phys_r2) 
        || (valid_cdbB && phys_d_reg_cdbB == phys_r2)|| (valid_cdbMem && phys_d_reg_cdbMem == phys_r2))
        id_dis_stage_reg.phys_r2_valid <= '1;

    end 
    else begin
        id_dis_stage_reg <= id_dis_stage_reg_next;
    end
end

assign flush_by_branch = branch_resolved? flush_by_branch_b : '0;
assign new_pc_target = pc_target_on_flush;


// pipelined regs
fetch fetch_stage(
    .clk(clk),
    .rst(rst),
    .flush_by_branch(flush_by_branch),
    .pc_target(new_pc_target),
    .imem_addr(imem_addr),
    .imem_rmask(imem_rmask),
    .imem_rdata(imem_rdata),
    .imem_resp(imem_resp),
    // .dispatch_stall(dispatch_stall),

    .valid_hist_entry(valid_hist_entry),
    .pc_tag(pc_tag),
    .branch_pattern(branch_pattern),
    .saturating_counter(saturating_counter),
    .pc_target_predict(pc_target_predict),
    .branch_pattern_out(branch_pattern_out),
    .saturating_counter_out(saturating_counter_out),
    .pc_target_predict_out(pc_target_predict_out),

    //decode signals
    .read(read),
    .instruction(instruction),
    .pc_out(pc),
    .read_ack(read_ack)
);

assign pc_tag = local_hist_table_read_data[61:36];
assign branch_pattern = local_hist_table_read_data[35:32];
assign pc_target_predict = local_hist_table_read_data[31:0];

valid_array_hist valid_array_hist_0 (
    .clk0       (clk),
    .rst0       (rst),
    .csb0       ('0),
    .web0       ('1),
    .addr0      (imem_addr[5:2]),
    .din0       ('x),
    .dout0      (valid_hist_entry),
    .csb1       (~branch_resolved),
    .web1       ('0),
    .addr1      (local_hist_table_write_idx),
    .din1       ('1),
    .dout1      ()
);

local_hist_table local_hist_table_0 (
    .clk0       (clk),
    .csb0       (rst),
    .web0       ('1),
    .addr0      (imem_addr[5:2]),
    .din0       ('x),
    .dout0      (local_hist_table_read_data),
    .clk1       (clk),
    .csb1       (~branch_resolved),
    .web1       ('0),
    .addr1      (local_hist_table_write_idx),
    .din1       (local_hist_table_write_data),
    .dout1      ()
);

pattern_hist_table pattern_hist_table_0 (
    .clk0(clk),
    .rst0(rst),
    .addr0(branch_pattern),
    .dout0(saturating_counter),
    .web1(~branch_resolved),
    .addr1(new_branch_pattern),
    .din1(new_saturating_counter)
);

decode_rename_unit decode_rename_stage(
    // inputs
    // inputs from fetch (should be from fetch stage??? We might needed a pipeline register)
    .instruction(instruction),
    .pc(pc),
    .read_ack(read_ack),
    .frli_read_ack(read_ack_free_list),

    .branch_pattern_out(branch_pattern_out),
    .saturating_counter_out(saturating_counter_out),
    .pc_target_predict_out(pc_target_predict_out),

    // inputs from RAT
    .ps1(ps1),
    .ps2(ps2),
    .ps1_valid(ps1_valid),
    .ps2_valid(ps2_valid),

    // inputs from free_list
    .d_reg_rename(renamed_dest_reg),

    // outputs
    // outputs to RAT
    .rs1_arc(rs1_arc),
    .rs2_arc(rs2_arc),
    .rd_arc(rd_arc),
    // signal to copy RAT
    .control_inst_checkpoint(control_inst_checkpoint),
    // stage reg output
    .id_dis_stage_reg_next(id_dis_stage_reg_next)
);

// modules that are outside pipeline stages

BRAT BRAT_0(
    .clk(clk),
    .rst(rst),
    .flush_by_branch(flush_by_branch),
    .write_en(control_inst_checkpoint),
    .read_en(branch_resolved),
    .free_list_rd_ptr_in(free_list_rd_ptr_in),
    .RAT_internal_map_in(RAT_internal_map_in),
    .RAT_internal_valid_map_in(RAT_internal_valid_map_in),
    .a_dest(rd_arc),
    .p_dest(renamed_dest_reg),
    .free_list_read_ack(read_ack_free_list),
    .cdb_entry_md(CDB_entry_mult), 
    .cdb_entry_add(CDB_entry_alu), 
    .cdb_entry_branch(CDB_entry_br),
    .cdb_entry_mem(CDB_entry_mem),
    .free_list_rd_ptr_out(free_list_rd_ptr_out),
    .RAT_internal_map_out(RAT_internal_map_out),
    .RAT_internal_valid_map_out(RAT_internal_valid_map_out),
    .queue_full(BRAT_full),
    .queue_empty()
);

RAT #(
    .DATA_WIDTH(PHYSICAL_REG_FILE_LENGTH)
)
register_alias_table 
(
    // inputs
    .clk(clk),
    .rst(rst),
    .flush_by_branch(flush_by_branch),
    // inputs from decode stage
    .rs1_arc(rs1_arc),
    .rs2_arc(rs2_arc),
    .a_dest(rd_arc),
    // inputs from free list
    .p_dest(renamed_dest_reg),
    .free_list_read_ack(read_ack_free_list),
    
    // inputs from CDB (not used so far)
    .cdb_entry_add(CDB_entry_alu), 
    .cdb_entry_md(CDB_entry_mult), 
    .cdb_entry_branch(CDB_entry_br), 
    .cdb_entry_mem(CDB_entry_mem),
    .control_read_ptr(control_read_ptr),
    //input from BRAT
    .RAT_internal_map_out(RAT_internal_map_out),
    .RAT_internal_valid_map_out(RAT_internal_valid_map_out),
    // outputs to BRAT
    .RAT_internal_map_in(RAT_internal_map_in),
    .RAT_internal_valid_map_in(RAT_internal_valid_map_in),
    // outputs to decode stage
    .ps1(ps1),
    .ps2(ps2),
    .ps1_valid(ps1_valid),
    .ps2_valid(ps2_valid)
);

free_list #(
    .DATA_WIDTH(PHYSICAL_REG_FILE_LENGTH), 
    .QUEUE_SIZE(FREE_LIST_QUEUE_LENGTH)
)
free_list_inst
(
    // inputs
    .clk(clk),
    .rst(rst),

    // inputs from RRF
    .write_en(ROB_read_ack), // don't have for now, so we will not update the free list. 
    .write_data(old_RRF_phys),
    .flush_by_branch(flush_by_branch),
    .free_list_rd_ptr_out(free_list_rd_ptr_out),
    .free_list_rd_ptr_in(free_list_rd_ptr_in),

    // inputs from dispatch stage
    .read_en(~dispatch_stall && read_ack && (rd_arc != '0)), // will be controlled by dispatch stalling
    
    // outputs
    // outputs to decode stage
    .read_data(renamed_dest_reg),

    // useless outputs (probably)
    .queue_full(queue_full_free_list),
    .queue_empty(queue_empty_free_list),
    .read_ack(read_ack_free_list),
    .write_ack(write_ack_free_list)
);

dispatch_unit dispatch_stage (
    // inputs
    .decode_stage_reg(id_dis_stage_reg),
    .rob_write_ptr(ROB_write_ptr),

    .cdb_entry_mult(CDB_entry_mult), 
    .cdb_entry_alu(CDB_entry_alu), 
    .cdb_entry_br(CDB_entry_br),
    .cdb_entry_mem(CDB_entry_mem),
    .rs_alu_full(rs_alu_full),
    .rs_mult_full(rs_mul_full),
    .rs_br_full(rs_br_full),
    // .rs_mem_full(rs_mem_full),
    .rs_load_full(rs_load_full),
    .store_queue_full(store_queue_full),
    .rs_addr_full(rs_addr_full),
    .control_queue_full(control_queue_full),
    .rob_full(ROB_full),
    .older_store_map(older_store_map),
    .dispatch_load_idx(dispatch_load_idx),
    .store_queue_idx(store_queue_idx),

    // outputs
    .dispatch_stall_out(dispatch_stall),

    .rob_write(ROB_write),   // work as write enable for reservation station
    .branch_write(branch_write),
    .alu_write(alu_write),
    .mul_write(mul_write),
    // .mem_write(mem_write),
    .load_write(load_write),
    .store_write(store_write),
    .control_write(control_write),
    .alu_rs_entry(alu_rs_entry),
    .mul_rs_entry(mul_rs_entry),
    .branch_rs_entry(branch_rs_entry),
    // .mem_rs_entry(mem_rs_entry),
    .load_rs_entry(load_rs_entry),
    .store_queue_entry(store_queue_entry),
    .addr_rs_entry(addr_rs_entry),
    .rob_entry(rob_entry),
    .control_rs_entry(control_rs_entry),
    .lsq_write_ptr(lsq_write_ptr_rec),
    .control_bit_map(control_bit_map),

    // rvfi
    .*
);



ROB #(
    .QUEUE_SIZE(ROB_DEPTH)
)
ROB_inst 
(
    .clk(clk), 
    .rst(rst),
    .write_data(rob_entry),
    .write_en(ROB_write),
    .flush_by_branch(flush_by_branch),
    // .read_en(),
    .cdb_entry_md(CDB_entry_mult),
    .cdb_entry_branch(CDB_entry_br),
    .cdb_entry_add(CDB_entry_alu),
    .cdb_entry_mem(CDB_entry_mem),

    .read_data(ROB_read_data),
    .queue_full(ROB_full), 
    .queue_empty(ROB_empty),
    .read_ack(ROB_read_ack),
    .write_ack(ROB_write_ack), 
    .ROB_write_ptr(ROB_write_ptr), 
    .ROB_read_ptr(ROB_read_ptr),
    .ROB_store_commit_flag(ROB_store_commit_flag),

    // rvfi 
    .*
);

physical_reg_file PHYS_REG_FILE (
    .clk(clk),
    .rst(rst),
    .regf_we_alu(CDB_entry_alu.valid),
    .regf_we_mul(CDB_entry_mult.valid),
    .regf_we_br(CDB_entry_br.valid),
    .regf_we_mem(CDB_entry_mem.valid),
    .rd_v_alu(CDB_entry_alu.rd_v),
    .rd_v_mul(CDB_entry_mult.rd_v),
    .rd_v_br(CDB_entry_br.rd_v),
    .rd_v_mem(CDB_entry_mem.rd_v),
    .rs1_alu(rs1_alu),
    .rs2_alu(rs2_alu),
    .rd_alu(CDB_entry_alu.phys_d_reg),
    .rs1_mul(rs1_mul),
    .rs2_mul(rs2_mul), 
    .rd_mul(CDB_entry_mult.phys_d_reg), 
    .rs1_br(rs1_br), 
    .rs2_br(rs2_br), 
    .rd_br(CDB_entry_br.phys_d_reg), 
    .rs1_mem(rs1_mem),
    .rs2_mem(rs2_mem),
    .rd_mem(CDB_entry_mem.phys_d_reg),

    // .rs1_v_alu(), 
    // .rs2_v_alu(), 
    // .rs1_v_mul(), 
    // .rs2_v_mul(), 
    // .rs1_v_br(), 
    // .rs2_v_br(),
    // .rs1_v_mem(), 
    // .rs2_v_mem(),
    // .rs2_v_mem_forward()
    .*
);



RRF RRF_inst (
    .clk(clk),
    .rst(rst), 
    .we(ROB_read_ack),
    .rd_v(ROB_read_data.phys_d_reg), 
    .rd_s(ROB_read_data.arch_d_reg), 
    .rrf_data(rrf_data),
    .rs1_v(old_RRF_phys)
);

CDB_alu CDB_alu_inst (
    .clk(clk), 
    .rst(rst),
    .flush_by_branch(flush_by_branch),
    .branch_resolved(branch_resolved),
    .control_read_ptr(control_read_ptr),
    .alu_write(alu_write),
    .alu_rs_entry(alu_rs_entry), 
    .rob_read_ptr('0), // used for priority 
    .rs1_v_alu(rs1_v_alu), 
    .rs2_v_alu(rs2_v_alu), 
    .cdb_entry_mult(CDB_entry_mult), 
    .cdb_entry_br(CDB_entry_br), 
    .cdb_entry_mem(CDB_entry_mem),

    .rs1_alu(rs1_alu), 
    .rs2_alu(rs2_alu), 
    .cdb_entry_alu_out(CDB_entry_alu), 
    .rs_alu_full(rs_alu_full),

    // rvfi 
    .*
);

CDB_muld CDB_muld_inst (
    .clk(clk),
    .rst(rst),
    .flush_by_branch(flush_by_branch),
    .branch_resolved(branch_resolved),
    .control_read_ptr(control_read_ptr),
    .mul_write(mul_write),
    .mul_rs_entry(mul_rs_entry),
    .rob_read_ptr('0),
    .rs1_v_mul(rs1_v_mul), // operands
    .rs2_v_mul(rs2_v_mul),
    .cdb_entry_br(CDB_entry_br),
    .cdb_entry_alu(CDB_entry_alu),
    .cdb_entry_mem(CDB_entry_mem),

    .rs1_mul(rs1_mul), 
    .rs2_mul(rs2_mul),
    .cdb_entry_mult_out(CDB_entry_mult),
    .rs_mul_full(rs_mul_full),

    // rvfi
    .*
);
    
CDB_branch CDB_branch_inst (
    .clk(clk),
    .rst(rst), 
    .flush_by_branch(flush_by_branch),
    .branch_write(branch_write), 
    .br_rs_entry(branch_rs_entry),
    .control_write(control_write),
    .control_rs_entry(control_rs_entry),
    .rob_read_ptr('0),
    .rs1_v_br(rs1_v_br),
    .rs2_v_br(rs2_v_br),
    .cdb_entry_mult(CDB_entry_mult), 
    .cdb_entry_alu(CDB_entry_alu),
    .cdb_entry_mem(CDB_entry_mem),

    .SQ_read_ack_out(SQ_read_ack_out),
    .SQ_read_ptr(SQ_read_ptr),
    
    .rs1_br(rs1_br),
    .rs2_br(rs2_br),
    .cdb_entry_br_out(CDB_entry_br),
    .rs_br_full(rs_br_full),
    .control_queue_full(control_queue_full),
    .control_bit_map_out(control_bit_map),
    .control_read_ptr_out(control_read_ptr),
    .lsq_write_ptr_on_flush(lsq_write_ptr_on_flush),
    .store_q_bitmap_on_flush(store_q_bitmap_on_flush),
    .pc_target(pc_target_b),
    .branch_en(branch_en_b),
    .branch_resolved(branch_resolved),

    .flush_by_branch_b(flush_by_branch_b),
    .pc_target_on_flush(pc_target_on_flush),
    .new_branch_pattern(new_branch_pattern),
    .new_saturating_counter(new_saturating_counter),
    .local_hist_table_write_idx(local_hist_table_write_idx),
    .local_hist_table_write_data(local_hist_table_write_data),
    //RVFI
    .*
);

CDB_mem CDB_mem_inst (
    .clk(clk), 
    .rst(rst),
    .flush_by_branch(flush_by_branch),
    // .write_en(mem_write),
    .load_write(load_write),
    .store_write(store_write),
    .load_rs_entry(load_rs_entry),
    .store_queue_entry(store_queue_entry),
    .addr_rs_entry(addr_rs_entry), 

    .ROB_read_ptr(ROB_read_ptr),

    .rs1_mem(rs1_mem), //outputs into Phys Reg File (we don't need rs2 for loads)
    .rs2_mem(rs2_mem),
    .rs1_v_mem(rs1_v_mem), 
    .rs2_v_mem(rs2_v_mem),

    .cdb_entry_mult(CDB_entry_mult), 
    .cdb_entry_branch(CDB_entry_br),
    .cdb_entry_alu(CDB_entry_alu),
    .cdb_entry_mem_out(CDB_entry_mem),

    .addr_rs_full(rs_addr_full),
    .load_rs_full(rs_load_full),
    .store_q_full(store_queue_full), 
    .store_q_wrt_ptr(lsq_write_ptr_rec),
    .SQ_read_ack_out(SQ_read_ack_out),
    .SQ_read_ptr_out(SQ_read_ptr),

    .older_store_map(older_store_map), // bit mask to designate 
    .store_queue_idx(store_queue_idx),
    .dispatch_load_idx(dispatch_load_idx),

    .lsq_write_ptr_on_flush(lsq_write_ptr_on_flush),
    .store_q_bitmap_on_flush(store_q_bitmap_on_flush),

    // inputs from D cache
    // input logic [31:0] dmem_raddr, // not needed for now because we force in order memory requests.
    .dmem_rdata(dmem_rdata),
    .dmem_resp(dmem_resp),
    // outputs into D Cache
    .dmem_addr(dmem_addr), 
    .dmem_wdata(dmem_wdata),
    .dmem_wmask(dmem_wmask), 
    .dmem_rmask(dmem_rmask),

    // rvfi 
    .*
);

RVFI #(
    .QUEUE_SIZE(ROB_DEPTH)
) RVFI_inst (
    .clk(clk),
    .rst(rst),
    .commit(ROB_read_ack),
    .rvfi_rob_write_dispatch(ROB_write),
    .rvfi_rob_write_ptr_dispatch(ROB_write_ptr),
    .branch_en(branch_en_b),
    .*
);

endmodule

