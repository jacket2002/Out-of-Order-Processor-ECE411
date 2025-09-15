module control_queue
import rv32i_types::*;
import params::*;
#(
    parameter QUEUE_SIZE = CONTROL_Q_DEPTH
)
(

    input control_rs_entry_t write_data, // inst
    input logic write_en,
    input logic clk,
    input logic rst,

    input   logic   flush_by_branch,  // same as rst here

    input   cdb_entry_t         cdb_entry_mult, 
    input   cdb_entry_t         cdb_entry_branch,
    input   cdb_entry_t         cdb_entry_alu,
    input   cdb_entry_t         cdb_entry_mem, 

    input logic SQ_read_ack_out, // to update the recorded bit map
    input logic [MEM_QUEUE_PTR_WIDTH : 0] SQ_read_ptr, 

    // input logic read_en,
    output logic [CONTROL_Q_PTR_WIDTH : 0]   control_read_ptr,
    output control_rs_entry_t           read_data, // inst
    output logic                        queue_full, queue_empty,
    output logic [CONTROL_Q_DEPTH-1:0]  control_bit_map,
    output logic                        read_ack, write_ack

);

/*

Should be cleared on flush

*/


localparam tmp_size = QUEUE_SIZE;
localparam int size = $clog2(QUEUE_SIZE);

control_rs_entry_t mem [tmp_size];

logic [size:0] write_ptr, read_ptr;

logic read_en;

assign read_en = (!queue_empty && mem[read_ptr[size-1:0]].phys_r1_valid == '1 && mem[read_ptr[size-1:0]].phys_r2_valid == '1) ? 1'b1 : 1'b0;

assign queue_full = ((write_ptr[size-1:0] == read_ptr[size-1:0])&&(write_ptr[size] != read_ptr[size])) ? '1 : '0; // makes sure read_ptr is more thanone away
assign queue_empty = (write_ptr == read_ptr) ? '1 : '0;

assign control_read_ptr = read_ptr;

// write ptr
always_ff @(posedge clk) begin

    if(rst|flush_by_branch) begin
        write_ptr <= '0;
    end
    else if(write_en&&!queue_full) begin
        write_ptr <= write_ptr + 1'b1;
    end
 
end

logic read_en_reg, queue_empty_reg;
logic [size:0] read_ptr_reg;
always_ff @(posedge clk) begin

    if(rst|flush_by_branch) begin
        read_en_reg <= '0;
        read_ptr_reg <= '0;
        queue_empty_reg <= '0;
    end
    else begin
        read_en_reg <= read_en;
        read_ptr_reg <= read_ptr;
        queue_empty_reg <= queue_empty;
    end
 
end

// bit map. used in dispatch state to tag RS_entries
always_ff @(posedge clk) begin

    if(rst|flush_by_branch) begin
        control_bit_map <= '0;
    end
    else begin
        if (read_en_reg&&!queue_empty_reg) begin
            control_bit_map[read_ptr_reg[size-1:0]] <= 1'b0;
        end
        if(write_en&&!queue_full) begin
            control_bit_map[write_ptr[size-1:0]] <= 1'b1;
        end
    end
 
end

// read ptr
always_ff @(posedge clk) begin

    if(rst|flush_by_branch) begin
        read_ptr <= '0;
    end
    else if(read_en&&!queue_empty) begin
        read_ptr <= read_ptr + 1'b1;
    end
 
end

// setting read data
always_comb begin

    if(read_en && !queue_empty) begin
        read_data = mem[read_ptr[size-1:0]];
        read_ack = '1;
        if (SQ_read_ack_out) read_data.store_bitmap[SQ_read_ptr[STORE_QUEUE_PTR_WIDTH-1:0]] = 1'b0;
    end
    else begin
        read_data = 'x;
        read_ack = '0;
    end

end

//writing data
    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < QUEUE_SIZE; i++) begin
                mem[i] <= '0;
            end
        end
        else begin
            //  exec finished, set corresponding finish to 1; set invalid operand to valid
            for (int i = 0; i < QUEUE_SIZE; i++) begin
                if (cdb_entry_branch.valid) begin
                    if (cdb_entry_branch.phys_d_reg == mem[i].phys_r1) begin
                        mem[i].phys_r1_valid <= 1'b1;
                    end
                    if (cdb_entry_branch.phys_d_reg == mem[i].phys_r2) begin
                        mem[i].phys_r2_valid <= 1'b1;
                    end
                end 
            
                if (cdb_entry_alu.valid) begin
                // for (int i = 0; i < ALU_RS_NUM; i++) begin
                    if (cdb_entry_alu.phys_d_reg == mem[i].phys_r1) begin
                        mem[i].phys_r1_valid <= 1'b1;
                    end
                    if (cdb_entry_alu.phys_d_reg == mem[i].phys_r2) begin
                        mem[i].phys_r2_valid <= 1'b1;
                    end
                end 

                if (cdb_entry_mult.valid) begin
                // for (int i = 0; i < ALU_RS_NUM; i++) begin
                    if (cdb_entry_mult.phys_d_reg == mem[i].phys_r1) begin
                        mem[i].phys_r1_valid <= 1'b1;
                    end
                    if (cdb_entry_mult.phys_d_reg == mem[i].phys_r2) begin
                        mem[i].phys_r2_valid <= 1'b1;
                    end
                end 

                if (cdb_entry_mem.valid) begin
                    if (cdb_entry_mem.phys_d_reg == mem[i].phys_r1) begin
                        mem[i].phys_r1_valid <= 1'b1;
                    end
                    if (cdb_entry_mem.phys_d_reg == mem[i].phys_r2) begin
                        mem[i].phys_r2_valid <= 1'b1;
                    end
                end
            end
            // if(write_en && !queue_full && !(rst|flush_by_branch)) begin
            if(write_en && !queue_full) begin          
                mem[write_ptr[size-1:0]] <= write_data;
            end
            if (SQ_read_ack_out) begin
                for (int i = 0; i < QUEUE_SIZE; i++) begin
                    mem[i].store_bitmap[SQ_read_ptr[STORE_QUEUE_PTR_WIDTH-1:0]] <= 1'b0;
                end
            end
        end

    end

always_comb begin
    if (write_en && !queue_full) begin
        write_ack = '1;
    end else begin
        write_ack = '0;
    end
end

endmodule
