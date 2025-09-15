module non_blocking_cache 
import params::*;
import rv32i_types::*;
(
    input   logic           clk,
    input   logic           rst,
    // input   logic              ready,
    // input   logic   [1:0]   write_count,

    // cpu side signals, ufp -> upward facing port
    input   logic   [31:0]  ufp_addr,
    input   logic   [3:0]   ufp_rmask,
    input   logic   [3:0]   ufp_wmask,
    output  logic   [31:0]  ufp_rdata,
    input   logic   [31:0]  ufp_wdata,
    output  logic           ufp_resp,

    // memory side signals, dfp -> downward facing port
    output  logic   [31:0]  dfp_addr,
    output  logic           dfp_read,
    output  logic           dfp_write,
    input   logic   [255:0] dfp_rdata,
    output  logic   [255:0] dfp_wdata,
    input   logic           dfp_resp,

    input   logic   [31:0] dfp_raddr,
    input logic dcache_serviced,
    input   logic  dfp_resp_write,


    // LSQ
    output logic ready,
    input logic [LOAD_RS_INDEX_BITS-1:0] index_write,
    output logic [LOAD_RS_INDEX_BITS-1:0] index_resp,
    output logic  dmem_resp_type

);



logic [255:0] data [3:0];
logic [255:0] data_in;
logic [23:0] tag_in [3:0];
logic [23:0] tag_out [3:0];
logic tag_write [3:0];
logic data_write [3:0];
logic chip_select [3:0];
logic [1:0] is_valid [3:0];
logic is_dirty;
logic write_en_send;
logic [3:0] current_set [3:0];
logic [1:0] index_hit;   
logic [31:0] write_mask [3:0];
logic write_stall, queue_full, queue_full_latch,queue_full_stall, write_ack, is_write_valid;
logic we_have_data_to_write;
logic hit_stall;
logic [2:0] LRU_next;
logic [2:0] LRU_new, dummy;
logic [1:0] index_replace;
logic LRU_access, LRU_write;
logic line_replaced;
logic [1:0] v;
logic [23:0] dirty_temp;
logic [255:0] data_no_shift, second_wdata;
logic [31:0] write_no_shift, read_no_shift, second_wmask;
logic [31:0] mask_shift_val;
logic [31:0] write_shift_val;
logic [3:0] read_lru_set;
logic [3:0] hit_ways;
logic [31:0] indexed_data;
logic [31:0] exact_bytes;
logic [31:0] dfp_exact_bytes;
logic [31:0] ufp_rdata_queue,ufp_rdata_queue_next, ufp_rdata_hit;
logic [31:0] dfp_addr_stage;
logic hit, ufp_resp_hit,ufp_resp_queue,ufp_resp_queue_next ;
logic [255:0] temp, temp1;
logic mask_valid;
logic write_non_dirty, write_non_dirty_next;
logic [23:0] addr_temp;
dec_exec d_e, d_e_next;
non_state_types state;
non_state_types next_state;
logic in_queue, queue_write_stall;
logic is_write_invalid, test_valid, index_replace_stall_next, index_replace_stall, miss;

inst_mem_t write_instruction, write_instruction_read, write_instruction_send;

logic [LOAD_RS_INDEX_BITS-1:0] index_immediate, index_queue, index_queue_next; 
logic [255:0] write_dirty, data_dirty_hit;



logic [255:0] write_temp, wmask_temp, data_in_temp;
logic[31:0] search_address, ufp_raddr;
logic search_valid, stall, read_ack;
logic dmem_resp_type_queue, dmem_resp_type_hit, dmem_resp_type_queue_next;
logic read_en;

logic search_index_valid;





assign dirty_temp = tag_out[index_replace];
assign is_dirty = is_valid[index_replace][0] ? dirty_temp[23] : '0;

// below is pipeline registers updating d_e refrencing the decode/execute stage 

assign ready = !(write_stall || hit_stall || index_replace_stall || queue_full_stall);

always_ff @(posedge clk) begin

    if(rst) begin
        d_e <='0;
    end
    else if(write_stall || hit_stall || index_replace_stall || queue_full_stall)begin
        d_e <=d_e;
    end
    else begin
        d_e<=d_e_next;
    end
end

assign stall  =  hit_stall || index_replace_stall ||queue_full_stall;


// decode info
cache_decode cache_decode(
    .*
);

