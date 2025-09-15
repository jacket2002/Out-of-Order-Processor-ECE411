module ppl_cache 
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
    input   logic           dfp_resp
);

logic [255:0] data [3:0];
logic [255:0] data_in;
logic [23:0] tag_in [3:0];
logic [23:0] tag_out [3:0];
logic tag_write [3:0];
logic data_write [3:0];
logic chip_select [3:0];
logic is_valid [3:0];
logic is_dirty;
logic [3:0] current_set [3:0];
logic [1:0] index_hit;   
logic [31:0] write_mask [3:0];
logic write_stall;
logic we_have_data_to_write;
logic read_stall;
logic [2:0] LRU_next;
logic [2:0] LRU_new, dummy;
logic [1:0] index_replace;
logic LRU_access, LRU_write;
logic line_replaced;
logic v;
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
logic [31:0] ufp_rdata_next;
logic [31:0] dfp_addr_stage;
logic hit;
logic [255:0] temp, temp1;
logic mask_valid;
logic write_non_dirty, write_non_dirty_next;
logic [23:0] addr_temp;
dec_exec d_e, d_e_next;
state_types state;
state_types next_state, prev_state;

// below is pipeline registers updating d_e refrencing the decode/execute stage 

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
        state <= idle;
    end
    else begin
        state<= next_state;
    end
    prev_state <= state;

 end

 assign mask_valid = d_e.read_mask != 4'b0000 || d_e.small_w != 4'b0000;
 assign temp = (data[index_hit]>>(32*d_e.addr[4:2]));
 assign temp1 = (dfp_rdata>>(32*d_e.addr[4:2]));
 assign indexed_data = temp[31:0];
 assign dfp_exact_bytes = temp1[31:0];
 assign dirty_temp = tag_out[index_replace];
 assign is_dirty = is_valid[index_replace] ? dirty_temp[23] : '0;
 assign dfp_addr_stage = {d_e.addr[31:5], 5'b0};
 assign hit_ways = {is_valid[0]&&(tag_out[0][22:0] == d_e.tag), is_valid[1]&&(tag_out[1][22:0] == d_e.tag), is_valid[2]&&(tag_out[2][22:0] == d_e.tag),is_valid[3]&&(tag_out[3][22:0] == d_e.tag)};
 assign hit = is_valid[0]&&(tag_out[0][22:0] == d_e.tag) || is_valid[1]&&(tag_out[1][22:0] == d_e.tag) || is_valid[2]&&(tag_out[2][22:0] == d_e.tag) || is_valid[3]&&(tag_out[3][22:0] == d_e.tag);
 
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
        ufp_rdata_next = 'x;

    unique case (state)

        idle: begin
        
            data_in = second_wdata;
            tag_in[index_replace] = {1'b1,d_e.tag};
            dfp_write = '0;
            ufp_resp = '0;
            dfp_read = '0;
            write_stall = '0;
            read_stall = '0;
            write_non_dirty_next = '1;
            dfp_addr = 'x;
          
            if(mask_valid) begin
                if(hit) begin
                    if(d_e.write_enable) begin

                        write_stall = '0;
                        LRU_write = '0;
                        ufp_rdata = indexed_data;
                        ufp_resp = '1;
                        
                    end
                    else begin

                        LRU_write = '0;
                        data_in = second_wdata;
                        write_mask[index_hit] = second_wmask;
                        data_write[index_hit] = '0;
                        tag_write[index_hit] = '0;
                        current_set[index_hit] = d_e.set_idx;
                        read_lru_set = d_e.set_idx;
                        tag_in[index_hit] = {1'b1,d_e.tag};
                        chip_select[index_hit] = '0;
                        write_stall = '0;
                        ufp_resp = '1;
                        next_state = idle_d_a;
                        write_non_dirty_next = '1;

                    end
                end
                else begin

                    if(is_dirty) begin

                        addr_temp = tag_out[index_replace];
                        dfp_addr = {addr_temp[22:0], d_e.set_idx, 5'b0};
                        dfp_wdata = data[index_replace];
                        dfp_write = '1;
                        next_state = dirty;
                        read_stall = '1;
                        tag_write[index_replace] = '0;
                        tag_in[index_replace] = tag_out[index_replace];
                        current_set[index_replace] = d_e.set_idx;
                        read_lru_set = d_e.set_idx;
                        v = '0;
                        // updat valid and re write

                    end
                    else begin
                        dfp_addr = dfp_addr_stage;
                        dfp_read = '1;
                        // if (ready) begin next_state = miss; end
                        // else begin next_state = miss_hold_req; end
                        next_state = miss;
                        read_stall = '1;
                        current_set[index_replace] = d_e.set_idx;
                        read_lru_set = d_e.set_idx;
                        
                    end
                end
            end
            else begin
                next_state = idle;
                write_stall = '0;
            end
          
        end

        // miss_hold_req: begin 
        //     ufp_resp = '0;
        //     dfp_read = '1;
        //     dfp_addr = dfp_addr_stage;
        //     read_stall = '1;
                    
        //     current_set[index_replace] = d_e.set_idx;
        //     read_lru_set = d_e.set_idx;
        //     tag_in[index_replace] = {1'b0, d_e.tag};
        // end
        
        miss: begin

            ufp_resp = '0;
            dfp_read = '1;
            read_stall = '1;
            dfp_addr = dfp_addr_stage;
            current_set[index_replace] = d_e.set_idx;
            read_lru_set = d_e.set_idx;
            tag_in[index_replace] = {1'b0, d_e.tag};

            if(dfp_resp) begin
                data_write[index_replace] = '0;
                tag_write[index_replace] = '0;
                write_mask[index_replace] = '1;
                data_in = dfp_rdata;
                current_set[index_replace] = d_e.set_idx;
                read_lru_set = d_e.set_idx;
                chip_select[index_replace] = '0;
                write_stall = '1;
                ufp_rdata_next = (d_e.write_enable) ? dfp_exact_bytes : 'x;
                next_state = idle_d_a;
            end
            else begin
                next_state = miss;
            end

        end
        dirty: begin

            ufp_resp = '0;
            current_set[index_replace] = d_e.set_idx;
            addr_temp = tag_out[index_replace];
            read_lru_set = d_e.set_idx;
            read_stall = '1;
            dfp_wdata = data[index_replace];
            dfp_addr = {addr_temp[22:0], d_e.set_idx, 5'b0};
            dfp_write = '1;
            if(dfp_resp) begin
                next_state = idle;
                current_set[0]= d_e.set_idx;
                current_set[1] = d_e.set_idx;
                current_set[2] = d_e.set_idx;
                current_set[3] = d_e.set_idx;
              
            end
            else begin
                next_state = dirty;
            end

        end

        idle_d_a : begin
            next_state = idle;
            data_in = second_wdata;
            tag_in[index_replace] = {1'b1,d_e.tag};
            dfp_write = '0;
            ufp_resp = '0;
            dfp_read = '0;
            write_stall = '1;
            read_stall = '0;
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

        default : begin

            next_state = idle;

        end

    endcase

 end

 // send new LRU to be written
always_comb begin
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
            LRU_new = {1'b1, LRU_next[1], 1'b1};
        end
    endcase

end
 
 // decode the next index to be replaced 
always_comb begin

    unique case (LRU_next)

        3'b010, 3'b000 : begin
            index_replace = 2'd3;
        end

        3'b110, 3'b100 : begin
            index_replace = 2'd2;
        end

        3'b001, 3'b101 : begin
            index_replace = 2'd1;
        end
        3'b011, 3'b111 : begin
            index_replace = 2'd0;
        end

    endcase

end

endmodule
