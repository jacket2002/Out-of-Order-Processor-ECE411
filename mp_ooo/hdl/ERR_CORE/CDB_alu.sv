module CDB_alu
import rv32i_types::*;
import params::*;
(
    input   logic           clk,
    input   logic           rst,

    input   logic   alu_write,
    input   alu_rs_entry_t alu_rs_entry,
    input   logic [ROB_PTR_WIDTH : 0] rob_read_ptr,

    input  logic   flush_by_branch,
    input  logic    branch_resolved,
    input  logic [CONTROL_Q_PTR_WIDTH : 0]   control_read_ptr,

    output  logic [PHYSICAL_REG_WIDTH - 1:0] rs1_alu, 
    output  logic [PHYSICAL_REG_WIDTH - 1:0] rs2_alu,
    input   logic   [31:0]  rs1_v_alu, 
    input   logic   [31:0]  rs2_v_alu,

    input   cdb_entry_t     cdb_entry_mult, 
    input   cdb_entry_t     cdb_entry_br,
    input   cdb_entry_t     cdb_entry_mem,
    output  cdb_entry_t     cdb_entry_alu_out,
    output  logic   rs_alu_full, 
    
    // rvfi signals
    output logic [31:0] rvfi_rs1_rdata_a, rvfi_rs2_rdata_a,
    output logic [31:0] rvfi_rd_wdata_a, 
    output logic [ROB_PTR_WIDTH:0] rvfi_issue_execute_rob_ptr_a, 
    output logic rvfi_inst_finished_a
);

    alu_rs_entry_t reservation_stations [ALU_RS_NUM]; 
    logic [ROB_PTR_WIDTH : 0] priority_array [ALU_RS_NUM]; // calculated with rob_read_ptr and its own rob_idx, small priority (closer) => older
    cdb_entry_t  cdb_entry_alu;
    logic   rs_full;
    logic begin_serving;
    logic [ALU_RS_INDEX_BITS-1:0] serving_idx; // not going to have more than 16 RSs

    logic   [31:0]  a;
    logic   [31:0]  b;

    logic signed   [31:0] as;
    // logic signed   [31:0] bs;
    logic unsigned [31:0] au;
    logic unsigned [31:0] bu;

    logic   [31:0]  aluout;

    logic   [ROB_PTR_WIDTH : 0] rob_idx_serving;
    logic   [4:0] arch_d_reg_serving;
    logic   [PHYSICAL_REG_FILE_LENGTH-1:0] phys_d_reg_serving;

    // intermediate register to split the issue vs execution logic. 
    logic [CONTROL_Q_DEPTH-1:0] control_bit_map_reg;
    logic [31:0] rs1_v_alu_reg, rs2_v_alu_reg;
    alu_ops_t alu_op_reg;
    logic inst_finished; // latch begin serving due to ALU not being multicycle, thus if we issue, next cycle it will finish and should be pushed to CDB.
    logic [4:0] arch_d_register;
    logic [PHYSICAL_REG_FILE_LENGTH-1:0] phys_d_register;
    logic [ROB_PTR_WIDTH : 0] rob_idx_reg;
    logic use_imm_reg;

    always_comb begin
        rvfi_issue_execute_rob_ptr_a = rob_idx_reg;
        rvfi_rs1_rdata_a = rs1_v_alu_reg;
        rvfi_rs2_rdata_a = rs2_v_alu_reg;
        rvfi_rd_wdata_a = aluout; 
        rvfi_inst_finished_a = inst_finished;
    end
    
    always_ff @(posedge clk) begin

        if(rst) begin
            for (int i = 0; i < ALU_RS_NUM; i++) begin
                reservation_stations[i].finished <= 1'b1;
                reservation_stations[i].alu_op <= alu_op_add;
                reservation_stations[i].imm <= '0;
                reservation_stations[i].arch_d_reg <= '0;
                reservation_stations[i].phys_d_reg <= '0;
                reservation_stations[i].phys_r1 <= '0;
                reservation_stations[i].phys_r2 <= '0;
                reservation_stations[i].phys_r1_valid <= '0;
                reservation_stations[i].phys_r2_valid <= '0;
                reservation_stations[i].rob_idx <= '0;
                reservation_stations[i].use_imm <= '0;
            end 
        end
        // else if (branch_resolved) begin
        //     for (int i = 0; i < ALU_RS_NUM; i++) begin
        //         if (reservation_stations[i].control_bit_map[control_read_ptr[CONTROL_Q_PTR_WIDTH-1 : 0]] == 1'b1) begin
        //             if (flush_by_branch) begin
        //                 reservation_stations[i].finished <= 1'b1;
        //             end
        //             else begin
        //                 reservation_stations[i].control_bit_map[control_read_ptr[CONTROL_Q_PTR_WIDTH-1 : 0]] <= 1'b0;
        //             end
        //         end
        //     end 
        // end
        // else if (flush_by_branch) begin
        //     for (int i = 0; i < ALU_RS_NUM; i++) begin
        //         if (reservation_stations[i].control_bit_map[control_read_ptr[CONTROL_Q_PTR_WIDTH-1 : 0]] == 1'b1) begin
        //             reservation_stations[i].finished <= 1'b1;
        //         end
        //     end
        // end
        else begin
            if (flush_by_branch) begin
                for (int i = 0; i < ALU_RS_NUM; i++) begin
                    if (reservation_stations[i].control_bit_map[control_read_ptr[CONTROL_Q_PTR_WIDTH-1 : 0]] == 1'b1) begin
                        reservation_stations[i].finished <= 1'b1;
                    end
                end
            end


            else if(!rs_full & alu_write) begin
                for (int i = 0; i < ALU_RS_NUM; i++) begin
                    if (reservation_stations[i].finished == 1'b1) begin
                        reservation_stations[i] <= alu_rs_entry;
                        break;
                    end
                end 
            end

            if (begin_serving) begin
                reservation_stations[serving_idx].finished <= 1'b1; // finish next cycle after issuing since ALU is immediate.
            end
            //  exec finished, set corresponding finish to 1; set invalid operand to valid
            for (int i = 0; i < ALU_RS_NUM; i++) begin
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
                for (int i = 0; i < ALU_RS_NUM; i++) begin 
                    reservation_stations[i].control_bit_map[control_read_ptr[CONTROL_Q_PTR_WIDTH-1 : 0]] <= 1'b0;
                end
            end
        end

    end

    // calculate priority
    always_comb begin
        for (int i = 0; i < ALU_RS_NUM; i++) begin
            if (reservation_stations[i].rob_idx[ROB_PTR_WIDTH] == rob_read_ptr[ROB_PTR_WIDTH])
                priority_array[i] = reservation_stations[i].rob_idx - rob_read_ptr;
            else
                priority_array[i] = {1'b1, reservation_stations[i].rob_idx[ROB_PTR_WIDTH - 1 : 0]} - {1'b0, rob_read_ptr[ROB_PTR_WIDTH - 1 : 0]};
        end 
    end

    // figure out which to serve
    always_comb begin
        begin_serving = '0;
        serving_idx   = '0;
        if ( flush_by_branch) begin
            begin_serving = '0;
            serving_idx   = '0;
        end
        else begin
            for (int unsigned i = 0; i < ALU_RS_NUM; i++) begin
                if (reservation_stations[i].phys_r1_valid && (reservation_stations[i].use_imm || reservation_stations[i].phys_r2_valid)&& !reservation_stations[i].finished) begin
                    begin_serving = '1;
                    serving_idx = ALU_RS_INDEX_BITS'(i);
                    break;
                end
            end
        end
    end

    assign rs1_alu = reservation_stations[serving_idx].phys_r1;
    assign rs2_alu = reservation_stations[serving_idx].phys_r2;


    
    always_ff @ (posedge clk) begin
        if (rst|flush_by_branch) begin
            rs1_v_alu_reg <= '0;
            rs2_v_alu_reg <= '0;
            alu_op_reg <= alu_op_add;
            inst_finished <= '0;
            arch_d_register <= '0;
            phys_d_register <= '0;
            rob_idx_reg <= '0;
            control_bit_map_reg <= '0;
        end else if (begin_serving) begin
            rs1_v_alu_reg <= rs1_v_alu;
            rs2_v_alu_reg <= (reservation_stations[serving_idx].use_imm) ? reservation_stations[serving_idx].imm : rs2_v_alu;
            alu_op_reg <= reservation_stations[serving_idx].alu_op;
            inst_finished <= '1;
            arch_d_register <= reservation_stations[serving_idx].arch_d_reg;
            phys_d_register <= reservation_stations[serving_idx].phys_d_reg;
            rob_idx_reg <= reservation_stations[serving_idx].rob_idx;
            control_bit_map_reg <= reservation_stations[serving_idx].control_bit_map;
        end else begin  // not serving
            inst_finished <= '0;
        end
        if (branch_resolved) control_bit_map_reg[control_read_ptr[CONTROL_Q_PTR_WIDTH-1 : 0]] <= 1'b0;
    end


    // assign a = rs1_v_alu;
    // assign b = (reservation_stations[serving_idx].use_imm) ? reservation_stations[serving_idx].imm : rs2_v_alu;
    assign a = rs1_v_alu_reg;
    assign b = rs2_v_alu_reg;

    assign as =   signed'(a);
    // assign bs =   signed'(b);
    assign au = unsigned'(a);
    assign bu = unsigned'(b);

    always_comb begin
        // unique case (reservation_stations[serving_idx].alu_op)
        unique case (alu_op_reg)
            alu_op_add: aluout = au +   bu;
            alu_op_sll: aluout = au <<  bu[4:0];
            alu_op_sra: aluout = unsigned'(as >>> bu[4:0]);
            alu_op_sub: aluout = au -   bu;
            alu_op_xor: aluout = au ^   bu;
            alu_op_srl: aluout = au >>  bu[4:0];
            alu_op_or : aluout = au |   bu;
            alu_op_and: aluout = au &   bu;
            default   : aluout = 'x;
        endcase
    end

    // assign rob_idx_serving = reservation_stations[serving_idx].rob_idx;
    // assign arch_d_reg_serving = reservation_stations[serving_idx].arch_d_reg;
    // assign phys_d_reg_serving = reservation_stations[serving_idx].phys_d_reg;

    always_comb begin
        if (inst_finished) begin
            // cdb_entry_alu.valid = '1;
            // cdb_entry_alu.rd_v  = aluout;
            // cdb_entry_alu.arch_d_reg = arch_d_reg_serving;
            // cdb_entry_alu.phys_d_reg = phys_d_reg_serving;
            // cdb_entry_alu.rob_idx = rob_idx_serving;
            cdb_entry_alu.valid = '1;
            cdb_entry_alu.rd_v = aluout;
            cdb_entry_alu.arch_d_reg = arch_d_register;
            cdb_entry_alu.phys_d_reg = phys_d_register;
            cdb_entry_alu.rob_idx = rob_idx_reg;
            cdb_entry_alu.control_bit_map = control_bit_map_reg;
        end else begin
            cdb_entry_alu.valid = '0;
            cdb_entry_alu.rd_v  = '0;
            cdb_entry_alu.arch_d_reg = '0;
            cdb_entry_alu.phys_d_reg = '0;
            cdb_entry_alu.rob_idx = '0;
            cdb_entry_alu.control_bit_map = '0;
        end
    end

    assign cdb_entry_alu_out = cdb_entry_alu;

    always_comb begin
        rs_full = '1;
        for (int i = 0; i < ALU_RS_NUM; i++) begin
            if (reservation_stations[i].finished == 1'b1) begin
                rs_full = '0;
                break;
            end 
        end
    end

    assign rs_alu_full = rs_full;

endmodule : CDB_alu
