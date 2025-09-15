module LOAD_RS 
import rv32i_types::*;
import params::*;
(
    input   logic           clk,
    input   logic           rst,

    input   logic   load_write, // from dispatch
    input   load_rs_entry_t load_rs_entry,

    input  logic   flush_by_branch,
    input  logic    branch_resolved,
    input  logic [CONTROL_Q_PTR_WIDTH : 0]   control_read_ptr,

    input  logic   SQ_read_ack, // prioritize stores over loads.
    input  [STORE_QUEUE_PTR_WIDTH:0] SQ_read_ptr,
    input logic dmem_stall, 

    output logic   rs_load_full, // output to dispatch to not make it dispatch a load inst.
    output logic [LOAD_RS_INDEX_BITS-1:0] dispatch_load_idx, // next available entry, used by ADDR RS to remember where to update the LOAD RS with calculated address. 

    input logic load_address_ready, // signal to tell load_rs to update one of its entries
    input logic [LOAD_RS_INDEX_BITS-1:0] load_entry_idx, 
    input logic [31:0] addr_v_in,
    input logic [3:0] rmask_in,
    input logic [31:0] rs1_v,
    input load_f3_t load_type,

    // non-block cache
    input logic [LOAD_RS_INDEX_BITS-1:0] dcache_load_idx,
    input logic dmem_resp,
    input logic dmem_resp_type,

    output logic [ROB_PTR_WIDTH:0] load_finished_rob_idx,
    output logic [4:0] load_finished_arch_d_reg,
    output logic [PHYSICAL_REG_FILE_LENGTH-1:0] load_finished_phys_d_reg,
    output logic [CONTROL_Q_DEPTH-1:0] load_finished_control_bit_map,
    output logic [1:0] load_finished_addr_bottom_bits,
    output logic load_finished_garbage_dmem,
    output load_f3_t load_finished_load_type,
    output logic [31:0] load_finished_rs1_v,
    output logic [31:0] load_finished_addr,
    output logic [3:0] load_finished_rmask,


    output logic [31:0] req_addr,
    output logic [3:0] req_rmask,
    output logic [4:0] req_arch_d_reg,
    output logic [PHYSICAL_REG_FILE_LENGTH-1:0] req_phys_d_reg,
    output logic [ROB_PTR_WIDTH:0] req_rob_idx,
    output load_f3_t req_load_type,
    output logic [31:0] req_rs1_v,
    output logic [CONTROL_Q_DEPTH-1:0] req_control_bit_map,
    // output logic serve_load,
    output logic serve_load_req,

    input  store_queue_entry_t store_queue [STORE_QUEUE_DEPTH],

    output load_rs_entry_t load_rs_out [LOAD_RS_NUM],
    output logic [LOAD_RS_INDEX_BITS-1:0] serve_load_idx
);

    load_rs_entry_t reservation_stations [LOAD_RS_NUM];
    assign load_rs_out = reservation_stations;
    // logic begin_serving;
    // logic [LOAD_RS_INDEX_BITS-1:0] serving_idx; // not going to have more than 16 RSs
    logic begin_load_req;
    logic [LOAD_RS_INDEX_BITS-1:0] req_idx; 
    logic rs_full;

    always_ff @(posedge clk) begin

        if(rst) begin
            for (int i = 0; i < LOAD_RS_NUM; i++) begin
                reservation_stations[i].finished <= '1;
                reservation_stations[i].rmask <= '0;
                reservation_stations[i].addr <= '0;
                reservation_stations[i].arch_d_reg <= '0;
                reservation_stations[i].phys_d_reg <= '0;
                reservation_stations[i].rob_idx <= '0;
                reservation_stations[i].store_bitmap <= '0;
                reservation_stations[i].valid_addr <= '0;
                reservation_stations[i].load_type <= load_f3_lb;
                reservation_stations[i].req_sent <= '0;
                reservation_stations[i].garbage_dmem <= '0;
                reservation_stations[i].control_bit_map <= '0;
            end 
        end
        else begin
            if (flush_by_branch) begin
                for (int i = 0; i < LOAD_RS_NUM; i++) begin
                    if (reservation_stations[i].control_bit_map[control_read_ptr[CONTROL_Q_PTR_WIDTH-1 : 0]] == 1'b1) begin
                        // reservation_stations[i].finished <= 1'b1;
                        if (!reservation_stations[i].req_sent) begin
                            reservation_stations[i].finished <= 1'b1;
                        end
                        reservation_stations[i].garbage_dmem <= 1'b1;
                    end
                end
            end
            else if(!rs_full & load_write) begin // on a load write, populate the next available entry. 
                reservation_stations[dispatch_load_idx] <= load_rs_entry;
            end

            if (load_address_ready) begin
                reservation_stations[load_entry_idx].addr <= addr_v_in;
                reservation_stations[load_entry_idx].rmask <= rmask_in;
                reservation_stations[load_entry_idx].valid_addr <= '1;
                reservation_stations[load_entry_idx].rs1_v <= rs1_v;
                reservation_stations[load_entry_idx].load_type <= load_type;
                // if (SQ_read_ack) begin
                //     reservation_stations[load_entry_idx].store_bitmap[SQ_read_ptr[STORE_QUEUE_PTR_WIDTH-1:0]] <= 1'b0;
                // end
            end

            if (SQ_read_ack) begin
                for (int i = 0; i < LOAD_RS_NUM; i++) begin
                    // if (reservation_stations[i].valid_addr) begin
                        reservation_stations[i].store_bitmap[SQ_read_ptr[STORE_QUEUE_PTR_WIDTH-1:0]] <= 1'b0;
                    // end
                end
            end

            // if (begin_load_req && !garbage_dmem) begin // done as soon as a load is ready, it's the job of CDB_LS to hold onto the resp. 
            // if (begin_load_req) begin
            
            if (begin_load_req) begin
                reservation_stations[req_idx].req_sent <= '1;
            end

            if (dmem_resp) begin
                if (!dmem_resp_type) begin
                    reservation_stations[dcache_load_idx].finished <= 1'b1; // finish next cycle after receiving rs1 since address is now known. 
                end
            end

            // check if older stores who have address ready have either finished or they don't have dependent address. 
            for (int i = 0; i < LOAD_RS_NUM; i++) begin
                for (int j = 0; j < STORE_QUEUE_DEPTH; j++) begin
                    if (reservation_stations[i].store_bitmap[j] && reservation_stations[i].valid_addr && store_queue[j].valid_addr && ((reservation_stations[i].addr[31:2] != store_queue[j].addr[31:2]) || ~|(reservation_stations[i].rmask & store_queue[j].wmask))) begin
                        reservation_stations[i].store_bitmap[j] <= 1'b0;
                    end
                end
            end

            if (branch_resolved) begin
                for (int i = 0; i < LOAD_RS_NUM; i++) begin 
                    reservation_stations[i].control_bit_map[control_read_ptr[CONTROL_Q_PTR_WIDTH-1 : 0]] <= 1'b0;
                end
            end
        end

    end

    // figure out which index we need to send as a request. 
    always_comb begin
        begin_load_req = '0;
        req_idx = '0;
        if ( flush_by_branch) begin
            begin_load_req = '0;
            req_idx   = '0;
        end
        else begin
            if (!SQ_read_ack) begin
                for (int unsigned i = 0; i < LOAD_RS_NUM; i++) begin
                    if (reservation_stations[i].valid_addr && reservation_stations[i].store_bitmap == '0 && !dmem_stall && !reservation_stations[i].req_sent && !reservation_stations[i].garbage_dmem) begin
                        begin_load_req = '1;
                        req_idx = LOAD_RS_INDEX_BITS'(i);
                    end
                end
            end
        end
    end

    // output the correct values for an actual load request.
   
    always_comb begin
        req_addr = '0;
        req_rmask = '0;
        req_arch_d_reg = '0;
        req_phys_d_reg = '0;
        req_rob_idx = '0;
        req_load_type = load_f3_lb;
        req_rs1_v = '0;
        req_control_bit_map = '0;
        serve_load_idx = '0;
        if (begin_load_req && !SQ_read_ack) begin
            req_addr = reservation_stations[req_idx].addr;
            req_rmask = reservation_stations[req_idx].rmask;
            req_arch_d_reg = reservation_stations[req_idx].arch_d_reg;
            req_phys_d_reg = reservation_stations[req_idx].phys_d_reg;
            req_rob_idx = reservation_stations[req_idx].rob_idx;
            req_load_type = reservation_stations[req_idx].load_type;
            req_rs1_v = reservation_stations[req_idx].rs1_v;
            req_control_bit_map = reservation_stations[req_idx].control_bit_map;
            serve_load_idx = req_idx;
        end
    end
    // assign serve_load_req = begin_load_req && !garbage_dmem;
    assign serve_load_req = begin_load_req;

    
    // dispatch_load_idx logic
    always_comb begin
        rs_full = '1;
        dispatch_load_idx = '0;
        for (int unsigned i = 0; i < LOAD_RS_NUM; i++) begin
            if (reservation_stations[i].finished == 1'b1) begin
                rs_full = '0;
                dispatch_load_idx = LOAD_RS_INDEX_BITS'(i);
                break;
            end 
        end
    end

    assign rs_load_full = rs_full;

    always_comb begin
        load_finished_arch_d_reg = reservation_stations[dcache_load_idx].arch_d_reg;
        load_finished_phys_d_reg = reservation_stations[dcache_load_idx].phys_d_reg;
        load_finished_rob_idx = reservation_stations[dcache_load_idx].rob_idx;
        load_finished_control_bit_map = reservation_stations[dcache_load_idx].control_bit_map;
        load_finished_addr_bottom_bits = reservation_stations[dcache_load_idx].addr[1:0];
        load_finished_garbage_dmem = reservation_stations[dcache_load_idx].garbage_dmem;
        load_finished_load_type = reservation_stations[dcache_load_idx].load_type;
        load_finished_addr = reservation_stations[dcache_load_idx].addr;
        load_finished_rs1_v = reservation_stations[dcache_load_idx].rs1_v;
        load_finished_rmask = reservation_stations[dcache_load_idx].rmask;
    end
    
endmodule : LOAD_RS
