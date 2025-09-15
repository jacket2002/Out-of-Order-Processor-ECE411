module write_clean_queue
import rv32i_types::*;
import params::*;
#(

    parameter DATA_WIDTH = 256,
    parameter QUEUE_SIZE = 4
)
(

    input inst_mem_t write_data, 
    input logic [255:0] dfp_rdata, // inst
    output logic [31:0] dfp_addr,
    input logic [31:0] dfp_raddr,
    output logic dfp_read, dfp_write,
    output logic [255:0] dfp_wdata,
    output logic search_valid,

    input logic [31:0] search_address, 

    input logic write_en,
    input logic clk,
    input logic rst,
    input logic dfp_resp,
    input logic read_en,
    output inst_mem_t read_data, // inst
    output logic queue_full, queue_empty,
    output logic read_ack, write_ack,
    input logic stall,
    input logic dcache_serviced,
    input logic dfp_resp_write,
    output logic search_index_valid,
    input logic [1:0] initial_index_replace,
    input logic [255:0] data_dirty_hit,
    input logic [1:0] index_hit,
    input logic  write_hit,
    input dec_exec d_e,
    input  logic is_idle

);

// valid indicates the space is valid to write to and zero indicates you can not


localparam tmp_size = QUEUE_SIZE;
localparam int size = $clog2(QUEUE_SIZE);


inst_mem_t mem [tmp_size];
inst_mem_t temp_dfp, temp_mem, temp_s, temp_i, temp_h;

logic dirty_hit;


logic [size:0] write_ptr, read_ptr, ghost_read_ptr;
logic [size-1:0] dfp_index_write_after,dfp_index_write_before, index_dirty;

logic [DATA_WIDTH-1:0] read_data_next;
logic start, read_start;
logic after_read_ptr;



assign queue_full = ((write_ptr[size-1:0] == read_ptr[size-1:0])&&(write_ptr[size] != read_ptr[size])) ? '1 : '0; // makes sure read_ptr is more thanone away
assign queue_empty = (write_ptr == read_ptr) ? '1 : '0;

// write ptr

logic stall_dirty;
assign stall_dirty = !stall||write_data.dirty;
always_ff @(posedge clk) begin

    if(rst) begin
        write_ptr <= '0;
    end
    else if(write_en&&!queue_full && stall_dirty && write_ack) begin
        write_ptr <= write_ptr + 1'b1;
    end

end

// read ptr
always_ff @(posedge clk) begin

    if(rst) begin
        read_ptr <= '0;
    end
    else if(read_en&&!queue_empty && mem[read_ptr[size-1:0]].valid && is_idle) begin
        read_ptr <= read_ptr + 1'b1;
    end
 
end

// setting read data
always_comb begin

    if(read_en && !queue_empty && mem[read_ptr[size-1:0]].valid && is_idle) begin
        read_data = mem[read_ptr[size-1:0]];
        read_ack = '1;
    end
    else begin
        read_data = '0;
        read_ack = '0;
     
    end

end

//writing data

logic success;

always_ff @(posedge clk) begin

    
    

    if(rst) begin

        for(int i = 0; i<QUEUE_SIZE; i++) begin
                mem[i] <= '0;
                mem[i].valid <= '1;
                mem[i].read <= '1;
        end

    end
    else begin
        if(write_en && !queue_full && !rst && mem[write_ptr[size-1:0]].valid && stall_dirty && write_ack) begin
            mem[write_ptr[size-1:0]] <= write_data;
        end
        
        if(dfp_resp) begin

            if(after_read_ptr) begin

             
                   

                        mem[dfp_index_write_after].valid <= '1;
                        mem[dfp_index_write_after].dmem_rdata <= dfp_rdata;
                        
            end
            else begin

           

                        mem[dfp_index_write_before].valid <= '1;
                        mem[dfp_index_write_before].dmem_rdata <= dfp_rdata;
                       

                    
             
            end
        end
        if(dfp_resp_write) begin
            mem[ghost_read_ptr[size-1:0]].valid <= '1;
        end
        if(read_ack) begin
            mem[read_ptr[size-1:0]].read <= '1;
        end
        if(dirty_hit) begin

             mem[index_dirty].dirty_data <= data_dirty_hit; 

        end
    end
    
end




always_comb begin
    
    after_read_ptr = '0;
    dfp_index_write_after = '0;
    dfp_index_write_before = '0;
if(dfp_resp) begin

    for(int unsigned i = 0; i<QUEUE_SIZE; i++ ) begin

            if(!mem[i].valid && mem[i].bmem_addr ==  dfp_raddr && (2'(i) >= read_ptr[size-1:0])) begin
                after_read_ptr = 1'b1;
                dfp_index_write_after = 2'(i);
                break;
            end
        end
    
    for(int unsigned i = 0; i < QUEUE_SIZE; i++ ) begin
            if(!mem[i].valid && mem[i].bmem_addr ==  dfp_raddr && (2'(i)< read_ptr[size-1:0])) begin
               
                dfp_index_write_before = 2'(i);
                break;
            end
    end
end
end

always_comb begin

    if (write_en && !queue_full) begin

        write_ack = '1;
        for(int  i = 0; i < QUEUE_SIZE; i++) begin
            if(write_data.bmem_addr == mem[i].bmem_addr && !mem[i].valid&& !mem[i].dirty) begin
                write_ack = '0;
            end
        end
        
    end else begin
        write_ack = '0;
    end

end




// ghost read_ptr stuff

always_ff @(posedge clk) begin

   
    if(rst) begin
        ghost_read_ptr <= '0;
    end
    else begin
        if(!(write_ptr == ghost_read_ptr) && dcache_serviced) begin
            ghost_read_ptr <= (dfp_write) ? ghost_read_ptr + dfp_resp_write :  ghost_read_ptr + 1'b1;
        end
    end

end




always_comb begin

    dfp_read = '0;
    dfp_write = '0;
    dfp_addr = 'x;
    dfp_wdata = 'x;

    if(ghost_read_ptr != write_ptr) begin
        temp_dfp = mem[ghost_read_ptr[size-1:0]];
        dfp_addr = temp_dfp.bmem_addr;
        dfp_read = |temp_dfp.read_mask || |temp_dfp.write_mask;
        dfp_write = temp_dfp.dirty;
        dfp_wdata = temp_dfp.write_data;
    end
end



//receive logic



logic [31:0] dirty_address;

always_comb begin

    search_valid = '1;

    for(int i =0; i<QUEUE_SIZE; i++) begin
        temp_s = mem[i];
        dirty_address = {temp_s.dirty_tag, temp_s.set, 5'b00000};
        if((temp_s.bmem_addr == search_address && !temp_s.valid && !temp_s.dirty) || (dirty_address ==search_address && !temp_s.dirty && !temp_s.read&&temp_s.is_dirty)) begin
            search_valid = '0;
        end


    end

end

always_comb begin

    search_index_valid = '1;

    for(int i =0; i<QUEUE_SIZE; i++) begin
        temp_i = mem[i];
        if(temp_i.set == write_data.set && temp_i.index_replace == initial_index_replace && !temp_i.read) begin
            search_index_valid = '0;
        end


    end

end


always_comb begin
    dirty_hit = '0;

    if(write_hit) begin

        for(int i =0; i<QUEUE_SIZE; i++) begin



            temp_h = mem[i];

            if(temp_h.set == d_e.set_idx && temp_h.index_replace == index_hit && !temp_h.read && temp_h.is_dirty) begin
                dirty_hit = '1;
                index_dirty = 2'(i);
            end


        end
    end


end



endmodule
