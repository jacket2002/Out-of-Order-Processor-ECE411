module ADDR_RS 
import rv32i_types::*;
import params::*;
(
    input   logic           clk,
    input   logic           rst,

    // input   logic   mem_write, // from dispatch
    input   logic           load_write,
    input   logic           store_write,
    input   addr_rs_entry_t addr_rs_entry,

    input  logic   flush_by_branch,
    input  logic    branch_resolved,
    input  logic [CONTROL_Q_PTR_WIDTH : 0]   control_read_ptr,

    output  logic [PHYSICAL_REG_WIDTH - 1:0] rs1_mem, // phys reg file ports
    input   logic   [31:0]  rs1_v_mem, 

    input   cdb_entry_t     cdb_entry_mult, 
    input   cdb_entry_t     cdb_entry_br,
    input   cdb_entry_t     cdb_entry_alu,
    input   cdb_entry_t     cdb_entry_mem,
    // output  cdb_entry_t     cdb_entry_mem_out, // CDB out
    output  logic   rs_addr_full, // output to dispatch
    
    output logic load_address_ready, // signal to tell load_rs to update one of its entries
    output logic store_address_ready, // signal to tell store_queue to update one of its entries
    output logic [LOAD_RS_INDEX_BITS-1:0] load_entry_idx,
    output logic [STORE_QUEUE_PTR_WIDTH-1:0] SQ_entry_idx,
    output load_f3_t load_type,
    output store_f3_t store_type,
    output logic [31:0] addr_v_out,
    output logic [3:0] rmask,
    output logic [3:0] wmask,
    output logic [31:0] rs1_v
);

    addr_rs_entry_t reservation_stations [ADDR_RS_NUM];
    logic begin_serving;
    logic [ADDR_RS_INDEX_BITS-1:0] serving_idx; // not going to have more than 16 RSs
    logic rs_full;

    always_ff @(posedge clk) begin

        if(rst) begin
            for (int i = 0; i < ADDR_RS_NUM; i++) begin
                reservation_stations[i].finished <= 1'b1;
                reservation_stations[i].load_store <= 1'b0;
                reservation_stations[i].load_type <= load_f3_lb;
                reservation_stations[i].store_type <= store_f3_sb;
                reservation_stations[i].imm <= '0;
                reservation_stations[i].arch_d_reg <= '0;
                reservation_stations[i].phys_d_reg <= '0;
                reservation_stations[i].phys_r1 <= '0;
                reservation_stations[i].phys_r2 <= '0;
                reservation_stations[i].phys_r1_valid <= '0;
                reservation_stations[i].phys_r2_valid <= '0;
                reservation_stations[i].load_rs_idx <= '0;
                reservation_stations[i].store_q_idx <= '0;
                reservation_stations[i].rob_idx <= '0;
            end 
        end
        else begin
            if (flush_by_branch) begin
                for (int i = 0; i < ADDR_RS_NUM; i++) begin
                    if (reservation_stations[i].control_bit_map[control_read_ptr[CONTROL_Q_PTR_WIDTH-1 : 0]] == 1'b1) begin
                        reservation_stations[i].finished <= 1'b1;
                    end
                end
            end

            else if(!rs_full & (load_write || store_write)) begin
                for (int i = 0; i < ADDR_RS_NUM; i++) begin
                    if (reservation_stations[i].finished == 1'b1) begin
                        reservation_stations[i] <= addr_rs_entry;
                        break;
                    end
                end 
            end

            if (begin_serving) begin
                reservation_stations[serving_idx].finished <= 1'b1; // finish next cycle after receiving rs1 since address is now known. 
            end
            //  exec finished, set corresponding finish to 1; set invalid operand to valid
            for (int i = 0; i < ADDR_RS_NUM; i++) begin
                if (reservation_stations[i].finished == 1'b0) begin
                    if (cdb_entry_alu.valid) begin
                        if (cdb_entry_alu.phys_d_reg == reservation_stations[i].phys_r1) begin
                            reservation_stations[i].phys_r1_valid <= 1'b1;
                        end
                        if (cdb_entry_alu.phys_d_reg == reservation_stations[i].phys_r2) begin
                            reservation_stations[i].phys_r2_valid <= 1'b1;
                        end
                    end 
                
                    if (cdb_entry_br.valid) begin
                    // for (int i = 0; i < ALU_RS_NUM; i++) begin
                        if (cdb_entry_br.phys_d_reg == reservation_stations[i].phys_r1) begin
                            reservation_stations[i].phys_r1_valid <= 1'b1;
                        end
                        if (cdb_entry_br.phys_d_reg == reservation_stations[i].phys_r2) begin
                            reservation_stations[i].phys_r2_valid <= 1'b1;
                        end
                    end 

                    if (cdb_entry_mult.valid) begin
                    // for (int i = 0; i < ALU_RS_NUM; i++) begin
                        if (cdb_entry_mult.phys_d_reg == reservation_stations[i].phys_r1) begin
                            reservation_stations[i].phys_r1_valid <= 1'b1;
                        end
                        if (cdb_entry_mult.phys_d_reg == reservation_stations[i].phys_r2) begin
                            reservation_stations[i].phys_r2_valid <= 1'b1;
                        end
                    end 

                    if (cdb_entry_mem.valid) begin
                        if (cdb_entry_mem.phys_d_reg == reservation_stations[i].phys_r1) begin
                            reservation_stations[i].phys_r1_valid <= 1'b1;
                        end
                        if (cdb_entry_mem.phys_d_reg == reservation_stations[i].phys_r2) begin
                            reservation_stations[i].phys_r2_valid <= 1'b1;
                        end
                    end
                end
            end
            if (branch_resolved) begin
                for (int i = 0; i < ADDR_RS_NUM; i++) begin 
                    reservation_stations[i].control_bit_map[control_read_ptr[CONTROL_Q_PTR_WIDTH-1 : 0]] <= 1'b0;
                end
            end
        end
    end

    // figure out which to serve
    always_comb begin
        begin_serving = '0;
        serving_idx   = '0;
        // if ( flush_by_branch) begin
        //     begin_serving = '0;
        //     serving_idx   = '0;
        // end
        // else begin
            for (int unsigned i = 0; i < ADDR_RS_NUM; i++) begin
                if (reservation_stations[i].phys_r1_valid && !reservation_stations[i].finished) begin
                    begin_serving = '1;
                    serving_idx = ADDR_RS_INDEX_BITS'(i);
                    // serving_idx = i;
                    break;
                end
            end
        // end
    end

    assign rs1_mem = reservation_stations[serving_idx].phys_r1;

    // logic on outputs to load_rs or store_queue
    always_comb begin
        load_address_ready = '0;
        store_address_ready = '0;
        addr_v_out = 'x;
        load_entry_idx = 'x;
        SQ_entry_idx = 'x;
        rmask = '0;
        wmask = '0;
        rs1_v = '0;
        load_type = load_f3_lb;
        store_type = store_f3_sb;
        if (begin_serving) begin
            rs1_v = rs1_v_mem; 
            addr_v_out = rs1_v_mem + reservation_stations[serving_idx].imm;
            if (!reservation_stations[serving_idx].load_store) begin // load address ready
                load_address_ready = '1;
                load_entry_idx = reservation_stations[serving_idx].load_rs_idx;
                load_type = reservation_stations[serving_idx].load_type;
                unique case(reservation_stations[serving_idx].load_type) 
                    load_f3_lb: begin
                        rmask = 4'b0001 << addr_v_out[1:0];
                    end
                    load_f3_lbu: begin
                        rmask = 4'b0001 << addr_v_out[1:0];
                    end
                    load_f3_lh: begin
                        rmask = 4'b0011 << addr_v_out[1:0];
                    end
                    load_f3_lhu: begin
                        rmask = 4'b0011 << addr_v_out[1:0];
                    end
                    load_f3_lw: begin
                        rmask = 4'b1111;
                    end
                    default: rmask = '0;
                endcase
            end else begin
                store_address_ready = '1;
                SQ_entry_idx = reservation_stations[serving_idx].store_q_idx;
                store_type = reservation_stations[serving_idx].store_type;
                unique case (reservation_stations[serving_idx].store_type)
                    store_f3_sb: wmask = 4'b0001 << addr_v_out[1:0];
                    store_f3_sh: wmask = 4'b0011 << addr_v_out[1:0];
                    store_f3_sw: wmask = 4'b1111;
                    default: wmask = '0;
                endcase
            end
        end
    end

    // full logic
    always_comb begin
        rs_full = '1;
        for (int i = 0; i < ADDR_RS_NUM; i++) begin
            if (reservation_stations[i].finished == 1'b1) begin
                rs_full = '0;
                break;
            end 
        end
    end

    assign rs_addr_full = rs_full;
    
endmodule : ADDR_RS
