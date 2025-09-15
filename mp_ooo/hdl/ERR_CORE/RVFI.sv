module RVFI
import rv32i_types::*;
import params::*;
#(
    parameter QUEUE_SIZE = ROB_DEPTH
)
(
    input logic clk, rst,
    input logic commit, // comes from ROB
    // input logic [31:0] rvfi_instruction, // comes from FIFO
    // input logic [4:0] rvfi_rs1_addr, // comes from DECODE
    // input logic [4:0] rvfi_rs2_addr, // comes from DECODE
    // input logic [31:0] rvfi_rs1_rdata, // comes from ISSUE (not know on dispatch)
    // input logic [31:0] rvfi_rs2_rdata,
    // input logic [4:0]  rvfi_rd_addr, // DECODE
    // input logic [31:0] rvfi_rd_wdata, // from EXECUTE
    // input logic [31:0] rvfi_pc_rdata, // from FIFO
    // input logic [31:0] rvfi_pc_wdata, // +4, later will need to come from branch EXECUTE. 
    // input logic [31:0] rvfi_mem_addr, // will come from EXECUTE
    // input logic [3:0]  rvfi_mem_rmask, // will come from DECODE
    // input logic [3:0]  rvfi_mem_wmask,
    // input logic [31:0] rvfi_mem_rdata, // will come from EXECUTE
    // input logic [31:0] rvfi_mem_wdata, // will come from ISSUE (not known on dispatch)

    input branch_en,
    input logic rvfi_rob_write_dispatch, // this is write enable for ROB, meaning instruction has been dispatched.
    input logic [ROB_PTR_WIDTH:0] rvfi_rob_write_ptr_dispatch,

    input logic [4:0] rvfi_rs1_s, rvfi_rs2_s, rvfi_rd_s,
    input logic [31:0] rvfi_inst, rvfi_pc_val,

    input logic [31:0] rvfi_rs1_rdata_a, rvfi_rs2_rdata_a, /// these come from execute (ALU)
    input logic [31:0] rvfi_rd_wdata_a,
    input logic [ROB_PTR_WIDTH:0] rvfi_issue_execute_rob_ptr_a,
    input logic rvfi_inst_finished_a,

    input logic [31:0] rvfi_rs1_rdata_m, rvfi_rs2_rdata_m, /// these come from execute (MULT)
    input logic [31:0] rvfi_rd_wdata_m,
    input logic [ROB_PTR_WIDTH:0] rvfi_issue_execute_rob_ptr_m,
    input logic rvfi_inst_finished_m,

    input logic [31:0] rvfi_rs1_rdata_b, rvfi_rs2_rdata_b, // these come from execute (BRANCH)
    input logic [31:0] rvfi_rd_wdata_b,
    input logic [ROB_PTR_WIDTH:0] rvfi_issue_execute_rob_ptr_b,
    input logic rvfi_inst_finished_b,
    input logic [31:0] rvfi_pc_wdata, 

    input logic [31:0] rvfi_rs1_rdata_mem, rvfi_rs2_rdata_mem, // these come from execute (MEM)
    input logic [31:0] rvfi_rd_wdata_mem, 
    input logic [ROB_PTR_WIDTH:0] rvfi_issue_execute_rob_ptr_mem, 
    input logic rvfi_inst_finished_mem,
    input logic [3:0] rvfi_mem_wmask, rvfi_mem_rmask,
    input logic [31:0] rvfi_mem_addr, rvfi_mem_rdata, rvfi_mem_wdata,

    input logic [31:0] rvfi_store_rs1_rdata_mem, rvfi_store_rs2_rdata_mem,
    input logic [31:0] rvfi_store_rd_wdata_mem, 
    input logic rvfi_store_inst_finished_mem,
    input logic [ROB_PTR_WIDTH:0] rvfi_store_issue_execute_rob_ptr_mem,
    input logic [3:0] rvfi_store_mem_wmask, rvfi_store_mem_rmask,
    input logic [31:0] rvfi_store_mem_addr, rvfi_store_mem_rdata, rvfi_store_mem_wdata,

    input logic [ROB_PTR_WIDTH:0] rvfi_ROB_read_ptr, // ROB read_ptr to pop off RVFI. 

    output logic rvfi_commit, 
    output logic [63:0] rvfi_order,
    output RVFI_entry_t RVFI_data
);
    RVFI_entry_t RVFI_array [QUEUE_SIZE];

    logic [63:0] commit_counter;
    assign rvfi_order = commit_counter;
    assign rvfi_commit = commit; 

    always_ff @ (posedge clk) begin
        if (rst) begin
            commit_counter <= '0;
        end else if (commit) begin
            commit_counter <= commit_counter + 'd1;
        end else begin
            commit_counter <= commit_counter;
        end
    end

    always_ff @ (posedge clk) begin
        if (rst) begin
            for (int i = 0; i < QUEUE_SIZE; i++) begin
                RVFI_array[i] <= '0;
            end
        end else begin
            if (rvfi_rob_write_dispatch) begin
                RVFI_array[rvfi_rob_write_ptr_dispatch[ROB_PTR_WIDTH-1:0]].rs1_addr <= rvfi_rs1_s;
                RVFI_array[rvfi_rob_write_ptr_dispatch[ROB_PTR_WIDTH-1:0]].rs2_addr <= rvfi_rs2_s;
                RVFI_array[rvfi_rob_write_ptr_dispatch[ROB_PTR_WIDTH-1:0]].rd_addr <= rvfi_rd_s;
                RVFI_array[rvfi_rob_write_ptr_dispatch[ROB_PTR_WIDTH-1:0]].instruction <= rvfi_inst;
                RVFI_array[rvfi_rob_write_ptr_dispatch[ROB_PTR_WIDTH-1:0]].pc_rdata <= rvfi_pc_val;
                RVFI_array[rvfi_rob_write_ptr_dispatch[ROB_PTR_WIDTH-1:0]].pc_wdata <= rvfi_pc_val + 'd4; // WILL NEED TO BE CHANGED FOR CONTROL FLOW INSTRUCTIONS
                RVFI_array[rvfi_rob_write_ptr_dispatch[ROB_PTR_WIDTH-1:0]].mem_rmask <= '0;
                RVFI_array[rvfi_rob_write_ptr_dispatch[ROB_PTR_WIDTH-1:0]].mem_wmask <= '0;
                RVFI_array[rvfi_rob_write_ptr_dispatch[ROB_PTR_WIDTH-1:0]].mem_addr <= '0; // all 0 for now since no loads or stores
                RVFI_array[rvfi_rob_write_ptr_dispatch[ROB_PTR_WIDTH-1:0]].mem_rdata <= '0;
                RVFI_array[rvfi_rob_write_ptr_dispatch[ROB_PTR_WIDTH-1:0]].mem_wdata <= '0;
            end

            if (rvfi_inst_finished_a) begin
                RVFI_array[rvfi_issue_execute_rob_ptr_a[ROB_PTR_WIDTH-1:0]].rs1_rdata <= rvfi_rs1_rdata_a;
                RVFI_array[rvfi_issue_execute_rob_ptr_a[ROB_PTR_WIDTH-1:0]].rs2_rdata <= rvfi_rs2_rdata_a;
                RVFI_array[rvfi_issue_execute_rob_ptr_a[ROB_PTR_WIDTH-1:0]].rd_wdata <= rvfi_rd_wdata_a;
            end

            if (rvfi_inst_finished_m) begin
                RVFI_array[rvfi_issue_execute_rob_ptr_m[ROB_PTR_WIDTH-1:0]].rs1_rdata <= rvfi_rs1_rdata_m;
                RVFI_array[rvfi_issue_execute_rob_ptr_m[ROB_PTR_WIDTH-1:0]].rs2_rdata <= rvfi_rs2_rdata_m;
                RVFI_array[rvfi_issue_execute_rob_ptr_m[ROB_PTR_WIDTH-1:0]].rd_wdata <= rvfi_rd_wdata_m;
            end

            if (rvfi_inst_finished_b) begin
                RVFI_array[rvfi_issue_execute_rob_ptr_b[ROB_PTR_WIDTH-1:0]].rs1_rdata <= rvfi_rs1_rdata_b;
                RVFI_array[rvfi_issue_execute_rob_ptr_b[ROB_PTR_WIDTH-1:0]].rs2_rdata <= rvfi_rs2_rdata_b;
                RVFI_array[rvfi_issue_execute_rob_ptr_b[ROB_PTR_WIDTH-1:0]].rd_wdata <= rvfi_rd_wdata_b;
                RVFI_array[rvfi_issue_execute_rob_ptr_b[ROB_PTR_WIDTH-1:0]].pc_wdata <= (branch_en) ? rvfi_pc_wdata : RVFI_array[rvfi_issue_execute_rob_ptr_b[ROB_PTR_WIDTH-1:0]].pc_rdata + 'd4;
            end

            if (rvfi_inst_finished_mem) begin
                RVFI_array[rvfi_issue_execute_rob_ptr_mem[ROB_PTR_WIDTH-1:0]].rs1_rdata <= rvfi_rs1_rdata_mem;
                RVFI_array[rvfi_issue_execute_rob_ptr_mem[ROB_PTR_WIDTH-1:0]].rs2_rdata <= rvfi_rs2_rdata_mem;
                RVFI_array[rvfi_issue_execute_rob_ptr_mem[ROB_PTR_WIDTH-1:0]].rd_wdata <= rvfi_rd_wdata_mem; 
                RVFI_array[rvfi_issue_execute_rob_ptr_mem[ROB_PTR_WIDTH-1:0]].mem_addr <= rvfi_mem_addr;
                RVFI_array[rvfi_issue_execute_rob_ptr_mem[ROB_PTR_WIDTH-1:0]].mem_wmask <= rvfi_mem_wmask;
                RVFI_array[rvfi_issue_execute_rob_ptr_mem[ROB_PTR_WIDTH-1:0]].mem_rmask <= rvfi_mem_rmask; 
                RVFI_array[rvfi_issue_execute_rob_ptr_mem[ROB_PTR_WIDTH-1:0]].mem_rdata <= rvfi_mem_rdata;
                RVFI_array[rvfi_issue_execute_rob_ptr_mem[ROB_PTR_WIDTH-1:0]].mem_wdata <= rvfi_mem_wdata;
            end

            if (rvfi_store_inst_finished_mem) begin
                RVFI_array[rvfi_store_issue_execute_rob_ptr_mem[ROB_PTR_WIDTH-1:0]].rs1_rdata <= rvfi_store_rs1_rdata_mem;
                RVFI_array[rvfi_store_issue_execute_rob_ptr_mem[ROB_PTR_WIDTH-1:0]].rs2_rdata <= rvfi_store_rs2_rdata_mem;
                RVFI_array[rvfi_store_issue_execute_rob_ptr_mem[ROB_PTR_WIDTH-1:0]].rd_wdata <= rvfi_store_rd_wdata_mem; 
                RVFI_array[rvfi_store_issue_execute_rob_ptr_mem[ROB_PTR_WIDTH-1:0]].mem_addr <= rvfi_store_mem_addr;
                RVFI_array[rvfi_store_issue_execute_rob_ptr_mem[ROB_PTR_WIDTH-1:0]].mem_wmask <= rvfi_store_mem_wmask;
                RVFI_array[rvfi_store_issue_execute_rob_ptr_mem[ROB_PTR_WIDTH-1:0]].mem_rmask <= rvfi_store_mem_rmask; 
                RVFI_array[rvfi_store_issue_execute_rob_ptr_mem[ROB_PTR_WIDTH-1:0]].mem_rdata <= rvfi_store_mem_rdata;
                RVFI_array[rvfi_store_issue_execute_rob_ptr_mem[ROB_PTR_WIDTH-1:0]].mem_wdata <= rvfi_store_mem_wdata;
            end
        end
    end

    always_comb begin
        if (commit) begin
            RVFI_data = RVFI_array[rvfi_ROB_read_ptr[ROB_PTR_WIDTH-1:0]];
            if (rvfi_store_inst_finished_mem) begin
                RVFI_data.rs1_rdata = rvfi_store_rs1_rdata_mem;
                RVFI_data.rs2_rdata = rvfi_store_rs2_rdata_mem;
                RVFI_data.rd_wdata = rvfi_store_rd_wdata_mem; 
                RVFI_data.mem_addr = rvfi_store_mem_addr;
                RVFI_data.mem_wmask = rvfi_store_mem_wmask;
                RVFI_data.mem_rmask = rvfi_store_mem_rmask; 
                RVFI_data.mem_rdata = rvfi_store_mem_rdata;
                RVFI_data.mem_wdata = rvfi_store_mem_wdata;
            end
        end else begin
            RVFI_data = '0;
        end
    end





endmodule : RVFI
