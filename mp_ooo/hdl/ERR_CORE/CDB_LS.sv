module CDB_mem
import rv32i_types::*;
import params::*;
(
    input   logic           clk,
    input   logic           rst,

    input   logic   load_write,
    input   load_rs_entry_t load_rs_entry,
    input   logic   store_write,
    input   store_queue_entry_t store_queue_entry, 
    input   addr_rs_entry_t addr_rs_entry,

    input   logic [ROB_PTR_WIDTH : 0] ROB_read_ptr,

    output  logic [PHYSICAL_REG_WIDTH - 1:0] rs1_mem, //outputs into Phys Reg File (we don't need rs2 for loads)
    output  logic [PHYSICAL_REG_WIDTH - 1:0] rs2_mem,
    input   logic   [31:0]  rs1_v_mem, 
    input   logic   [31:0]  rs2_v_mem,

    input   logic flush_by_branch,
    input  logic    branch_resolved,
    input  logic [CONTROL_Q_PTR_WIDTH : 0]   control_read_ptr,
    input logic [MEM_QUEUE_PTR_WIDTH : 0] lsq_write_ptr_on_flush,
    input logic [STORE_QUEUE_DEPTH-1:0]     store_q_bitmap_on_flush,

    input   cdb_entry_t     cdb_entry_mult, 
    input   cdb_entry_t     cdb_entry_branch,
    input   cdb_entry_t     cdb_entry_alu,
    output  cdb_entry_t     cdb_entry_mem_out,

    output logic [STORE_QUEUE_DEPTH-1:0] older_store_map, // bit mask to designate 
    output logic [LOAD_RS_INDEX_BITS-1:0] dispatch_load_idx,
    output logic [STORE_QUEUE_PTR_WIDTH-1:0] store_queue_idx,
    output logic addr_rs_full, load_rs_full, store_q_full,
    output logic [MEM_QUEUE_PTR_WIDTH : 0] store_q_wrt_ptr,
    output logic SQ_read_ack_out,
    output logic [MEM_QUEUE_PTR_WIDTH : 0] SQ_read_ptr_out, 
    output logic ROB_store_commit_flag,

    // inputs from D cache
    // input logic [31:0] dmem_raddr, // not needed for now because we force in order memory requests.
    input logic [31:0] dmem_rdata,
    input logic dmem_resp,
    // outputs into D Cache
    output logic [31:0] dmem_addr, dmem_wdata,
    output logic [3:0] dmem_wmask, dmem_rmask,
    
    // rvfi signals
    output logic [31:0] rvfi_rs1_rdata_mem, rvfi_rs2_rdata_mem,
    output logic [31:0] rvfi_rd_wdata_mem, 
    output logic [ROB_PTR_WIDTH:0] rvfi_issue_execute_rob_ptr_mem, 
    output logic rvfi_inst_finished_mem,
    output logic [3:0] rvfi_mem_wmask, rvfi_mem_rmask,
    output logic [31:0] rvfi_mem_addr, rvfi_mem_rdata, rvfi_mem_wdata,

    output logic [31:0] rvfi_store_rs1_rdata_mem, rvfi_store_rs2_rdata_mem,
    output logic [31:0] rvfi_store_rd_wdata_mem, 
    output logic rvfi_store_inst_finished_mem,
    output logic [ROB_PTR_WIDTH:0] rvfi_store_issue_execute_rob_ptr_mem,
    output logic [3:0] rvfi_store_mem_wmask, rvfi_store_mem_rmask,
    output logic [31:0] rvfi_store_mem_addr, rvfi_store_mem_rdata, rvfi_store_mem_wdata
);
    // ADDR_RS signals
    logic [PHYSICAL_REG_WIDTH - 1:0] rs1_mem_wire;
    logic rs_addr_full;
    logic load_address_ready;
    logic store_address_ready;
    logic [LOAD_RS_INDEX_BITS-1:0] load_entry_idx;
    logic [STORE_QUEUE_PTR_WIDTH-1:0] SQ_entry_idx;
    logic [31:0] addr_v_out;
    logic [3:0] rmask;
    logic [3:0] wmask;
    logic [31:0] rs1_v; 
    load_f3_t load_type;
    store_f3_t store_type;

    // LOAD_RS signals
    logic rs_load_full;
    logic [LOAD_RS_INDEX_BITS-1:0] dispatch_load_idx_wire;

    logic [31:0] req_addr;
    logic [3:0] req_rmask;
    logic [4:0] req_arch_d_reg;
    logic [PHYSICAL_REG_FILE_LENGTH-1:0] req_phys_d_reg;
    logic [ROB_PTR_WIDTH:0] req_rob_idx;
    load_f3_t req_load_type;
    logic [31:0] req_rs1_v;
    logic [CONTROL_Q_DEPTH-1:0] req_control_bit_map;
    logic serve_load_req;

    // Store Queue signals
    logic SQ_full, SQ_empty;
    logic [PHYSICAL_REG_WIDTH - 1:0] rs2_mem_wire;
    logic SQ_read_ack;
    logic [31:0] store_serving_addr;
    logic [3:0] store_serving_wmask;
    logic [31:0] store_serving_wdata;
    logic [ROB_PTR_WIDTH:0] store_serving_rob_idx;
    logic [31:0] store_serving_rs1_v, store_serving_rs2_v; 
    logic [CONTROL_Q_DEPTH-1:0] store_serving_control_bit_map;
    logic [STORE_QUEUE_DEPTH-1:0] older_store_map_wire;
    logic [STORE_QUEUE_PTR_WIDTH:0] SQ_read_ptr;
    logic [STORE_QUEUE_PTR_WIDTH-1:0] SQ_idx;
    logic [STORE_QUEUE_PTR_WIDTH :0] SQ_idx_0;
    logic store_able_to_commit; 

    store_queue_entry_t store_queue_out [STORE_QUEUE_DEPTH];
    logic serve_store;
    logic load_ready;
    logic store_ready; 

    logic [CONTROL_Q_DEPTH-1:0] control_bit_map_reg, CDB_control_bit_map_reg; 
    logic flush_fu_by_branch;

    logic [3:0] mem_rmask_reg, mem_rmask;
    logic [3:0] mem_wmask_reg, mem_wmask; 
    logic [ROB_PTR_WIDTH:0] CDB_rob_reg;
    load_f3_t load_f3_reg; 
    logic [1:0] addr_bottom_bits; // needed for load to shift data correctly. 
    logic dmem_resp_reg; // valid
    logic [31:0] dmem_rdata_reg; // rd_v (after shifting and calculation)
    // logic [31:0] actual_dmem_rdata_reg; // raw data you read from memory, passed into RVFI. 
    logic [3:0] rvfi_wmask_reg, rvfi_rmask_reg;

    // rvfi
    logic [31:0] rs1_rdata_reg, rs2_rdata_reg;
    // logic [31:0] rd_wdata_reg;
    logic [ROB_PTR_WIDTH:0] rob_ptr_reg;
    // logic inst_finished_reg;
    logic [31:0] mem_addr_reg, mem_rdata_reg, mem_wdata_reg;

    logic dmem_stall;
    assign dmem_stall = (!dmem_resp && !(mem_wmask_reg == '0 && mem_rmask_reg == '0)) ? 1'b1 : 1'b0;
    cdb_entry_t cdb_entry_mem;
    logic garbage_dmem;
    assign cdb_entry_mem_out = cdb_entry_mem;
    assign dispatch_load_idx = dispatch_load_idx_wire;
    assign load_rs_full = rs_load_full; 
    assign addr_rs_full = rs_addr_full;
    assign store_q_full = SQ_full;
    assign ROB_store_commit_flag = store_able_to_commit;

    assign load_ready = (serve_load_req && !garbage_dmem && !dmem_stall);
    assign store_ready = (serve_store && !garbage_dmem && !dmem_stall);
    assign store_queue_idx = SQ_idx;

    assign rs2_mem = rs2_mem_wire;
    assign rs1_mem = rs1_mem_wire; 
    assign older_store_map = older_store_map_wire;

    assign store_q_wrt_ptr = SQ_idx_0;

    assign flush_fu_by_branch = (flush_by_branch && control_bit_map_reg[control_read_ptr[CONTROL_Q_PTR_WIDTH-1 : 0]] == 1'b1)? 1'b1: 1'b0;

    assign SQ_read_ack_out = SQ_read_ack;
    assign SQ_read_ptr_out = SQ_read_ptr;

    // garbage dmem resp
    always_ff @ (posedge clk) begin
        if (rst) garbage_dmem <= 1'b0;
        // else if (flush_by_branch & (dmem_stall||(read_en && !(mem_rmask == '0 && mem_wmask == '0)))) garbage_dmem <= 1'b1;
        else if (flush_fu_by_branch & (dmem_stall||((store_ready || load_ready) && !(mem_rmask == '0 && mem_wmask == '0)))) garbage_dmem <= 1'b1;
        else if (dmem_resp) garbage_dmem <= 1'b0;
    end
    
    // dmem_signals
    always_comb begin
        mem_rmask = '0;
        mem_wmask = '0;
        if (store_ready) begin 
            mem_wmask = store_serving_wmask;
        end else if (load_ready) begin
            mem_rmask = req_rmask;
        end 
    end

    logic [31:0] dmem_wdata_out; // intermediate variable so we can pass it to RVFI as well. 
    always_comb begin
        dmem_addr = 'x;
        dmem_rmask = '0;
        dmem_wmask = '0;
        dmem_wdata_out = 'x;
        if (!store_ready && !load_ready) begin
            dmem_rmask = '0;
            dmem_wmask = '0;
        end else if (store_ready) begin
            dmem_wmask = mem_wmask;
            dmem_addr = {store_serving_addr[31:2], 2'b00}; // align the address to 4 bytes
            dmem_wdata_out = store_serving_wdata;
        end else if (load_ready) begin
            dmem_rmask = mem_rmask; 
            dmem_addr = {req_addr[31:2], 2'b00}; // align the address to 4 bytes
            dmem_wdata_out = '0;
        end
    end

    assign dmem_wdata = dmem_wdata_out;

    // post response calculation on loads for CDB. 
    always_ff @ (posedge clk) begin
        if (rst | flush_fu_by_branch) begin
            dmem_rdata_reg <= '0;
            // actual_dmem_rdata_reg <= '0;
        end else begin
            if (dmem_resp && !garbage_dmem) begin
                if (mem_rmask_reg != '0) begin // load
                    // actual_dmem_rdata_reg <= dmem_rdata; 
                    unique case(load_f3_reg)
                        load_f3_lb: dmem_rdata_reg <= {{24{dmem_rdata[7 +8 *addr_bottom_bits[1:0]]}}, dmem_rdata[8 *addr_bottom_bits[1:0] +: 8 ]};
                        load_f3_lbu: dmem_rdata_reg <= {{24{1'b0}}, dmem_rdata[8 *addr_bottom_bits[1:0] +: 8 ]};
                        load_f3_lh: dmem_rdata_reg <= {{16{dmem_rdata[15+16*addr_bottom_bits[1]  ]}}, dmem_rdata[16*addr_bottom_bits[1]   +: 16]};
                        load_f3_lhu: dmem_rdata_reg <= {{16{1'b0}}, dmem_rdata[16*addr_bottom_bits[1]   +: 16]};
                        load_f3_lw: dmem_rdata_reg <= dmem_rdata;
                        default: dmem_rdata_reg <= 'x;
                    endcase
                end else begin // store
                    // actual_dmem_rdata_reg <= '0;
                    dmem_rdata_reg <= '0;
                end
            end 
        end
    end

    always_ff @ (posedge clk) begin
        if (rst | flush_fu_by_branch) begin
            dmem_resp_reg <= '0;
        end else begin
            if (dmem_resp) begin
                dmem_resp_reg <= '1;
            end else begin
                dmem_resp_reg <= '0;
            end
        end
    end

    // ------------ RVFI ----------------------------------------
    always_ff @ (posedge clk) begin // on read enable, latch basically everything other than mem_rdata, rd_wdata
        // if (store_ready) begin
        //     rvfi_wmask_reg <= store_serving_wmask;
        //     rvfi_rmask_reg <= '0;
        //     rs1_rdata_reg <= store_serving_rs1_v;
        //     rs2_rdata_reg <= store_serving_rs2_v;
        //     rob_ptr_reg   <= store_serving_rob_idx; // store rob ptr before pop
        //     mem_addr_reg  <= store_serving_addr;
        //     mem_wdata_reg <= store_serving_wdata;
        // end else 
        if (load_ready) begin // actual load request
            rvfi_wmask_reg <= '0;
            rvfi_rmask_reg <= req_rmask;
            rs1_rdata_reg <= req_rs1_v;
            rs2_rdata_reg <= '0;
            rob_ptr_reg   <= req_rob_idx; // store rob ptr before pop
            mem_addr_reg  <= req_addr;
            mem_wdata_reg <= '0;
            load_f3_reg <= req_load_type;
        end
    end

    logic req_finished; 
    assign rvfi_inst_finished_mem = req_finished;

    assign req_finished = (dmem_resp && !garbage_dmem && mem_rmask_reg != '0);

    logic [31:0] rvfi_rd_wdata_tmp; // processed load data we send to RVFI rd_wdata. 
    always_comb begin
        if (dmem_resp && !garbage_dmem) begin
            if (mem_rmask_reg != '0) begin
                unique case(load_f3_reg)
                    load_f3_lb: rvfi_rd_wdata_tmp = {{24{dmem_rdata[7 +8 *addr_bottom_bits[1:0]]}}, dmem_rdata[8 *addr_bottom_bits[1:0] +: 8 ]};
                    load_f3_lbu: rvfi_rd_wdata_tmp = {{24{1'b0}}, dmem_rdata[8 *addr_bottom_bits[1:0] +: 8 ]};
                    load_f3_lh: rvfi_rd_wdata_tmp = {{16{dmem_rdata[15+16*addr_bottom_bits[1]  ]}}, dmem_rdata[16*addr_bottom_bits[1]   +: 16]};
                    load_f3_lhu: rvfi_rd_wdata_tmp = {{16{1'b0}}, dmem_rdata[16*addr_bottom_bits[1]   +: 16]};
                    load_f3_lw: rvfi_rd_wdata_tmp = dmem_rdata;
                    default: rvfi_rd_wdata_tmp = 'x;
                endcase
            end else begin
                rvfi_rd_wdata_tmp = '0;
            end
        end else begin
            rvfi_rd_wdata_tmp = 'x;
        end 
    end

    // passing RVFI signals. 
    always_comb begin
        if ((dmem_resp && !garbage_dmem) && mem_rmask_reg != '0) begin // same cycle as response, provide data to RVFI. 
            rvfi_rs1_rdata_mem = rs1_rdata_reg;
            rvfi_rs2_rdata_mem = rs2_rdata_reg;
            rvfi_rd_wdata_mem = rvfi_rd_wdata_tmp;
            rvfi_issue_execute_rob_ptr_mem = rob_ptr_reg;
            rvfi_mem_wmask = rvfi_wmask_reg;
            rvfi_mem_rmask = rvfi_rmask_reg;
            rvfi_mem_addr = mem_addr_reg;
            rvfi_mem_rdata = dmem_rdata;
            rvfi_mem_wdata = mem_wdata_reg;
        end 
        else begin
            rvfi_rs1_rdata_mem = '0;
            rvfi_rs2_rdata_mem = '0;
            rvfi_rd_wdata_mem = '0;
            rvfi_issue_execute_rob_ptr_mem = '0;
            rvfi_mem_wmask = '0;
            rvfi_mem_rmask = '0;
            rvfi_mem_addr = '0;
            rvfi_mem_rdata = '0;
            rvfi_mem_wdata = '0;
        end
    end

    always_comb begin
        rvfi_store_rs1_rdata_mem = '0;
        rvfi_store_rs2_rdata_mem = '0;
        rvfi_store_rd_wdata_mem = '0;
        rvfi_store_mem_wmask = '0;
        rvfi_store_mem_rmask = '0;
        rvfi_store_mem_addr = '0;
        rvfi_store_mem_rdata = '0;
        rvfi_store_mem_wdata = '0;
        rvfi_store_inst_finished_mem = '0;
        rvfi_store_issue_execute_rob_ptr_mem = '0;
        if (store_ready) begin
            rvfi_store_inst_finished_mem = '1;
            rvfi_store_rs1_rdata_mem = store_serving_rs1_v;
            rvfi_store_rs2_rdata_mem = store_serving_rs2_v;
            rvfi_store_issue_execute_rob_ptr_mem = store_serving_rob_idx;
            rvfi_store_rd_wdata_mem = '0;
            rvfi_store_mem_wmask = store_serving_wmask;
            rvfi_store_mem_rmask = '0;
            rvfi_store_mem_addr = store_serving_addr;
            rvfi_store_mem_rdata = '0;
            rvfi_store_mem_wdata = store_serving_wdata;
        end 
    end



    // ---------------RVFI ----------------------------------------------------

    // -------------------------------CDB-------------------------------------
    logic [ROB_PTR_WIDTH:0]                 CDB_load_req_rob_idx1;
    logic [4:0]                             CDB_load_req_arch_d_reg1;
    logic [PHYSICAL_REG_FILE_LENGTH-1:0]    CDB_load_req_phys_d_reg1;
    logic [CONTROL_Q_DEPTH-1:0]             CDB_load_control_bit_map_reg1;

    logic [ROB_PTR_WIDTH:0]                 CDB_load_req_rob_idx2;
    logic [4:0]                             CDB_load_req_arch_d_reg2;
    logic [PHYSICAL_REG_FILE_LENGTH-1:0]    CDB_load_req_phys_d_reg2;
    logic [CONTROL_Q_DEPTH-1:0]             CDB_load_control_bit_map_reg2;

    logic [ROB_PTR_WIDTH:0]                 CDB_store_req_rob_idx;
    logic [CONTROL_Q_DEPTH-1:0]             CDB_store_control_bit_map_reg;
    always_ff @ (posedge clk) begin
        if (rst |flush_fu_by_branch) begin
            mem_wmask_reg <= '0;
            mem_rmask_reg <= '0;
            control_bit_map_reg <= '0;
        end 
        else if (store_ready) begin
            mem_wmask_reg <= store_serving_wmask;
            mem_rmask_reg <= '0;
            control_bit_map_reg <= store_serving_control_bit_map;
        end else if (load_ready) begin
            mem_rmask_reg <= req_rmask;
            mem_wmask_reg <= '0;
            control_bit_map_reg <= req_control_bit_map;
        end else if (dmem_resp && !store_ready && !load_ready) begin
            mem_rmask_reg <= '0;
            mem_wmask_reg <= '0;
            control_bit_map_reg <= '0;
        end
        if (branch_resolved) control_bit_map_reg[control_read_ptr[CONTROL_Q_PTR_WIDTH-1 : 0]] <= 1'b0;
    end

    logic load_req_finished, store_req_finished;
    always_ff @ (posedge clk) begin
        if (rst | flush_fu_by_branch) begin
            load_req_finished <= '0;
        end else if (dmem_resp && !garbage_dmem && mem_rmask_reg != '0) begin
            load_req_finished <= '1;
        end 
        else begin
            load_req_finished <= '0;
        end
    end

    // setting CDB
    always_comb begin
        cdb_entry_mem = '0;
        if (dmem_resp_reg && load_req_finished) begin
            cdb_entry_mem.valid = '1;
            cdb_entry_mem.rob_idx = CDB_load_req_rob_idx2;
            cdb_entry_mem.arch_d_reg = CDB_load_req_arch_d_reg2;
            cdb_entry_mem.phys_d_reg = CDB_load_req_phys_d_reg2;
            cdb_entry_mem.rd_v = dmem_rdata_reg;
            cdb_entry_mem.control_bit_map = CDB_load_control_bit_map_reg2;
        end
    end

    always_ff @ (posedge clk) begin
        if (rst | flush_fu_by_branch) begin
            addr_bottom_bits <= '0;
        end 
        else if (load_ready) begin
            addr_bottom_bits <= req_addr[1:0];
        end 
    end

    always_ff @ (posedge clk) begin
        if (rst |flush_fu_by_branch) begin
            CDB_load_req_rob_idx1 <= '0;
            CDB_load_req_arch_d_reg1 <= '0;
            CDB_load_req_phys_d_reg1 <= '0;
        end else if (load_ready) begin
            CDB_load_req_rob_idx1 <= req_rob_idx;
            CDB_load_req_arch_d_reg1 <= req_arch_d_reg;
            CDB_load_req_phys_d_reg1 <= req_phys_d_reg;
            CDB_load_control_bit_map_reg1 <= req_control_bit_map;
        end
    end

    always_ff @ (posedge clk) begin
        if (rst |flush_fu_by_branch) begin
            CDB_load_req_rob_idx2 <= '0;
            CDB_load_req_arch_d_reg2 <= '0;
            CDB_load_req_phys_d_reg2 <= '0;
            CDB_load_control_bit_map_reg2 <= '0;
        end else begin
            CDB_load_req_rob_idx2 <= CDB_load_req_rob_idx1;
            CDB_load_req_arch_d_reg2 <= CDB_load_req_arch_d_reg1;
            CDB_load_req_phys_d_reg2 <= CDB_load_req_phys_d_reg1;
            CDB_load_control_bit_map_reg2 <= CDB_load_control_bit_map_reg1;
        end
    end

    // --------------------------------CDB-----------------------------------

    ADDR_RS ADDR_RS_inst (
        .clk(clk),
        .rst(rst),

        .load_write(load_write),
        .store_write(store_write),
        .addr_rs_entry(addr_rs_entry),

        .flush_by_branch(flush_by_branch),
        .branch_resolved(branch_resolved),
        .control_read_ptr(control_read_ptr),
        
        .rs1_v_mem(rs1_v_mem), // input from reg file.  

        .cdb_entry_mult(cdb_entry_mult), 
        .cdb_entry_br(cdb_entry_branch),
        .cdb_entry_alu(cdb_entry_alu),
        .cdb_entry_mem(cdb_entry_mem),

        .rs_addr_full(rs_addr_full),
        .rs1_mem(rs1_mem_wire),
        .load_address_ready(load_address_ready), 
        .store_address_ready(store_address_ready),
        .load_entry_idx(load_entry_idx),
        .SQ_entry_idx(SQ_entry_idx),
        .addr_v_out(addr_v_out),
        .rmask(rmask),
        .wmask(wmask),
        .rs1_v(rs1_v),
        .load_type(load_type),
        .store_type(store_type)
    );

    LOAD_RS LOAD_RS_inst (
        .clk(clk),
        .rst(rst),

        .load_write(load_write), // from dispatch
        .load_rs_entry(load_rs_entry),

        .flush_by_branch(flush_by_branch),
        .branch_resolved(branch_resolved),
        .control_read_ptr(control_read_ptr),

        .SQ_read_ack(SQ_read_ack), 
        .SQ_read_ptr(SQ_read_ptr),
        .dmem_stall(dmem_stall),

        .rs_load_full(rs_load_full), // output to dispatch to not make it dispatch a load inst.
        .dispatch_load_idx(dispatch_load_idx_wire), // next available entry, used by ADDR RS to remember where to update the LOAD RS with calculated address. 

        .load_address_ready(load_address_ready), // signal to tell load_rs to update one of its entries
        .load_entry_idx(load_entry_idx), 
        .addr_v_in(addr_v_out),
        .rmask_in(rmask),
        .rs1_v(rs1_v),
        .load_type(load_type),
        .garbage_dmem(garbage_dmem),

        .req_addr(req_addr),
        .req_rmask(req_rmask),
        .req_arch_d_reg(req_arch_d_reg),
        .req_phys_d_reg(req_phys_d_reg),
        .req_rob_idx(req_rob_idx),
        .req_load_type(req_load_type),
        .req_rs1_v(req_rs1_v),
        .req_control_bit_map(req_control_bit_map),
        .serve_load_req(serve_load_req),

        .store_queue(store_queue_out)
    );

    store_queue SQ_inst (
        .clk(clk),
        .rst(rst),

        .flush_by_branch(flush_by_branch),
        .branch_resolved(branch_resolved),
        .control_read_ptr(control_read_ptr),

        .store_write(store_write),
        .store_queue_entry(store_queue_entry),

        .cdb_entry_mult(cdb_entry_mult), 
        .cdb_entry_branch(cdb_entry_branch),
        .cdb_entry_add(cdb_entry_alu),
        .cdb_entry_mem(cdb_entry_mem),

        .dmem_stall(dmem_stall),
        .ROB_read_ptr(ROB_read_ptr), // stores will only be popped once phys_r2 is valid and the store instruction has reached head of the ROB. 

        .SQ_full(SQ_full),
        .SQ_empty(SQ_empty),

        .rs2_v_mem(rs2_v_mem), // phys reg file. 
        .rs2_mem(rs2_mem_wire),

        .store_address_ready(store_address_ready), // signal to tell store_queue to update one of its entries
        .SQ_entry_idx(SQ_entry_idx),
        .addr_v_in(addr_v_out),
        .wmask_in(wmask), 
        .rs1_v(rs1_v),
        .store_type(store_type),
        .garbage_dmem(garbage_dmem),

        .lsq_write_ptr_on_flush(lsq_write_ptr_on_flush),
        .store_q_bitmap_on_flush(store_q_bitmap_on_flush),

        .SQ_read_ack(SQ_read_ack),
        .serve_store(serve_store),
        .SQ_read_ptr(SQ_read_ptr),
        .store_serving_addr(store_serving_addr),
        .store_serving_wmask(store_serving_wmask),
        .store_serving_wdata(store_serving_wdata),
        .store_serving_rob_idx(store_serving_rob_idx),
        .store_serving_rs1_v(store_serving_rs1_v),
        .store_serving_rs2_v(store_serving_rs2_v),
        .store_serving_control_bit_map(store_serving_control_bit_map),
        .store_able_to_commit(store_able_to_commit),

        .older_store_map(older_store_map_wire),
        .store_queue_out(store_queue_out),
        .SQ_idx_0(SQ_idx_0),
        .SQ_idx(SQ_idx)
    );




endmodule : CDB_mem
