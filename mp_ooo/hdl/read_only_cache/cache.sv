module cache_read
import rv32i_types::*;
(
    input   logic           clk,
    input   logic           rst,

    // cpu side signals, ufp -> upward facing port
    input   logic   [31:0]  ufp_addr,
    input   logic   [3:0]   ufp_rmask,
    input   logic   [3:0]   ufp_wmask,
    input   logic   [31:0]  ufp_wdata,

    output  logic   [31:0]  ufp_rdata,
    output  logic           ufp_resp,


    // memory side signals, dfp -> downward facing port
    output  logic   [31:0]  dfp_addr,
    output  logic           dfp_read,
    output  logic           dfp_write,
    input   logic   [255:0] dfp_rdata,
    output  logic   [255:0] dfp_wdata,
    input   logic           dfp_resp,
    input logic             icache_serviced
);

logic [255:0] data [1:0];
logic [255:0] data_in;
logic [23:0] tag_in [1:0];
logic [23:0] tag_out [1:0];
logic tag_write [1:0];
logic data_write [1:0];
logic chip_select [1:0];
logic is_valid [1:0];
logic is_dirty;
logic [3:0] current_set [1:0];
logic index_hit;   
logic [31:0] write_mask [1:0];
logic write_stall;
logic we_have_data_to_write;
logic read_stall;
logic [15:0] mem;

logic line_replaced;
logic v;
logic [23:0] dirty_temp;
logic hit;
logic [255:0] data_no_shift, second_wdata;
logic [31:0] write_no_shift, read_no_shift, second_wmask;
logic [31:0] mask_shift_val;
logic [31:0] write_shift_val;
logic [3:0] read_lru_set;
logic [1:0] hit_ways;
logic [31:0] indexed_data;
logic [31:0] exact_bytes;
logic [31:0] dfp_exact_bytes;
logic [31:0] ufp_rdata_next;
logic [31:0] dfp_addr_stage;
logic [255:0] temp, temp1;
logic mask_valid;
logic write_non_dirty, write_non_dirty_next;
logic [23:0] addr_temp;
dec_exec d_e, d_e_next;
state_types state;
state_types next_state;


// register staging between decode and execute
always_ff @(posedge clk) begin

    if(rst) begin
        d_e <='0;
    end
    else if(write_stall || read_stall)begin
        d_e <=d_e;
    end
    else begin
        d_e<=d_e_next;
    end
end

// below is decode
cache_decode_read cache_decode(
    .*
);

