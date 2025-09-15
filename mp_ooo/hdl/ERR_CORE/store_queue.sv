module store_queue
import rv32i_types::*;
import params::*;
(
    input logic clk,
    input logic rst,

    input logic flush_by_branch,

    input logic store_write,
    input store_queue_entry_t store_queue_entry,

    input   cdb_entry_t     cdb_entry_mult, 
    input   cdb_entry_t     cdb_entry_branch,
    input   cdb_entry_t     cdb_entry_add,
    input   cdb_entry_t     cdb_entry_mem,

    input  logic dmem_stall,
    input  logic [ROB_PTR_WIDTH:0] ROB_read_ptr, // stores will only be popped once phys_r2 is valid and the store instruction has reached head of the ROB. 

    output logic SQ_full, SQ_empty,

    input   logic   [31:0]  rs2_v_mem, // phys reg file. 
    output  logic [PHYSICAL_REG_WIDTH - 1:0] rs2_mem,

    input logic store_address_ready, // signal to tell store_queue to update one of its entries
    input logic [STORE_QUEUE_PTR_WIDTH-1:0] SQ_entry_idx,
    input logic [31:0] addr_v_in,
    input logic [3:0] wmask_in, 
    input logic [31:0] rs1_v,
    input store_f3_t store_type,
    input logic garbage_dmem,

    // EBR
    input  logic [CONTROL_Q_PTR_WIDTH : 0]   control_read_ptr,
    input  logic    branch_resolved,
    input logic [MEM_QUEUE_PTR_WIDTH : 0]   lsq_write_ptr_on_flush,
    input logic [STORE_QUEUE_DEPTH-1:0]     store_q_bitmap_on_flush,

    output logic SQ_read_ack,
    output logic serve_store,
    output logic [STORE_QUEUE_PTR_WIDTH:0] SQ_read_ptr,
    output logic [31:0] store_serving_addr,
    output logic [3:0] store_serving_wmask,
    output logic [31:0] store_serving_wdata,
    output logic [31:0] store_serving_rs1_v, store_serving_rs2_v, 
    output logic [ROB_PTR_WIDTH:0] store_serving_rob_idx,
    output logic [CONTROL_Q_DEPTH-1:0] store_serving_control_bit_map,

    output logic [STORE_QUEUE_DEPTH-1:0] older_store_map,
    output store_queue_entry_t store_queue_out [STORE_QUEUE_DEPTH],
    output logic [STORE_QUEUE_PTR_WIDTH :0] SQ_idx_0,
    output logic [STORE_QUEUE_PTR_WIDTH-1:0] SQ_idx,

    output logic store_able_to_commit
);

    store_queue_entry_t store_queue [STORE_QUEUE_DEPTH];
    logic [STORE_QUEUE_PTR_WIDTH:0] store_queue_read_ptr, store_queue_write_ptr; 
    logic SQ_read_en;

    logic [STORE_QUEUE_DEPTH-1:0] bitmap;
    logic flush_entire_lsq;

    assign SQ_read_ptr = store_queue_read_ptr;
    assign store_queue_out = store_queue;
    assign rs2_mem = store_queue[store_queue_read_ptr[STORE_QUEUE_PTR_WIDTH-1:0]].phys_r2;
    assign SQ_full = ((store_queue_write_ptr[STORE_QUEUE_PTR_WIDTH-1:0] == store_queue_read_ptr[STORE_QUEUE_PTR_WIDTH-1:0])&&
    (store_queue_write_ptr[STORE_QUEUE_PTR_WIDTH] != store_queue_read_ptr[STORE_QUEUE_PTR_WIDTH])) ? '1 : '0; // makes sure read_ptr is more thanone away

    assign SQ_empty = (store_queue_read_ptr == store_queue_write_ptr) ? '1 : '0;
    
    assign SQ_read_en = (store_queue[store_queue_read_ptr[STORE_QUEUE_PTR_WIDTH-1:0]].phys_r2_valid && store_queue[store_queue_read_ptr[STORE_QUEUE_PTR_WIDTH-1:0]].rob_idx[ROB_PTR_WIDTH-1:0] == ROB_read_ptr[ROB_PTR_WIDTH-1:0] && 
    store_queue[store_queue_read_ptr[STORE_QUEUE_PTR_WIDTH-1:0]].valid_addr && !dmem_stall && !garbage_dmem && !flush_by_branch);

    assign SQ_idx = store_queue_write_ptr[STORE_QUEUE_PTR_WIDTH-1:0];
    assign SQ_idx_0 = store_queue_write_ptr;
    assign flush_entire_lsq = (store_queue[store_queue_read_ptr[STORE_QUEUE_PTR_WIDTH-1:0]].control_bit_map[control_read_ptr[CONTROL_Q_PTR_WIDTH-1 : 0]] == 1'b1)? 1'b1: 1'b0;
    assign store_able_to_commit = SQ_read_en && !SQ_empty;
    // bit map
    always_ff @ (posedge clk) begin
        if (rst) begin
            bitmap <= '0;
        end
        else if (flush_by_branch) begin
            bitmap <= store_q_bitmap_on_flush;
        end else begin
            if (store_write && !SQ_full) begin
                bitmap[store_queue_write_ptr[STORE_QUEUE_PTR_WIDTH-1:0]] <= 1'b1;
            end 
            if (SQ_read_en && !SQ_empty) begin
                bitmap[store_queue_read_ptr[STORE_QUEUE_PTR_WIDTH-1:0]] <= 1'b0;
            end
        end
    end
    assign older_store_map = bitmap;

    // write_ptr logic
    always_ff @ (posedge clk) begin
        if (rst) begin
            store_queue_write_ptr <= '0;
        end 
        else if (flush_by_branch) begin
            store_queue_write_ptr <= lsq_write_ptr_on_flush;
        end
        else if (store_write && !SQ_full) begin
            store_queue_write_ptr <= store_queue_write_ptr + 1'b1;
        end
    end

    // read_ptr logic
    always_ff @ (posedge clk) begin
        if (rst) begin
            store_queue_read_ptr <= '0;
        end else if (SQ_read_en && !SQ_empty) begin
            store_queue_read_ptr <= store_queue_read_ptr + 1'b1;
        end
    end

    // writing logic for SQ
    always_ff @ (posedge clk) begin
        if (rst) begin
            for (int i = 0; i < STORE_QUEUE_DEPTH; i++) begin
                store_queue[i] <= '0;
            end
        end else begin
            if (store_write && !SQ_full) begin
                store_queue[store_queue_write_ptr[STORE_QUEUE_PTR_WIDTH-1:0]] <= store_queue_entry;
            end

            if (store_address_ready) begin
                store_queue[SQ_entry_idx].wmask <= wmask_in;
                store_queue[SQ_entry_idx].addr <= addr_v_in;
                store_queue[SQ_entry_idx].valid_addr <= '1;
                store_queue[SQ_entry_idx].rs1_v <= rs1_v;
                store_queue[SQ_entry_idx].store_type <= store_type;
            end

            for (int i = 0; i < STORE_QUEUE_DEPTH; i++) begin
                if (cdb_entry_add.valid) begin
                    if (store_queue[i].phys_r2 == cdb_entry_add.phys_d_reg && cdb_entry_add.phys_d_reg != '0) begin
                        store_queue[i].phys_r2_valid <= '1;
                    end
                end

                if (cdb_entry_mult.valid) begin
                    if (store_queue[i].phys_r2 == cdb_entry_mult.phys_d_reg && cdb_entry_mult.phys_d_reg != '0) begin
                        store_queue[i].phys_r2_valid <= '1;
                    end
                end

                if (cdb_entry_branch.valid) begin
                    if (store_queue[i].phys_r2 == cdb_entry_branch.phys_d_reg && cdb_entry_branch.phys_d_reg != '0) begin
                        store_queue[i].phys_r2_valid <= '1;
                    end
                end

                if (cdb_entry_mem.valid) begin
                    if (store_queue[i].phys_r2 == cdb_entry_mem.phys_d_reg && cdb_entry_mem.phys_d_reg != '0) begin
                        store_queue[i].phys_r2_valid <= '1;
                    end
                end
            end
            if (branch_resolved) begin
                for (int i = 0; i < STORE_QUEUE_DEPTH; i++) begin
                    store_queue[i].control_bit_map [control_read_ptr[CONTROL_Q_PTR_WIDTH-1 : 0]] <= 1'b0;
                end
            end
        end
    end

    always_comb begin
        SQ_read_ack = '0;
        store_serving_addr = 'x;
        store_serving_wmask = '0;
        store_serving_wdata = '0;
        store_serving_rob_idx = '0;
        serve_store = '0;
        store_serving_rs2_v = '0;
        store_serving_rs1_v = '0;
        store_serving_control_bit_map = '0;
        if (SQ_read_en && !SQ_empty) begin
            serve_store = '1;
            SQ_read_ack = '1;
            store_serving_addr = store_queue[store_queue_read_ptr[STORE_QUEUE_PTR_WIDTH-1:0]].addr;
            store_serving_wmask = store_queue[store_queue_read_ptr[STORE_QUEUE_PTR_WIDTH-1:0]].wmask;
            store_serving_rob_idx = store_queue[store_queue_read_ptr[STORE_QUEUE_PTR_WIDTH-1:0]].rob_idx;
            store_serving_rs1_v = store_queue[store_queue_read_ptr[STORE_QUEUE_PTR_WIDTH-1:0]].rs1_v; // RVFI signals. 
            store_serving_rs2_v = rs2_v_mem;
            store_serving_control_bit_map = store_queue[store_queue_read_ptr[STORE_QUEUE_PTR_WIDTH-1:0]].control_bit_map;
            // store_serving_wdata = rs2_v_mem;
            unique case (store_queue[store_queue_read_ptr[STORE_QUEUE_PTR_WIDTH-1:0]].store_type)
                store_f3_sb: store_serving_wdata[8 *store_queue[store_queue_read_ptr[STORE_QUEUE_PTR_WIDTH-1:0]].addr[1:0] +: 8 ] = rs2_v_mem[7:0];
                store_f3_sh: store_serving_wdata[16*store_queue[store_queue_read_ptr[STORE_QUEUE_PTR_WIDTH-1:0]].addr[1]   +: 16] = rs2_v_mem[15:0];
                store_f3_sw: store_serving_wdata = rs2_v_mem;
                default: store_serving_wdata = '0;
            endcase
        end
    end



endmodule : store_queue