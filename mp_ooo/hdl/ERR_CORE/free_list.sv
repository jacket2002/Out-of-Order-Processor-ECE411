module free_list
import rv32i_types::*;
import params::*;
#(

    parameter DATA_WIDTH = PHYSICAL_REG_FILE_LENGTH,
    parameter QUEUE_SIZE = FREE_LIST_QUEUE_LENGTH
)
(

    input logic [DATA_WIDTH-1:0] write_data,
    input logic write_en,
    input logic clk,
    input logic rst,

    input  logic   flush_by_branch,
    // come from BRAT
    input  logic   [FREE_LIST_PTR_WIDTH : 0] free_list_rd_ptr_out,
    // connect to BRAT
    output   logic   [FREE_LIST_PTR_WIDTH : 0] free_list_rd_ptr_in,  // three write_data

    input logic read_en,
    output logic [DATA_WIDTH-1:0] read_data,
    output logic queue_full, queue_empty,
    output logic read_ack, write_ack

);

/*

Functionality :

write happens same cycle

Enables must be held for a whole cycle to ensure data arrives correctly and same with write_data

*/


// logic [63:0] read_ptr_count, write_ptr_count;

localparam tmp_size = QUEUE_SIZE;
localparam int size = $clog2(QUEUE_SIZE);

localparam int size_one = size-1;

logic [DATA_WIDTH-1:0] mem [tmp_size];
logic [size:0] write_ptr, read_ptr;

logic [DATA_WIDTH-1:0] read_data_next;
logic start, read_start;
logic [size:0] debug_queue_length;

assign debug_queue_length = write_ptr - read_ptr;

assign free_list_rd_ptr_in = read_ptr;

assign queue_full = ((write_ptr[size-1:0] == read_ptr[size-1:0])&&(write_ptr[size] != read_ptr[size])) ? '1 : '0; // makes sure read_ptr is more thanone away
assign queue_empty = (write_ptr == read_ptr) ? '1 : '0;

// write ptr
always_ff @(posedge clk) begin

    if(rst) begin
        write_ptr <= {1'b1, {size{1'b0}}};
        // write_ptr_count <='0;
    end
    else if(write_en&&!queue_full&&write_data != '0) begin
        write_ptr <= write_ptr + 1'b1;
        // write_ptr_count <= write_ptr_count +1'b1;
    end
 
end

// read ptr
always_ff @(posedge clk) begin

    if(rst) begin
        // read_ptr_count<='0;
        // read_ptr <= {{size{1'b0}},1'b1};
        read_ptr <=  '0;
    end
    else if (flush_by_branch) begin
        read_ptr <= free_list_rd_ptr_out;
    end
    else if(read_en&&!queue_empty) begin
        read_ptr <= read_ptr + 1'b1;
        // read_ptr_count <= read_ptr_count+1'd1;
    end
 
end

// setting read data
always_comb begin

    if(read_en && !queue_empty) begin
        read_data = mem[read_ptr[size-1:0]];
        read_ack = '1;
    end
    else begin
        read_data = 'x;
        read_ack = '0;

    end

end

//writing data
logic [size-1:0] tmp;
assign tmp = write_ptr[size-1:0];
always_ff @(posedge clk) begin

    if(rst) begin
        for (int unsigned i =0; i < QUEUE_SIZE; i++) begin
            mem[i] <= DATA_WIDTH'(i) + 6'd32;
            // mem[i] <= i;
        end 
    end
    if(write_en && !queue_full && write_data != '0) begin

        mem[write_ptr[size-1:0]] <= write_data;
        write_ack <= '1;

    end
    else begin

        write_ack <= '0;
    end

end





endmodule
