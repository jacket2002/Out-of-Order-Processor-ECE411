module fetch
import rv32i_types::*;
import params::*;
(

    input logic clk,
    input logic rst,

    input  logic   flush_by_branch,
    input logic [31:0] pc_target,

    output logic [31:0] imem_addr,
    output logic [3:0] imem_rmask,
    input logic [31:0] imem_rdata, 
    input logic imem_resp,
    output logic [31:0] instruction,
    output logic [31:0] pc_out,

    input logic valid_hist_entry,
    input logic [25:0] pc_tag,   // first 26 bits of pc, (4 bits for index)
    input logic [3:0]  branch_pattern,
    input logic [1:0]  saturating_counter,
    input logic [31:0] pc_target_predict,
    output logic [3:0]  branch_pattern_out,
    output logic [1:0]  saturating_counter_out,
    output logic [31:0] pc_target_predict_out,

    //decode signals
    input logic read,
    // input logic dispatch_stall,
    output logic read_ack
    
);


logic [31:0] instruction_write, instruction_read, pc_next, pc, write_data;

logic [3:0]  branch_pattern_in;
logic [1:0] saturating_counter_in;
logic [31:0] pc_target_predict_in;

logic write, read_test, full, empty, write_ack;

logic latched_reset, prev_resp;
logic garbage_imem;



always_ff @(posedge clk) begin

    if(rst) begin
        pc<= 32'h1eceb000;
    end
    else if (flush_by_branch) begin
        pc <= pc_target;
    end
    else if(imem_resp && !full) begin
        pc<=pc_next;
    end
    else begin
        pc <= pc;
    end
end

always_ff @(posedge clk) begin 
    if (rst) garbage_imem <= 1'b0;
    else if (flush_by_branch & (!imem_resp)) garbage_imem <= 1'b1;
    else if (imem_resp) garbage_imem <= 1'b0;
end

always_comb begin
    pc_next = pc + 'd4;
    if (!(imem_resp & !garbage_imem) && !full)begin
        pc_next = pc;
    end else begin
        if (flush_by_branch) pc_next = pc_target;
        // else if (valid_hist_entry && pc_tag == pc[31:6] && saturating_counter[1])  pc_next = pc_target_predict;
        else if (valid_hist_entry) begin
            if (pc_tag == pc[31:6] && saturating_counter[1]) begin
                pc_next = pc_target_predict;
            end
        end
        else pc_next = pc + 'd4;
    end
end

always_ff @(posedge clk) begin

    latched_reset <= rst;
//     if(rst) begin
//         imem_rmask <= '0;
//     end
//     else if(!write_ack && !latched_reset) begin
//         imem_rmask <= '0;
//     end
//     else begin
//         imem_rmask <= '1;
//     end

end

always_comb begin
    if (!latched_reset && !imem_resp) begin
        imem_rmask = '0;
    end else begin
        imem_rmask = '1;
    end
end

// logic check;

// always_ff @(posedge clk) begin

//    if(rst) begin
//         prev_resp <='0;

//    end 
//    else if(imem_resp) begin
//         prev_resp <= '1;
//         latched_write_data <= imem_rdata;
//    end
//    else if (!write_ack) begin
//         prev_resp <=prev_resp;
    
//    end
//    else begin

//         prev_resp<= '0;

//     end
//         check <= (prev_resp)&&full;

// end





always_comb begin



    imem_addr = (!write_ack && !flush_by_branch) ? pc : pc_next;
    // write = imem_resp || check;
    write = imem_resp && !full;
    instruction = (read_ack) ? instruction_read : 'x;

    // write_data = imem_resp ? imem_rdata : latched_write_data;
    write_data =imem_rdata ;


end

always_comb begin
    branch_pattern_in = 4'b0000;
    saturating_counter_in = 2'b01;
    pc_target_predict_in = '0;
    if (valid_hist_entry) begin
        if (pc_tag == pc[31:6]) begin
            branch_pattern_in = branch_pattern;
            saturating_counter_in = saturating_counter;
            pc_target_predict_in = pc_target_predict;
        end
    end
end


fifo #(

    .DATA_WIDTH(32),
    .QUEUE_SIZE(INSTRUCTION_QUEUE_DEPTH)
    
)
instruction_queue (

    .write_data(write_data),
    .imem_addr(pc),
    .write_en(write && (!garbage_imem)),
    .clk(clk),
    .rst(rst|flush_by_branch),

    .branch_pattern(branch_pattern_in),
    .saturating_counter(saturating_counter_in),
    .pc_target_predict(pc_target_predict_in),
    .branch_pattern_out(branch_pattern_out),
    .saturating_counter_out(saturating_counter_out),
    .pc_target_predict_out(pc_target_predict_out),

    .read_en(read),
    .read_data(instruction_read),
    .read_data_pc(pc_out),

    .queue_full(full), 
    .queue_empty(empty),

    .write_ack(write_ack),
    .read_ack(read_ack)

);








endmodule
