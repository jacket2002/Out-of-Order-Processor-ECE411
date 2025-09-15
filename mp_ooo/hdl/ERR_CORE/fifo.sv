module fifo
import rv32i_types::*;
#(

    parameter DATA_WIDTH = 32,
    parameter QUEUE_SIZE = 16
)
(

    input logic [DATA_WIDTH-1:0] write_data, // inst
    input logic [DATA_WIDTH-1:0] imem_addr, // the pc_val
    input logic write_en,
    input logic clk,
    input logic rst,

    input logic [3:0]  branch_pattern,
    input logic [1:0] saturating_counter,
    input logic [31:0] pc_target_predict,
    output logic [3:0]  branch_pattern_out,
    output logic [1:0] saturating_counter_out,
    output logic [31:0] pc_target_predict_out,

    input logic read_en,
    output logic [DATA_WIDTH-1:0] read_data, // inst
    output logic [DATA_WIDTH-1:0] read_data_pc, // pc_val
    output logic queue_full, queue_empty,
    output logic read_ack, write_ack

);

/*

Functionality :

write happens same cycle

Enables must be held for a whole cycle to ensure data arrives correctly and same with write_data

*/


localparam tmp_size = QUEUE_SIZE;
localparam int size = $clog2(QUEUE_SIZE);

inst_fifo_t mem [tmp_size];

logic [size:0] write_ptr, read_ptr;

logic [DATA_WIDTH-1:0] read_data_next;
logic start, read_start;



assign queue_full = ((write_ptr[size-1:0] == read_ptr[size-1:0])&&(write_ptr[size] != read_ptr[size])) ? '1 : '0; // makes sure read_ptr is more thanone away
assign queue_empty = (write_ptr == read_ptr) ? '1 : '0;

// write ptr
always_ff @(posedge clk) begin

    if(rst) begin
        write_ptr <= '0;
    end
    else if(write_en&&!queue_full) begin
        write_ptr <= write_ptr + 1'b1;
    end
 
end

// read ptr
always_ff @(posedge clk) begin

    if(rst) begin
        read_ptr <= '0;
    end
    else if(read_en&&!queue_empty) begin
        read_ptr <= read_ptr + 1'b1;
    end
 
end

// setting read data
always_comb begin

    if(read_en && !queue_empty) begin
        read_data = mem[read_ptr[size-1:0]].inst;
        read_data_pc = mem[read_ptr[size-1:0]].pc;
        branch_pattern_out = mem[read_ptr[size-1:0]].branch_pattern;
        saturating_counter_out = mem[read_ptr[size-1:0]].saturating_counter;
        pc_target_predict_out = mem[read_ptr[size-1:0]].pc_target_predict;
        read_ack = '1;
    end
    else begin
        read_data = 'x;
        read_ack = '0;
        branch_pattern_out = 'x;
        saturating_counter_out = 'x;
        pc_target_predict_out = 'x;
        read_data_pc = 'x;
    end

end

//writing data

always_ff @(posedge clk) begin
    // if (rst) begin
    //     mem <= '0;
    // end
    // else 
    if(write_en && !queue_full && !rst) begin

        mem[write_ptr[size-1:0]].inst <= write_data;
        mem[write_ptr[size-1:0]].pc <= imem_addr;
        mem[write_ptr[size-1:0]].branch_pattern <= branch_pattern;
        mem[write_ptr[size-1:0]].saturating_counter <= saturating_counter;
        mem[write_ptr[size-1:0]].pc_target_predict <= pc_target_predict;
        // write_ack <= '1;

    end
    // else begin

    //     write_ack <= '0;
    // end

end

always_comb begin
    if (write_en && !queue_full) begin
        write_ack = '1;
    end else begin
        write_ack = '0;
    end
end





endmodule