assign data_no_shift = {224'b0, d_e.wd_small};
assign write_no_shift = {28'b0, d_e.small_w};
assign mask_shift_val = d_e.addr[4:2]*4;
assign write_shift_val = d_e.addr[4:2] *32;

assign second_wmask = write_no_shift << (mask_shift_val);
assign second_wdata = data_no_shift << (write_shift_val);

// below are our arrays with related info

    generate for (genvar i = 0; i < 2; i++) begin : arrays
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
        valid_array valid_array (
            .clk0       (clk),
            .rst0       (rst),
            .csb0       (chip_select[i]),
            .web0       (tag_write[i]),
            .addr0      (current_set[i]),
            .din0       (v),
            .dout0      (is_valid[i])
        );
   
    end endgenerate

   

// below is execute stage 
 


 always_ff @(posedge clk) begin

    if(rst) begin
        state <= idle;
    end
    else begin
        state<= next_state;
    end

end

 assign temp = (data[index_hit]>>(32*d_e.addr[4:2]));
 assign temp1 = (dfp_rdata>>(32*d_e.addr[4:2]));
 assign indexed_data = temp[31:0];
 assign dfp_exact_bytes = temp1[31:0];
 assign dirty_temp = tag_out[mem[d_e.set_idx]];
 assign is_dirty = is_valid[mem[d_e.set_idx]] ? dirty_temp[23] : '0;
 assign dfp_addr_stage = {d_e.addr[31:5], 5'b0};
 assign hit_ways = {is_valid[0]&&(tag_out[0][22:0] == d_e.tag), is_valid[1]&&(tag_out[1][22:0] == d_e.tag)};
 assign hit = is_valid[0]&&(tag_out[0][22:0] == d_e.tag) || is_valid[1]&&(tag_out[1][22:0] == d_e.tag);

 always_comb begin

   
     if (hit_ways[1]) begin
        index_hit = 1'd0;
    end
    else if (hit_ways[0]) begin
        index_hit = 1'd1;
    end
    else begin
        index_hit = 'x;
    end

 end

 


// dont assume dirty after miss carry some bit somehow or something
// 


assign mask_valid = d_e.read_mask != 4'b0000 || d_e.small_w != 4'b0000;


always_ff @(posedge clk) begin

    write_non_dirty <= write_non_dirty_next;

end


 always_comb begin

        v = '1;
        data_write[0] = '1;
        data_write[1] = '1;
    
        write_mask[0] = '0;
        write_mask[1] = '0;

        chip_select[0] = '0;
        chip_select[1] = '0;

        current_set[0] = d_e_next.set_idx;
        current_set[1] = d_e_next.set_idx;

        read_lru_set = d_e_next.set_idx;

        tag_write[0] = '1;
        tag_write[1] = '1;

        tag_in[0] = '0;
        tag_in[1] = '0;

        data_in = 'x;
        ufp_resp = '0;
        write_stall = '0;
        read_stall = '0;
        ufp_rdata = 'x;
        dfp_write = '0;
        dfp_read = '0;
        dfp_addr = 'x;
        dfp_wdata = 'x;
        addr_temp = 'x;
        write_non_dirty_next = '1;
        next_state = idle;

    unique case (state)

        idle: begin
          
            data_in = second_wdata;
            tag_in[mem[d_e.set_idx]] = {1'b1,d_e.tag};
            ufp_resp = '0;
            dfp_read = '0;
            write_stall = '0;
            read_stall = '0;
            write_non_dirty_next = '1;
            dfp_addr = 'x;
            dfp_write = '0;
            ufp_resp = '0;
            dfp_read = '0;

            if(mask_valid) begin
                if(hit) begin
                    write_stall = '0;
            
                    ufp_rdata = indexed_data;
                    ufp_resp = '1;
                end
                else begin
                  dfp_addr = dfp_addr_stage;
                  dfp_read = '1;
                  next_state = miss;
                  read_stall = '1;
                  current_set[mem[d_e.set_idx]] = d_e.set_idx;
                  read_lru_set = d_e.set_idx;
                end
            end
            else begin
                next_state = idle;
            
            end
            
        end

        miss: begin

            dfp_read = !icache_serviced;
            dfp_addr = dfp_addr_stage;
            read_stall = '1;
            current_set[mem[d_e.set_idx]] = d_e.set_idx;
            read_lru_set = d_e.set_idx;
            tag_in[mem[d_e.set_idx]] = {1'b0, d_e.tag};

            if(dfp_resp) begin
             
                data_write[mem[d_e.set_idx]] = '0;
                tag_write[mem[d_e.set_idx]] = '0;
                write_mask[mem[d_e.set_idx]] = '1;
                data_in = dfp_rdata;
                current_set[mem[d_e.set_idx]] = d_e.set_idx;
                read_lru_set = d_e.set_idx;
                chip_select[mem[d_e.set_idx]] = '0;
                write_stall = '1;
                ufp_rdata_next = (d_e.write_enable) ? dfp_exact_bytes : 'x;
                next_state = idle_d_a;
        
            end
            else begin
                next_state = miss;
            end
        end

       

        idle_d_a : begin
            next_state = idle;
            data_in = second_wdata;
            tag_in[mem[d_e.set_idx]] = {1'b1,d_e.tag};
            dfp_write = '0;
            ufp_resp = '0;
            dfp_read = '0;
            write_stall = '1;
            read_stall = '0;
            write_non_dirty_next = '1;
            if(d_e.read_mask != 4'b0000 || d_e.small_w!= 4'b0000) begin
              
                current_set[1] = d_e.set_idx;
                current_set[0] = d_e.set_idx;
                read_lru_set = d_e.set_idx;
                chip_select[0] = '0;
                chip_select[1] = '0;
               
            end
            else begin
                write_stall = '0;
                current_set[0] = d_e_next.set_idx;

                current_set[1] = d_e_next.set_idx;
                read_lru_set = d_e_next.set_idx;
                chip_select[0] = '0;
                chip_select[1] = '0;
           
            end
        end
        

        default : begin
            next_state = idle;

        end
        

    endcase
 end




always_ff @(posedge clk) begin

    if (rst) begin

        for(int i = 0; i<16; i++) begin
            mem[i] <= '0;
        end
    end
    else begin
    if(hit && state==idle && mask_valid) begin

        mem[current_set[index_hit]] <= !index_hit;
    end
    end


end


endmodule
