module CDB_muld
import rv32i_types::*;
import params::*;
(
    input   logic           clk,
    input   logic           rst,

    input   logic   mul_write,
    input   mul_rs_entry_t mul_rs_entry,
    input   logic [ROB_PTR_WIDTH : 0] rob_read_ptr,

    input  logic   flush_by_branch,
    input  logic    branch_resolved,
    input  logic [CONTROL_Q_PTR_WIDTH : 0]   control_read_ptr,

    output  logic [PHYSICAL_REG_WIDTH - 1:0] rs1_mul, 
    output  logic [PHYSICAL_REG_WIDTH - 1:0] rs2_mul,
    input   logic   [31:0]  rs1_v_mul, 
    input   logic   [31:0]  rs2_v_mul,

    output  cdb_entry_t     cdb_entry_mult_out, 
    input   cdb_entry_t     cdb_entry_br,
    input   cdb_entry_t     cdb_entry_alu,
    input   cdb_entry_t     cdb_entry_mem,
    output  logic   rs_mul_full,

    // rvfi
    output logic [31:0] rvfi_rs1_rdata_m, rvfi_rs2_rdata_m,
    output logic [31:0] rvfi_rd_wdata_m, 
    output logic [ROB_PTR_WIDTH:0] rvfi_issue_execute_rob_ptr_m, 
    output logic rvfi_inst_finished_m
);
    logic divide_by_zero, is_divide, is_rem;
    mul_rs_entry_t reservation_stations [MULT_RS_NUM]; 
    logic [ROB_PTR_WIDTH : 0] priority_array [MULT_RS_NUM]; // calculated with rob_read_ptr and its own rob_idx, small priority (closer) => older
    cdb_entry_t  cdb_entry_mult;
    logic   rs_full;
    logic begin_serving;
    logic [MULT_RS_INDEX_BITS-1:0] serving_idx; // not going to have more than 16 RSs

    logic   [ROB_PTR_WIDTH : 0] rob_idx_serving;
    logic   [4:0] arch_d_reg_serving;
    logic   [PHYSICAL_REG_FILE_LENGTH-1:0] phys_d_reg_serving;

    // intermediate register to split the issue vs execution logic. 
    logic [31:0] rs1_v_mul_reg, rs2_v_mul_reg;
    logic div_start_reg;

    m_extension_f3_t mul_op_reg;
    logic [CONTROL_Q_DEPTH-1:0] control_bit_map_reg;
    logic inst_finished; // latch begin serving due to  not being multicycle, thus if we issue, next cycle it will finish and should be pushed to CDB.
    logic [4:0] arch_d_register;
    logic [PHYSICAL_REG_FILE_LENGTH-1:0] phys_d_register;
    logic [ROB_PTR_WIDTH : 0] rob_idx_reg;

    logic [63:0] chosen_out, temp;
    // figure out which output we need for multiply, divide, or remainder instruction


    // ==================== generate our inputs ====================
    // our functional ips

    logic mul_complete, divide_complete, complete;
    logic [31:0] cdb_result;
    logic idle_, after_start;
    logic [63:0] multiply_out;
    logic [31:0] divide_quotient;
    logic [31:0] remainder;
    logic [31:0] a, b;
    logic [31:0] b_reg, a_reg;
    logic neg_result, half;
    logic [1:0] mul_div_rem_var;
    // making it single cycle 
    logic [1:0] mul_type;

    logic divide_complete_original, mul_complete_original, divide_by_zero_original;
    logic [31:0] divide_quotient_original, remainder_original;
    logic [63:0] multiply_out_original;

    //start logic 
    logic mul_start;
    logic div_start;
    logic start_signal;
    logic flush_fu_by_branch;

    // rvfi
    always_comb begin
        rvfi_issue_execute_rob_ptr_m = rob_idx_reg;
        rvfi_rs1_rdata_m = rs1_v_mul_reg;
        rvfi_rs2_rdata_m = rs2_v_mul_reg;
        rvfi_rd_wdata_m = (divide_by_zero && (is_rem)) ? a : (divide_by_zero && (is_divide)) ? '1 : cdb_result;
        rvfi_inst_finished_m = complete;
    end

    always_ff @(posedge clk) begin

        if(rst) begin
            for (int i = 0; i < MULT_RS_NUM; i++) begin
                reservation_stations[i].finished <= 1'b1;
                reservation_stations[i].mul_op <= m_mul;
                reservation_stations[i].arch_d_reg <= '0;
                reservation_stations[i].phys_d_reg <= '0;
                reservation_stations[i].phys_r1 <= '0;
                reservation_stations[i].phys_r2 <= '0;
                reservation_stations[i].phys_r1_valid <= '0;
                reservation_stations[i].phys_r2_valid <= '0;
                reservation_stations[i].rob_idx <= '0;  
            end 
        end
        // else if (branch_resolved) begin
        //     for (int i = 0; i < MULT_RS_NUM; i++) begin
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
        //     for (int i = 0; i < MULT_RS_NUM; i++) begin
        //         if (reservation_stations[i].control_bit_map[control_read_ptr[CONTROL_Q_PTR_WIDTH-1 : 0]] == 1'b1) begin
        //             reservation_stations[i].finished <= 1'b1;
        //         end
        //     end
        // end
        else begin
            if (flush_by_branch) begin
                for (int i = 0; i < MULT_RS_NUM; i++) begin
                    if (reservation_stations[i].control_bit_map[control_read_ptr[CONTROL_Q_PTR_WIDTH-1 : 0]] == 1'b1) begin
                        reservation_stations[i].finished <= 1'b1;
                    end
                end
            end
            else if(!rs_full & mul_write) begin
                for (int i = 0; i < MULT_RS_NUM; i++) begin
                    if (reservation_stations[i].finished == 1'b1) begin
                        reservation_stations[i] <= mul_rs_entry;
                        break;
                    end
                end 
            end
            if (begin_serving && inst_finished == 1'b1) begin
                reservation_stations[serving_idx].finished <= 1'b1; // finish next cycle after issuing since ALU is immediate.
            end
            //  exec finished, set corresponding finish to 1; set invalid operand to valid
            for (int i = 0; i < MULT_RS_NUM; i++) begin
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
                        if (cdb_entry_br.phys_d_reg == reservation_stations[i].phys_r1) begin
                            reservation_stations[i].phys_r1_valid <= 1'b1;
                        end
                        if (cdb_entry_br.phys_d_reg == reservation_stations[i].phys_r2) begin
                            reservation_stations[i].phys_r2_valid <= 1'b1;
                        end
                    end 

                    if (cdb_entry_mult.valid) begin
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
                for (int i = 0; i < MULT_RS_NUM; i++) begin 
                    reservation_stations[i].control_bit_map[control_read_ptr[CONTROL_Q_PTR_WIDTH-1 : 0]] <= 1'b0;
                end
            end
        end

    end

    // calculate priority
    always_comb begin
        for (int i = 0; i < MULT_RS_NUM; i++) begin
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
        if (flush_by_branch) begin
            begin_serving = '0;
            serving_idx   = '0;
        end
        else begin
            for (int unsigned i = 0; i < MULT_RS_NUM; i++) begin
                if (reservation_stations[i].phys_r1_valid && reservation_stations[i].phys_r2_valid && !reservation_stations[i].finished) begin
                    begin_serving = '1;
                    serving_idx = MULT_RS_INDEX_BITS'(i);
                    // serving_idx = i;
                    break;
                end
            end
        end
    end

    assign rs1_mul = reservation_stations[serving_idx].phys_r1;
    assign rs2_mul = reservation_stations[serving_idx].phys_r2;


    assign flush_fu_by_branch = (flush_by_branch && control_bit_map_reg[control_read_ptr[CONTROL_Q_PTR_WIDTH-1 : 0]] == 1'b1)? 1'b1: 1'b0;

    always_ff @ (posedge clk) begin
        if (rst| flush_fu_by_branch) begin
            rs1_v_mul_reg <= '0;
            rs2_v_mul_reg <= '0;
            mul_op_reg <= m_mul;
            inst_finished <= '1;
            arch_d_register <= '0;
            phys_d_register <= '0;
            rob_idx_reg <= '0;
            control_bit_map_reg <= '0;
        end 
        else if (begin_serving && inst_finished == 1'b1) begin // change condition here to keep until complete 
            rs1_v_mul_reg <= rs1_v_mul;
            rs2_v_mul_reg <= rs2_v_mul;
            mul_op_reg <= reservation_stations[serving_idx].mul_op;
            inst_finished <= '0;

            // These three needed for set CDB, need to keep until complete !! 
            arch_d_register <= reservation_stations[serving_idx].arch_d_reg;
            phys_d_register <= reservation_stations[serving_idx].phys_d_reg;
            rob_idx_reg <= reservation_stations[serving_idx].rob_idx;
            control_bit_map_reg <= reservation_stations[serving_idx].control_bit_map;
        end else if (complete) begin  // can change to idle_ if there is registered CDB data dependent on complete
            inst_finished <= '1;
        end
        if (branch_resolved) control_bit_map_reg[control_read_ptr[CONTROL_Q_PTR_WIDTH-1 : 0]] <= 1'b0;
    end

    always_ff @ (posedge clk) begin
        if (rst| flush_fu_by_branch) begin
            start_signal <= '0;
        end
        else if (begin_serving && inst_finished == 1'b1) begin
            start_signal <= '1;
        end
        else if (start_signal == '1) begin
            start_signal <= '0;
        end
    end

    always_ff @ (posedge clk) begin
        if (rst| flush_fu_by_branch) begin
            after_start <= '0;
        end
        else begin
            if (start_signal) begin
                after_start <= '1;
            end
            else if (after_start == 1'b1 && idle_ && !div_start_reg) begin
                after_start <= '0;
            end
        end
    end
    
    always_ff @(posedge clk) begin


        div_start_reg<=  div_start;

    end
    assign complete = (after_start && idle_ && !div_start_reg)? 1'b1: 1'b0;


    
    assign a = rs1_v_mul_reg;
    assign b = rs2_v_mul_reg;

    // find mul_type
always_comb begin
    unique case(mul_op_reg)

                m_mul : begin
                    mul_type = 2'b01;
                    half = '0;
                    mul_div_rem_var = '0;
                end
                m_mulh : begin
                    mul_type = 2'b01;
                    half = '1;
                    mul_div_rem_var = '0;

                end
                m_mulhsu : begin
                    mul_type = 2'b10;
                    half = '1;
                    mul_div_rem_var = '0;

                end
                m_mulhu : begin

                    mul_type = 2'b00;
                    half = '1;
                    mul_div_rem_var = '0;

                end
                m_div : begin
                    mul_type = 2'b01;
                    mul_div_rem_var = '1;
                    half = '0;
                end
                m_divu : begin
                    mul_type = 2'b00;
                    mul_div_rem_var = '1;
                    half = '0;
                end
                m_rem : begin
                    mul_type = 2'b01;
                    mul_div_rem_var = 2'b10;
                    half = '0;
                end
                m_remu : begin

                    mul_type = 2'b00;
                    mul_div_rem_var = 2'b10;
                    half = '0;
                end
                default: begin 
                    mul_type = 'x;
                    mul_div_rem_var = 'x;
                    half = 'x;
                end
    endcase 
end
    

    always_comb begin
        neg_result = 'x;
        a_reg = 'x;
        b_reg = 'x;
            unique case (mul_type)
                2'b00:
                begin
                    neg_result = '0;  
                    a_reg = a;
                    b_reg = b;
                end
                2'b01:
                begin

                    neg_result = (!is_rem) ? ((a[31] ^ b[31]) && ((a != '0) && (b != '0))) : (is_rem && a[31] && !b[31])|| (is_rem && a[31] && b[31]) ; // basically x or to see if not pos pos or neg neg
           
                    a_reg = (a[31]) ? {(~a + 1'b1)} : a;
                    b_reg = (b[31]) ? {(~b + 1'b1)} : b;
                end
                2'b10:
                begin
                    neg_result = a[31];
                    a_reg = (a[31]) ? {(~a + 1'b1)} : a;
                    b_reg = b;
                end
                default: neg_result = 'x;

            endcase
    
    end





// assign complete = mul_complete || divide_complete;
assign idle_ = mul_complete & divide_complete ;

assign mul_start = (!(|mul_div_rem_var) && start_signal);
assign div_start = (|mul_div_rem_var && start_signal);

DW_mult_seq #(
    .a_width(32),
    .b_width(32),
    .tc_mode(0),
    .num_cyc(4),
    .rst_mode(1),
    .input_mode(1),
    .output_mode(0),
    .early_start(1)
)
multiply
(
    .clk(clk),
    .rst_n(~(rst| flush_fu_by_branch)),
    .a(a_reg),
    .b(b_reg),
    .hold('0),
    .start(mul_start),
    .complete(mul_complete_original),
    .product(multiply_out_original)
);

DW_div_seq #(
    .a_width(32),
    .b_width(32),
    .tc_mode(0),
    .input_mode(1), // register inputs
    .output_mode(0), // non registered outputs since CDB is registerized
    .num_cyc(16),
    .rst_mode(1), // synchronous reset
    .early_start(1)
)
divide
(
    .clk(clk),
    .rst_n(!(rst| flush_fu_by_branch)), // on branches flush multiply
    .hold('0),           // currently deciding to never stall operation
    .start (div_start), // basically togle to save power
    .a(a_reg), 
    .b(b_reg),
    .complete(divide_complete_original),
    .quotient(divide_quotient_original),
    .remainder(remainder_original),
    .divide_by_0(divide_by_zero_original)       // basically check if b is zero when dividing 
);

// output registers
always_ff @ (posedge clk) begin
    if (rst) begin
        divide_complete <= '0;
        mul_complete <= '0;
        multiply_out <= '0;
        divide_quotient <= '0;
        remainder <= '0;
        divide_by_zero  <= '0;
    end
    else  begin
        divide_complete <= divide_complete_original;
        mul_complete <= mul_complete_original;
        multiply_out <= multiply_out_original;
        divide_quotient <= divide_quotient_original;
        remainder <= remainder_original;
        divide_by_zero  <= divide_by_zero_original;
    end
end 

always_comb begin
    chosen_out = '0;
    unique case(mul_div_rem_var)
        2'b11 :  begin
            chosen_out = {32'b0,divide_quotient};
        end
        2'b00 : begin
            chosen_out = multiply_out;
        end
        2'b10 : begin
            chosen_out = {32'b0,remainder};
        end
        default: chosen_out = 'x;
    endcase
end


    always_comb begin 
        temp = 'x;
        unique case (mul_type)
            2'b00: begin
                temp = chosen_out[63:0];
            end
            2'b01, 2'b10: begin
                temp = neg_result ? (~chosen_out + 1'b1) : chosen_out;
                if(remainder == a && (is_rem)) begin
                    temp = {32'b0,remainder};
                end
            end

            default: temp = 'x;
        endcase
    end

   assign cdb_result = (half) ? temp[63:32] : temp[31:0]; 



// set CDB
// always_ff @(posedge clk) begin

//     if(rst) begin

//         CDB_muld.valid <= '0;
//         CDB_muld.rob_pointer <= 'x; 
//         CDB_muld.ps1 <= 'x;
//         CDB_muld.ps2 <= 'x;
//         CDB_muld.rd_v <= 'x;

//     end

//     if(complete) begin

//         CDB_muld.valid <= '1;
//         CDB_muld.rob_idx <= rob_idx_reg; 
//         CDB_muld.arch_d_reg <= arch_d_register;
//         CDB_muld.phys_d_reg <= phys_d_register;
//         CDB_muld.rd_v <= cdb_result;

//     end
//     else begin

//         CDB_muld.valid <= '0;
//         CDB_muld.rob_idx <= rob_idx_reg; 
//         CDB_muld.arch_d_reg <= arch_d_register;
//         CDB_muld.phys_d_reg <= phys_d_register;
//         CDB_muld.rd_v <= cdb_result;
//     end
// end
assign is_divide = (mul_op_reg==m_div)||(mul_op_reg==m_divu);
assign is_rem = (mul_op_reg==m_rem)||(mul_op_reg==m_remu);
assign cdb_entry_mult_out = cdb_entry_mult;
always_comb begin
    cdb_entry_mult.valid = '0;
    cdb_entry_mult.rob_idx = rob_idx_reg; 
    cdb_entry_mult.arch_d_reg = arch_d_register;
    cdb_entry_mult.phys_d_reg = phys_d_register;
    cdb_entry_mult.rd_v = (divide_by_zero && (is_rem)) ? a : (divide_by_zero && (is_divide)) ? '1 : cdb_result;
    cdb_entry_mult.control_bit_map = control_bit_map_reg;
    if(complete) cdb_entry_mult.valid = '1;

end

always_comb begin
    rs_full = '1;
    for (int i = 0; i < MULT_RS_NUM; i++) begin
        if (reservation_stations[i].finished == 1'b1) begin
            rs_full = '0;
            break;
        end 
    end
end

assign rs_mul_full = rs_full;

endmodule
