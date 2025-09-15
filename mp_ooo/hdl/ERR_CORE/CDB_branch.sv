module CDB_branch
import rv32i_types::*;
import params::*;
(
    input   logic           clk,
    input   logic           rst,

    input   logic   branch_write,
    input   branch_rs_entry_t br_rs_entry,
    input   logic   control_write,
    input   control_rs_entry_t control_rs_entry,

    input   logic [ROB_PTR_WIDTH : 0] rob_read_ptr,

    input   logic   flush_by_branch,

    output  logic [PHYSICAL_REG_WIDTH - 1:0] rs1_br, 
    output  logic [PHYSICAL_REG_WIDTH - 1:0] rs2_br,
    input   logic   [31:0]  rs1_v_br, 
    input   logic   [31:0]  rs2_v_br,

    input   cdb_entry_t         cdb_entry_mult, 
    output  cdb_entry_t        cdb_entry_br_out,
    input   cdb_entry_t          cdb_entry_alu,
    input   cdb_entry_t         cdb_entry_mem, 

    output  logic   rs_br_full, 
    output  logic   control_queue_full,
    output logic [CONTROL_Q_DEPTH-1:0] control_bit_map_out,
    output logic [CONTROL_Q_PTR_WIDTH : 0]   control_read_ptr_out,
    output logic [MEM_QUEUE_PTR_WIDTH : 0]   lsq_write_ptr_on_flush,
    output logic [STORE_QUEUE_DEPTH-1:0] store_q_bitmap_on_flush,

    input logic SQ_read_ack_out, // to update the recorded bit map
    input logic [MEM_QUEUE_PTR_WIDTH : 0] SQ_read_ptr, 

    output logic [31:0] pc_target, 
    output logic branch_en,
    output logic branch_resolved,

    output logic flush_by_branch_b,
    output logic [31:0] pc_target_on_flush,
    output logic [3:0] new_branch_pattern,
    output logic [1:0] new_saturating_counter,
    output logic [3:0] local_hist_table_write_idx,
    output logic [61:0] local_hist_table_write_data,
    
    // rvfi signals
    output logic [31:0] rvfi_pc_wdata, 
    output logic [31:0] rvfi_rs1_rdata_b, rvfi_rs2_rdata_b,
    output logic [31:0] rvfi_rd_wdata_b, 
    output logic [ROB_PTR_WIDTH:0] rvfi_issue_execute_rob_ptr_b, 
    output logic rvfi_inst_finished_b

);


    branch_rs_entry_t reservation_stations [BR_RS_NUM]; 
    logic [ROB_PTR_WIDTH : 0] priority_array [BR_RS_NUM]; // calculated with rob_read_ptr and its own rob_idx, small priority (closer) => older
    cdb_entry_t  cdb_entry_branch;
    logic   rs_full;
    logic begin_serving;
    logic [BR_RS_INDEX_BITS-1:0] serving_idx; // not going to have more than 16 RSs

    logic   [31:0]  add, pc_reg, imm_reg;
    branch_f3_t cmp_op;

    logic [CONTROL_Q_PTR_WIDTH : 0]   control_read_ptr;
    logic [CONTROL_Q_PTR_WIDTH : 0]   control_read_ptr_reg, control_read_ptr_reg2;
    logic [CONTROL_Q_DEPTH-1:0] control_bit_map;
    logic [CONTROL_Q_DEPTH-1:0] control_bit_map_reg;
    logic [MEM_QUEUE_PTR_WIDTH : 0] lsq_idx_reg;


    logic cmp_out, is_branch_reg, cmp_or_alu_reg;

    logic jalr_inst_reg, jal_inst_reg;

    logic   [ROB_PTR_WIDTH : 0] rob_idx_serving;
    logic   [4:0] arch_d_reg_serving;
    logic   [PHYSICAL_REG_FILE_LENGTH-1:0] phys_d_reg_serving;

    // intermediate register to split the issue vs execution logic. 
    logic [31:0] rs1_v_br_reg, rs1_v_br_reg2, rs2_v_br_reg, rs2_v_br_reg2;
    branch_f3_t cmp_op_reg;
    logic inst_finished, inst_finished2; // latch begin serving due to ALU not being multicycle, thus if we issue, next cycle it will finish and should be pushed to CDB.
    logic [4:0] arch_d_register;
    logic [PHYSICAL_REG_FILE_LENGTH-1:0] phys_d_register;
    logic [ROB_PTR_WIDTH : 0] rob_idx_reg, rob_idx_reg2;
    logic use_imm_reg;

    // control queue logic 
    control_rs_entry_t control_q_read_data;
    logic control_q_full, control_q_empty;
    // logic [CONTROL_Q_DEPTH-1:0] control_bit_map;
    logic control_q_read_ack, control_q_write_ack;
    logic [STORE_QUEUE_DEPTH-1:0] store_q_bitmap_reg;
    logic [3:0]  branch_pattern_reg;
    logic [1:0] saturating_counter_reg;
    logic [31:0] pc_target_predict_reg; 


    logic [3:0] new_branch_pattern_prev;
    logic [3:0] local_hist_table_write_idx_prev;
    logic [61:0] local_hist_table_write_data_prev;
    logic [1:0] new_saturating_counter_prev;
    logic flush_by_branch_b_prev;
    logic [31:0] pc_target_on_flush_prev;
    logic branch_en_prev ;
    logic [31:0] pc_target_prev ;
    logic branch_resolved_prev;
    logic [MEM_QUEUE_PTR_WIDTH : 0] lsq_write_ptr_on_flush_prev ;
    logic [STORE_QUEUE_DEPTH-1:0] store_q_bitmap_on_flush_prev ;

    assign control_bit_map_out = control_bit_map;
    assign control_read_ptr_out = control_read_ptr_reg2;
    // rvfi
    always_comb begin
        rvfi_issue_execute_rob_ptr_b = rob_idx_reg2;
        rvfi_rs1_rdata_b = rs1_v_br_reg2;
        rvfi_rs2_rdata_b = rs2_v_br_reg2;
        rvfi_rd_wdata_b = cdb_entry_br_out.rd_v; 
        rvfi_inst_finished_b = inst_finished2;
        rvfi_pc_wdata = pc_target;
    end
    
    always_ff @(posedge clk) begin

        if(rst) begin
            for (int i = 0; i < BR_RS_NUM; i++) begin
                reservation_stations[i].finished <= 1'b1;
                reservation_stations[i].cmpop <= branch_f3_beq;
                reservation_stations[i].pc <= '0;
                reservation_stations[i].imm <='0;
                reservation_stations[i].use_imm <= '0;
                reservation_stations[i].arch_d_reg <= '0;
                reservation_stations[i].phys_d_reg <= '0;
                reservation_stations[i].phys_r1 <= '0;
                reservation_stations[i].phys_r2 <= '0;
                reservation_stations[i].phys_r1_valid <= '0; 
                reservation_stations[i].phys_r2_valid <= '0; 
                reservation_stations[i].branch_inst <= '0;
                reservation_stations[i].cmp_or_alu <= '0;
                reservation_stations[i].jalr_flag <= '0;
                reservation_stations[i].rob_idx <= '0;
            end 
        end
        // else if (branch_resolved) begin
        //     for (int i = 0; i < BR_RS_NUM; i++) begin
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
        //     for (int i = 0; i < BR_RS_NUM; i++) begin
        //         if (reservation_stations[i].control_bit_map[control_read_ptr[CONTROL_Q_PTR_WIDTH-1 : 0]] == 1'b1) begin
        //             reservation_stations[i].finished <= 1'b1;
        //         end
        //     end
        // end
        else begin
            if (flush_by_branch) begin
                for (int i = 0; i < BR_RS_NUM; i++) begin
                    if (reservation_stations[i].control_bit_map[control_read_ptr[CONTROL_Q_PTR_WIDTH-1 : 0]] == 1'b1) begin
                        reservation_stations[i].finished <= 1'b1;
                    end
                end
            end
            
            else if(!rs_full & branch_write) begin
                for (int i = 0; i < BR_RS_NUM; i++) begin
                    if (reservation_stations[i].finished == 1'b1) begin
                        reservation_stations[i] <= br_rs_entry;
                        break;
                    end
                end 
            end
            if (begin_serving) begin
                reservation_stations[serving_idx].finished <= 1'b1; // finish next cycle after issuing since branch resolution is immediate.
            end
            //  exec finished, set corresponding finish to 1; set invalid operand to valid
            for (int i = 0; i < BR_RS_NUM; i++) begin
                if (reservation_stations[i].finished == 1'b0) begin

                    if (cdb_entry_br_out.valid) begin
                        if (cdb_entry_br_out.phys_d_reg == reservation_stations[i].phys_r1) begin
                            reservation_stations[i].phys_r1_valid <= 1'b1;
                        end
                        if (cdb_entry_br_out.phys_d_reg == reservation_stations[i].phys_r2) begin
                            reservation_stations[i].phys_r2_valid <= 1'b1;
                        end
                    end 
                
                    if (cdb_entry_alu.valid) begin
                    // for (int i = 0; i < ALU_RS_NUM; i++) begin
                        if (cdb_entry_alu.phys_d_reg == reservation_stations[i].phys_r1) begin
                            reservation_stations[i].phys_r1_valid <= 1'b1;
                        end
                        if (cdb_entry_alu.phys_d_reg == reservation_stations[i].phys_r2) begin
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
                for (int i = 0; i < BR_RS_NUM; i++) begin 
                    reservation_stations[i].control_bit_map[control_read_ptr[CONTROL_Q_PTR_WIDTH-1 : 0]] <= 1'b0;
                end
            end
        end
    end

    // calculate priority
    always_comb begin
        for (int i = 0; i < BR_RS_NUM; i++) begin
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
        if (control_q_read_ack | flush_by_branch) begin
            begin_serving = '0;
            serving_idx   = '0;
        end
        else begin
            for (int unsigned i = 0; i < BR_RS_NUM; i++) begin
                if (reservation_stations[i].phys_r1_valid && (reservation_stations[i].use_imm || reservation_stations[i].phys_r2_valid)&& !reservation_stations[i].finished) begin
                    begin_serving = '1;
                    serving_idx = BR_RS_INDEX_BITS'(i);
                    break;
                end
            end
        end
    end

    // assign rs1_br = reservation_stations[serving_idx].phys_r1;
    // assign rs2_br = reservation_stations[serving_idx].phys_r2;
    always_comb begin
        if (control_q_read_ack) begin
            rs1_br = control_q_read_data.phys_r1;
            rs2_br = control_q_read_data.phys_r2;
        end
        else begin
            rs1_br = reservation_stations[serving_idx].phys_r1;
            rs2_br = reservation_stations[serving_idx].phys_r2;
        end
    end


    
    always_ff @ (posedge clk) begin

        if (rst|flush_by_branch) begin
            rs1_v_br_reg <= '0;
            rs2_v_br_reg <= '0;
            cmp_op_reg <= branch_f3_beq;
            inst_finished <= '0;
            arch_d_register <= '0;
            phys_d_register <= '0;
            rob_idx_reg <= '0;
            jalr_inst_reg <= '0;
            pc_reg <= '0;
            imm_reg <= '0;
            is_branch_reg <= '0;
            cmp_or_alu_reg <= '0;
            use_imm_reg <= '0;
            jal_inst_reg <= '0;
            control_bit_map_reg <= '0;
            control_read_ptr_reg <= '0;

            branch_pattern_reg <= '0;
            saturating_counter_reg <= '0;
            pc_target_predict_reg <= '0;
        end
        else if (control_q_read_ack) begin
            rs1_v_br_reg <= rs1_v_br;
            rs2_v_br_reg <= rs2_v_br;
            pc_reg <= control_q_read_data.pc;
            cmp_op_reg <= control_q_read_data.cmpop;
            inst_finished <= '1; // CMP and ALU are combinational logic, branch can be resolved 1 cycle after issue, both target PC and branch enable. 
            arch_d_register <= control_q_read_data.arch_d_reg;
            phys_d_register <= control_q_read_data.phys_d_reg;
            rob_idx_reg <= control_q_read_data.rob_idx;
            imm_reg <= control_q_read_data.imm;
            is_branch_reg <= control_q_read_data.branch_inst;
            cmp_or_alu_reg <= control_q_read_data.cmp_or_alu;
            jalr_inst_reg <= control_q_read_data.jalr_flag;
            jal_inst_reg  <= control_q_read_data.jal_flag;
            use_imm_reg <= control_q_read_data.use_imm;
            control_bit_map_reg <= control_q_read_data.control_bit_map;
            lsq_idx_reg <= control_q_read_data.lsq_idx;
            store_q_bitmap_reg <= control_q_read_data.store_bitmap;
            control_read_ptr_reg <= control_read_ptr;

            branch_pattern_reg <= control_q_read_data.branch_pattern;
            saturating_counter_reg <= control_q_read_data.saturating_counter;
            pc_target_predict_reg <= control_q_read_data.pc_target_predict;
        end else if (begin_serving) begin

            rs1_v_br_reg <= rs1_v_br;
            rs2_v_br_reg <= rs2_v_br;
            pc_reg <= reservation_stations[serving_idx].pc;
            cmp_op_reg <= reservation_stations[serving_idx].cmpop;
            inst_finished <= '1; // CMP and ALU are combinational logic, branch can be resolved 1 cycle after issue, both target PC and branch enable. 
            arch_d_register <= reservation_stations[serving_idx].arch_d_reg;
            phys_d_register <= reservation_stations[serving_idx].phys_d_reg;
            rob_idx_reg <= reservation_stations[serving_idx].rob_idx;
            imm_reg <= reservation_stations[serving_idx].imm;
            is_branch_reg <= reservation_stations[serving_idx].branch_inst;
            cmp_or_alu_reg <= reservation_stations[serving_idx].cmp_or_alu;
            jalr_inst_reg <= reservation_stations[serving_idx].jalr_flag;
            jal_inst_reg  <= reservation_stations[serving_idx].jal_flag;
            use_imm_reg <= reservation_stations[serving_idx].use_imm;
            control_bit_map_reg <= reservation_stations[serving_idx].control_bit_map;

        end else begin  // not serving
            inst_finished <= '0;
        end
        if (branch_resolved) control_bit_map_reg[control_read_ptr[CONTROL_Q_PTR_WIDTH-1 : 0]] <= 1'b0;
    end


/*
    input logic [31:0] pc, imm, rs1_v, rs2_v,

    input branch_f3_t cmp_op,

    input  logic jalr_inst,  // is it jalr

    input logic branch,  // is it branch
  
    input logic cmp_alu,  // is this slt or auipc

    output logic cmp,

    output logic add

*/
br_func_unit branch_result(

    .pc(pc_reg),
    .imm(imm_reg),
    .rs1_v(rs1_v_br_reg),
    .rs2_v(rs2_v_br_reg),
    .cmp_op(cmp_op_reg),
   
 
    .jalr_inst(jalr_inst_reg),
    .use_imm_in_compare(use_imm_reg),
    .cmp(cmp_out),
    .add(add)

);


control_queue control_queue_0(
    .write_data(control_rs_entry),
    .write_en(control_write),
    .read_data(control_q_read_data),
    .queue_full(control_q_full),
    .queue_empty(control_q_empty),
    .control_bit_map(control_bit_map),
    .read_ack(control_q_read_ack),
    .write_ack(control_q_write_ack),
    .control_read_ptr(control_read_ptr),
    .SQ_read_ack_out(SQ_read_ack_out),
    .SQ_read_ptr(SQ_read_ptr),
    .cdb_entry_branch(cdb_entry_br_out),
    .*
);

    assign control_queue_full = control_q_full;

    always_comb begin
        if (inst_finished) begin
            cdb_entry_branch.valid = '1;
            if (jalr_inst_reg || jal_inst_reg) cdb_entry_branch.rd_v = pc_reg + 'd4;
            else cdb_entry_branch.rd_v = (cmp_or_alu_reg) ? {31'b0, cmp_out} : add;
            cdb_entry_branch.arch_d_reg = arch_d_register;
            cdb_entry_branch.phys_d_reg = phys_d_register;
            cdb_entry_branch.rob_idx = rob_idx_reg;
            cdb_entry_branch.control_bit_map = control_bit_map_reg;
            lsq_write_ptr_on_flush_prev = lsq_idx_reg;
            store_q_bitmap_on_flush_prev = store_q_bitmap_reg;
            if (SQ_read_ack_out) store_q_bitmap_on_flush_prev[SQ_read_ptr[STORE_QUEUE_PTR_WIDTH-1:0]] = 1'b0;

            if (jalr_inst_reg || jal_inst_reg) begin branch_en_prev = '1; branch_resolved_prev = '1;  end
            else if (is_branch_reg) begin branch_en_prev = cmp_out; branch_resolved_prev = '1;  end
            else begin branch_en_prev = '0; branch_resolved_prev = '0;  end
            pc_target_prev = add;

        end else begin
            cdb_entry_branch.valid = '0;
            cdb_entry_branch.rd_v  = '0;
            cdb_entry_branch.arch_d_reg = '0;
            cdb_entry_branch.phys_d_reg = '0;
            cdb_entry_branch.rob_idx = '0;
            cdb_entry_branch.control_bit_map = '0;
            branch_en_prev = '0;
            pc_target_prev = '0;
            branch_resolved_prev = '0;
            lsq_write_ptr_on_flush_prev = 'x;
            store_q_bitmap_on_flush_prev = 'x;
        end
    end


    always_comb begin
        flush_by_branch_b_prev = (branch_en_prev ^ saturating_counter_reg[1]) || (saturating_counter_reg[1] && branch_en_prev && pc_target_prev != pc_target_predict_reg); // flush  if they are different
        pc_target_on_flush_prev = saturating_counter_reg[1] == 1'b0 ? pc_target_prev : pc_reg + 'd4;
        if (saturating_counter_reg[1] && branch_en_prev && pc_target_prev != pc_target_predict_reg) pc_target_on_flush_prev = pc_target_prev;
    end

    always_comb begin
        new_branch_pattern_prev = {branch_pattern_reg[2:0], branch_en_prev};  // index to update pattern history table
        local_hist_table_write_idx_prev = pc_reg[5:2];
        local_hist_table_write_data_prev = {pc_reg[31:6], new_branch_pattern_prev, pc_target_prev};
        new_saturating_counter_prev = saturating_counter_reg;
        if (branch_en_prev) begin
            if (saturating_counter_reg != 2'b11) new_saturating_counter_prev = saturating_counter_reg + 1'b1;
        end
        else begin
            if (saturating_counter_reg != 2'b00) new_saturating_counter_prev = saturating_counter_reg - 1'b1;
        end
    end




    always_ff @(posedge clk) begin
        if (rst | (flush_by_branch && control_bit_map_reg[control_read_ptr_reg2[CONTROL_Q_PTR_WIDTH-1 : 0]] == 1'b1)) begin
            new_branch_pattern          <= '0;
            local_hist_table_write_idx  <= '0;
            local_hist_table_write_data <= '0;
            new_saturating_counter      <= '0;
            flush_by_branch_b           <= '0;
            pc_target_on_flush          <= '0;
            branch_en                   <= '0;
            pc_target                   <= '0;
            branch_resolved             <= '0;
            lsq_write_ptr_on_flush      <= '0;
            store_q_bitmap_on_flush     <= '0;
            cdb_entry_br_out.valid      <= '0;

            rob_idx_reg2                <= '0;
            rs1_v_br_reg2               <= '0;
            rs2_v_br_reg2               <= '0;
            inst_finished2              <= '0;
            control_read_ptr_reg2       <= '0;

        end
        else begin
            new_branch_pattern          <= new_branch_pattern_prev;
            local_hist_table_write_idx  <= local_hist_table_write_idx_prev;
            local_hist_table_write_data <= local_hist_table_write_data_prev;
            new_saturating_counter      <= new_saturating_counter_prev;
            flush_by_branch_b           <= flush_by_branch_b_prev;
            pc_target_on_flush          <= pc_target_on_flush_prev;
            branch_en                   <= branch_en_prev ;
            pc_target                   <= pc_target_prev ;
            branch_resolved             <= branch_resolved_prev;
            lsq_write_ptr_on_flush      <= lsq_write_ptr_on_flush_prev ;
            store_q_bitmap_on_flush     <= store_q_bitmap_on_flush_prev ;
            cdb_entry_br_out            <= cdb_entry_branch;

            rob_idx_reg2                <= rob_idx_reg;
            rs1_v_br_reg2               <= rs1_v_br_reg;
            rs2_v_br_reg2               <= rs2_v_br_reg;
            inst_finished2              <= inst_finished;
            control_read_ptr_reg2       <= control_read_ptr_reg;
        end
    end


    // assign cdb_entry_br_out = cdb_entry_branch;

    always_comb begin
        rs_full = '1;
        for (int i = 0; i < BR_RS_NUM; i++) begin
            if (reservation_stations[i].finished == 1'b1) begin
                rs_full = '0;
                break;
            end 
        end
    end

    assign rs_br_full = rs_full;


endmodule