assign data_no_shift = {224'b0, d_e.wd_small};
assign write_no_shift = {28'b0, d_e.small_w};
assign mask_shift_val = d_e.addr[4:2]*4;
assign write_shift_val = d_e.addr[4:2] *32;

assign second_wmask = write_no_shift << (mask_shift_val);
assign second_wdata = data_no_shift << (write_shift_val);


// below is our arrays


// make dual port
    generate for (genvar i = 0; i < 4; i++) begin : arrays
        mp_cache_data_array data_array (
            .clk0       (clk),
            .csb0       (chip_select[i]),
            .web0       (data_write[i]),
            .wmask0     (write_mask[i]),
            .addr0      (current_set[i]),
            .din0       (data_in),
            .dout0      (data[i])

            
        );
        mp_cache_tag_array tag_array (
            .clk0       (clk),
            .csb0       (rst),
            .web0       (tag_write[i]),
            .addr0      (current_set[i]),
            .din0       (tag_in[i]),
            .dout0      (tag_out[i])

        
        );
        valid_array_1 valid_array ( // now two bits, first bit is valid to write to next bit is invalid to write to 

            .clk0       (clk),
            .rst0       (rst),
            .csb0       (chip_select[i]),
            .web0       (tag_write[i]),
            .addr0      (current_set[i]),
            .din0       (v),
            .dout0      (is_valid[i])

        );
   
    end endgenerate

    lru_array lru_array (
        .clk0       (clk),
        .rst0       (rst),
        .csb0       ('0),
        .web0       ('1),
        .addr0      (read_lru_set),
        .din0       ('x),
        .dout0      (LRU_next),
        .csb1       (d_e.chip_select),
        .web1       (LRU_write),
        .addr1      (d_e.set_idx),
        .din1       (LRU_new),
        .dout1      (dummy)
    );

   

// below is execute stage 

 always_ff @(posedge clk) begin

    if(rst) begin
        state <= idle_n;
    end
    else if((!(hit_stall || index_replace_stall || queue_full_stall)) || (read_ack && !write_instruction_read.dirty && state==idle_n) ) begin
        state<= next_state;
    end

 end

 assign mask_valid = d_e.read_mask != 4'b0000 || d_e.small_w != 4'b0000;
 assign temp = (data[index_hit]>>(32*d_e.addr[4:2]));
 assign temp1 = (dfp_rdata>>(32*d_e.addr[4:2]));
 assign indexed_data = temp[31:0];
 assign dfp_exact_bytes = temp1[31:0];


 assign dfp_addr_stage = {d_e.addr[31:5], 5'b0};
 assign hit_ways = {is_valid[0][0]&&(tag_out[0][22:0] == d_e.tag), is_valid[1][0]&&(tag_out[1][22:0] == d_e.tag), is_valid[2][0]&&(tag_out[2][22:0] == d_e.tag),is_valid[3][0]&&(tag_out[3][22:0] == d_e.tag)};
 assign hit = is_valid[0][0]&&(tag_out[0][22:0] == d_e.tag) || is_valid[1][0]&&(tag_out[1][22:0] == d_e.tag) || is_valid[2][0]&&(tag_out[2][22:0] == d_e.tag) || is_valid[3][0]&&(tag_out[3][22:0] == d_e.tag);

 always_comb begin

    if(hit_ways[3]) begin
        index_hit = 2'd0;
    end
    else if(hit_ways[2]) begin
        index_hit = 2'd1;
    end
    else if (hit_ways[1]) begin
        index_hit = 2'd2;
    end
    else if (hit_ways[0]) begin
        index_hit = 2'd3;
    end
    else begin
        index_hit = 'x;
    end

   

 end

 
always_ff @(posedge clk) begin

  write_non_dirty <= write_non_dirty_next;
  ufp_rdata_queue<=ufp_rdata_queue_next;
  ufp_resp_queue<=ufp_resp_queue_next;
  index_queue <= index_queue_next;
  dmem_resp_type_queue <= dmem_resp_type_queue_next;


end
logic [22:0] temp_in_queue;

logic [255:0] temp_data;

assign temp_in_queue = tag_out[index_hit][22:0];
logic [1:0] valid_temp;
assign valid_temp = is_valid[index_hit];
assign in_queue = !valid_temp[1];

logic write_hit;
logic write_queue_dirty;

logic queue_full_stall_prev, write_stall_prev;


always_ff @(posedge clk) begin
    queue_full_stall_prev <= queue_full_stall;
    write_stall_prev <= write_stall;
end



 always_comb begin

        v = '1;
        data_write[0] = '1;
        data_write[1] = '1;
        data_write[2] = '1;
        data_write[3] = '1;
        write_mask[0] = '0;
        write_mask[3] = '0;
        write_mask[2] = '0;
        write_mask[1] = '0;
        chip_select[0] = '0;
        chip_select[1] = '0;
        chip_select[2] = '0;
        chip_select[3] = '0;
        current_set[0] = d_e_next.set_idx;
        current_set[3] = d_e_next.set_idx;
        current_set[2] = d_e_next.set_idx;
        current_set[1] = d_e_next.set_idx;
        read_lru_set = d_e_next.set_idx;
        tag_write[0] = '1;
        tag_write[2] = '1;
        tag_write[3] = '1;
        tag_write[1] = '1;
        tag_in[0] = '0;
        tag_in[2] = '0;
        tag_in[3] = '0;
        tag_in[1] = '0;
        data_in = 'x;
        LRU_write = '1;
        ufp_resp_hit = '0;
        write_stall = '0;
        ufp_rdata_hit = 'x; 
        write_non_dirty_next = '1;
        next_state = idle_n;
        write_hit = '0;
        miss = '0;
        hit_stall = '0;
        write_queue_dirty = '0;
        queue_full_stall = '0;
        search_address = '0;
        ufp_rdata_queue_next[31:0] = '0;
        ufp_resp_queue_next = '0;
        index_queue_next = '0;
        index_immediate = '0;
        dmem_resp_type_queue_next = 'x;
        dmem_resp_type_hit = 'x;
        read_en = '1;
      

    unique case (state)

        idle_n: begin

            search_address = dfp_addr_stage;
        
            data_in = second_wdata;
            tag_in[index_replace] = {1'b1,d_e.tag};
           
            ufp_resp_hit = '0;
          
            write_stall = '0;
            write_non_dirty_next = '1;
          

            hit_stall = '0;
            write_hit = '0;



            if(read_ack && !write_instruction_read.dirty) begin


                write_queue_dirty = write_instruction_read.is_dirty;
                if(write_instruction_read.read_mask != '0) begin

                    temp_data = write_instruction_read.dmem_rdata;
                    temp_data = write_instruction_read.dmem_rdata >> (32* write_instruction_read.offset );
                    ufp_rdata_queue_next = temp_data[31:0];
                    ufp_resp_queue_next = '1;
                    index_queue_next = write_instruction_read.index;
                    ufp_raddr = write_instruction.dmem_raddr;
                    data_in = write_instruction_read.dmem_rdata;
                    write_mask[write_instruction_read.index_replace] = '1;
                    data_write[write_instruction_read.index_replace] = '0;
                    tag_write[write_instruction_read.index_replace] = '0;
                    current_set[write_instruction_read.index_replace] = write_instruction_read.set;
                    tag_in[write_instruction_read.index_replace] = {'0,write_instruction_read.tag};
                    chip_select[write_instruction_read.index_replace] = '0;
                    
                    v ='1;
                    next_state = allocate;
                    dmem_resp_type_queue_next = '0;
                    queue_full_stall = queue_full_stall_prev ||write_stall_prev || mask_valid;
                   


                end
                else begin



                    ufp_rdata_queue_next = '0;
                    ufp_resp_queue_next = '1;
                    ufp_raddr = write_instruction_read.dmem_raddr;
                    index_queue_next = write_instruction_read.index;
                    write_temp = write_instruction_read.dmem_rdata & ~wmask_temp;
                    data_in = write_temp | (write_instruction_read.write_data);
                    write_mask[write_instruction_read.index_replace] = '1;
                    data_write[write_instruction_read.index_replace] = '0;
                    tag_write[write_instruction_read.index_replace] = '0;
                    current_set[write_instruction_read.index_replace] = write_instruction_read.set;
                    tag_in[write_instruction_read.index_replace] ={'1,write_instruction_read.tag};
                    chip_select[write_instruction_read.index_replace] = '0;
                    v ='1;
                    next_state = allocate;
                   read_lru_set = write_instruction_read.set;
                    dmem_resp_type_queue_next = '1;
                    queue_full_stall = queue_full_stall_prev||write_stall_prev|| mask_valid;



                    //write in data we were suppose to write in 

                end
                
            end
          
            else if(mask_valid) begin

                if(in_queue) begin
                    hit_stall = '1;
                end
                else begin
        
                    if(hit) begin
                        
                        index_immediate = d_e.index;
                        if(d_e.write_enable) begin

                            write_stall = '0;
                            LRU_write = '0;
                            ufp_rdata_hit = indexed_data;
                            ufp_resp_hit = '1;
                            dmem_resp_type_hit = '0;
                    
                        end
                        else begin

                            LRU_write = '0;
                            data_in = second_wdata;
                            write_mask[index_hit] = second_wmask;
                            data_write[index_hit] = queue_full;
                            tag_write[index_hit] = queue_full;
                            current_set[0] = d_e.set_idx;
                            current_set[1] = d_e.set_idx;
                            current_set[2] = d_e.set_idx;
                            current_set[3] = d_e.set_idx;
                            read_lru_set = d_e.set_idx;
                            tag_in[index_hit] = {1'b1,d_e.tag};
                            chip_select[index_hit] = '0;
                            write_stall = '0;
                            ufp_resp_hit = !queue_full;
                            write_non_dirty_next = '1;

                            write_hit = '1;
                            next_state = idle_d_a_n;
                            queue_full_stall = queue_full;
                            dmem_resp_type_hit = '1;
                            // we also need to send new information
                            v ='1;
                            
                        end
                    end
                    else begin




                        // send inputs

                        miss = '1;
   
                        // can low key just update valid bit
            
                        queue_full_stall = queue_full || !search_valid;
                        read_lru_set = d_e.set_idx;
                        LRU_write = '0;

                        if(queue_full_stall ||index_replace_stall) begin
                            current_set[0] = d_e.set_idx;
                            current_set[1] = d_e.set_idx;
                            current_set[2] = d_e.set_idx;
                            current_set[3] = d_e.set_idx;
                            read_lru_set = d_e.set_idx;
                            LRU_write = '1;
                        end
                        next_state = idle_n;
                            
                            
                        end
                end
            end
            else begin
                next_state = idle_n;
                write_stall = '0;
            end
            
          
        end

        idle_d_a_n : begin
            next_state = idle_n;
            ufp_resp_hit = '0;
            data_in = second_wdata;
            tag_in[index_replace] = {1'b1,d_e.tag};
   
            ufp_resp_hit = '0;
     
            write_stall = '1;
            write_non_dirty_next = '1;
            if(d_e.read_mask != 4'b0000 || d_e.small_w!= 4'b0000) begin
                current_set[3] = d_e.set_idx;
                current_set[2] = d_e.set_idx;
                current_set[1] = d_e.set_idx;
                current_set[0] = d_e.set_idx;
                read_lru_set = d_e.set_idx;
                chip_select[0] = '0;
                chip_select[1] = '0;
                chip_select[2] = '0;
                chip_select[3] = '0;
            end
            else begin
                write_stall = '0;
                current_set[0] = d_e_next.set_idx;
                current_set[3] = d_e_next.set_idx;
                current_set[2] = d_e_next.set_idx;
                current_set[1] = d_e_next.set_idx;
                read_lru_set = d_e_next.set_idx;
                chip_select[0] = '0;
                chip_select[1] = '0;
                chip_select[2] = '0;
                chip_select[3] = '0;
            end

        end

        allocate : begin

            //  write info

            write_stall = '1;
            ufp_resp_queue_next = '0;

            write_queue_dirty = '0;


            
             data_in = data_in_temp;
             write_mask[write_instruction_read.index_replace] = '1;
             data_write[write_instruction_read.index_replace] = '1;
             tag_write[write_instruction_read.index_replace] = '1;
             current_set[write_instruction_read.index_replace] = write_instruction_read.set;
             tag_in[write_instruction_read.index_replace] = {(write_instruction_read.read_mask == '0),write_instruction_read.tag};
             chip_select[write_instruction_read.index_replace] = '0;
             v ='1;
                        
              if(d_e.read_mask != 4'b0000 || d_e.small_w!= 4'b0000) begin
                current_set[3] = d_e.set_idx;
                current_set[2] = d_e.set_idx;
                current_set[1] = d_e.set_idx;
                current_set[0] = d_e.set_idx;
                read_lru_set = d_e.set_idx;
                chip_select[0] = '0;
                chip_select[1] = '0;
                chip_select[2] = '0;
                chip_select[3] = '0;
            end
            else begin
                hit_stall = '0;
                current_set[0] = d_e_next.set_idx;
                current_set[3] = d_e_next.set_idx;
                current_set[2] = d_e_next.set_idx;
                current_set[1] = d_e_next.set_idx;
                read_lru_set = d_e_next.set_idx;
                chip_select[0] = '0;
                chip_select[1] = '0;
                chip_select[2] = '0;
                chip_select[3] = '0;
            end
              next_state = idle_n;
              read_en ='0;

        end

        default : begin

            next_state = idle_n;

        end

    endcase

 end

 // send new LRU to be written
always_comb begin

    if(state ==idle_n && miss) begin

        unique case (index_hit)

        2'b00 : begin
            LRU_new = LRU_next & (3'b100);
        end

        2'b01 : begin
            LRU_new = {LRU_next[2], 2'b10};
        end
        2'b10 : begin
            LRU_new = {1'b0, LRU_next[1], 1'b1};
        end

        2'b11 : begin
            LRU_new = {1'b1, LRU_next[0], 1'b1};
        end
    endcase

    end
    unique case (index_hit)

        2'b00 : begin
            LRU_new = LRU_next & (3'b100);
        end

        2'b01 : begin
            LRU_new = {LRU_next[2], 2'b10};
        end
        2'b10 : begin
            LRU_new = {1'b0, LRU_next[1], 1'b1};
        end

        2'b11 : begin
            LRU_new = {1'b1, LRU_next[0], 1'b1};
        end
    endcase



end
 

 always_comb begin

    if(state == allocate) begin

        ufp_rdata = ufp_rdata_queue;
        ufp_resp = ufp_resp_queue;
        index_resp = index_queue;
        dmem_resp_type = dmem_resp_type_queue;

    end
    else begin

        ufp_rdata = ufp_rdata_hit; 
        ufp_resp = ufp_resp_hit;
        index_resp = index_immediate;
        dmem_resp_type = dmem_resp_type_hit;

    end


 end
 // decode the next index to be replaced 



logic [1:0] initial_index_replace;
always_comb begin

    index_replace = '0;
    index_replace_stall = '0;
    initial_index_replace = '0;

    unique case (LRU_next)

        3'b010, 3'b000 : begin
            initial_index_replace = 2'd3;
        end

        3'b110, 3'b100 : begin
            initial_index_replace = 2'd2;
        end

        3'b001, 3'b101 : begin
            initial_index_replace = 2'd1;
        end
        3'b011, 3'b111 : begin
            initial_index_replace = 2'd0;
        end

    endcase

    // add logic for searching through valid array and making index_replace go to entry that currently is not in queue if 

    if(!search_index_valid && mask_valid && state!=allocate && miss) begin

        index_replace_stall = '1;
        
    end
    index_replace = initial_index_replace;

end




/*

non-blocking aspect of cache


*/



logic write_en;

write_clean_queue write_clean_mem(

   .write_data( write_instruction), 
   .dfp_rdata(dfp_rdata), 
   .dfp_resp(dfp_resp),
   .write_en(write_en),
   .clk(clk),
   .rst(rst),
   .read_en(read_en),
   .read_data(write_instruction_read), 
   .queue_full(queue_full),
   .queue_empty(),
   .dfp_raddr(dfp_raddr),
   .dfp_addr(dfp_addr),
   .read_ack(read_ack), 
   .write_ack(write_ack),
   .dfp_write(dfp_write),
   .dfp_read(dfp_read),
   .search_valid(search_valid),
   .search_address(search_address),
   .stall(stall),
   .dcache_serviced(dcache_serviced),
   .dfp_wdata(dfp_wdata),
   .dfp_resp_write(dfp_resp_write),
   .initial_index_replace(initial_index_replace),
   .search_index_valid(search_index_valid),
   .data_dirty_hit(data_dirty_hit),
   .index_hit(index_hit),
   .write_hit(write_hit),
   .d_e(d_e),
   .is_idle(state==idle_n)

);


logic dirty_wdata;

logic [255:0] wmask_dirty;

always_comb begin 

    write_en = '0;
    write_instruction = '0;
  
    if(write_hit) begin
    //     write_instruction = '0;

    //     write_en = '1;
    //     write_instruction.bmem_addr = dfp_addr_stage;
    //     write_instruction.read_mask = '0;
    //     write_instruction.dmem_raddr = '0;
    //     write_instruction.index_replace = '0;
    //     write_instruction.valid = '0;
    //     write_instruction.tag = d_e.tag;
    //     write_instruction.dirty = '1;
    //     write_instruction.set = d_e.set_idx;

    //     // do the dirty data
        write_dirty = data[index_hit] & ~wmask_dirty;
        data_dirty_hit = write_dirty | (second_wdata);
    //     write_instruction.index = d_e.index;

    end
    if(write_queue_dirty) begin

        write_instruction = '0;
        write_en = '1;
        write_instruction.bmem_addr = {write_instruction_read.dirty_tag, write_instruction_read.set, 5'b00000};
        write_instruction.read_mask = '0;
        write_instruction.dmem_raddr = '0;
        write_instruction.index_replace = '0;
        write_instruction.valid = '0;
        write_instruction.tag = write_instruction_read.dirty_tag ;
        write_instruction.dirty = '1;
        write_instruction.write_data = write_instruction_read.dirty_data;
        write_instruction.set = write_instruction_read.set;
        write_instruction.index = d_e.index;
        write_instruction.read = '0;

    end
    else if (miss) begin

        write_instruction = '0;
        write_en = '1;
        write_instruction.bmem_addr = dfp_addr_stage;
        write_instruction.read_mask = d_e.read_mask;
        write_instruction.dmem_raddr = '0;
        write_instruction.index_replace = index_replace;
        write_instruction.valid = '0;
        write_instruction.write_mask = second_wmask;
        write_instruction.write_data = second_wdata;
        write_instruction.tag = d_e.tag;
        write_instruction.dirty = '0;
        write_instruction.offset = d_e.addr[4:2];
        write_instruction.set = d_e.set_idx;
        write_instruction.index = d_e.index;
        write_instruction.is_dirty = is_dirty;
        write_instruction.dirty_tag = tag_out[index_replace];
        write_instruction.dirty_data = data[index_replace];
        write_instruction.read = '0;
    end
end


logic write_ack_latch;


always_ff @(posedge clk) begin

    data_in_temp <= (rst) ? '0 : data_in;

end


assign wmask_temp = {{8{write_instruction_read.write_mask[31]}},{8{write_instruction_read.write_mask[30]}},{8{write_instruction_read.write_mask[29]}},{8{write_instruction_read.write_mask[28]}},{8{write_instruction_read.write_mask[27]}},{8{write_instruction_read.write_mask[26]}},{8{write_instruction_read.write_mask[25]}},{8{write_instruction_read.write_mask[24]}},{8{write_instruction_read.write_mask[23]}},{8{write_instruction_read.write_mask[22]}},{8{write_instruction_read.write_mask[21]}},{8{write_instruction_read.write_mask[20]}},{8{write_instruction_read.write_mask[19]}},{8{write_instruction_read.write_mask[18]}},{8{write_instruction_read.write_mask[17]}},{8{write_instruction_read.write_mask[16]}},{8{write_instruction_read.write_mask[15]}},{8{write_instruction_read.write_mask[14]}},{8{write_instruction_read.write_mask[13]}},{8{write_instruction_read.write_mask[12]}},{8{write_instruction_read.write_mask[11]}},{8{write_instruction_read.write_mask[10]}},{8{write_instruction_read.write_mask[9]}},{8{write_instruction_read.write_mask[8]}},{8{write_instruction_read.write_mask[7]}},{8{write_instruction_read.write_mask[6]}},{8{write_instruction_read.write_mask[5]}},{8{write_instruction_read.write_mask[4]}},{8{write_instruction_read.write_mask[3]}},{8{write_instruction_read.write_mask[2]}},{8{write_instruction_read.write_mask[1]}},{8{write_instruction_read.write_mask[0]}}};
assign wmask_dirty = {{8{second_wmask[31]}},{8{second_wmask[30]}},{8{second_wmask[29]}},{8{second_wmask[28]}},{8{second_wmask[27]}},{8{second_wmask[26]}},{8{second_wmask[25]}},{8{second_wmask[24]}},{8{second_wmask[23]}},{8{second_wmask[22]}},{8{second_wmask[21]}},{8{second_wmask[20]}},{8{second_wmask[19]}},{8{second_wmask[18]}},{8{second_wmask[17]}},{8{second_wmask[16]}},{8{second_wmask[15]}},{8{second_wmask[14]}},{8{second_wmask[13]}},{8{second_wmask[12]}},{8{second_wmask[11]}},{8{second_wmask[10]}},{8{second_wmask[9]}},{8{second_wmask[8]}},{8{second_wmask[7]}},{8{second_wmask[6]}},{8{second_wmask[5]}},{8{second_wmask[4]}},{8{second_wmask[3]}},{8{second_wmask[2]}},{8{second_wmask[1]}},{8{second_wmask[0]}}};












endmodule
