module cache 
import ppl_cache_types::*;
(
    input   logic           clk,
    input   logic           rst,

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

/*

basically we have upward facing port from cpu
this port acts as the way to get a value and then if it is cache miss you
go to the downward facing port and then get the value from memory 

so take ufp data send through cache logic and if miss then send through to the dfp


also for write allocate when we miss and go to main memory we will bring block into cache

Also is a write back cache so when line replaced we will send lines to be written in main memory, maybe could add flag if said line has been written to...
if flag is added then we dont write every time a line is replaced fixing when a line is never used 


this flag is having dirty miss versus clean miss, if we have a clean miss swap lines if dirty stall, update memory and then update the current state 


additionally there is going to be a valid bit which simply states if the cache line isn't filled or is invalidated 
valid flag ensures tags aren't compared when they shouldn't be 

*/


/*

pipelining the cache,

first cycle:

I think the first cycle we need to figure out if it's a hit or a miss and updating LRU entrys, LRU synchronized so just get new data ready to be taken on clock edge 


If it's a hit then update LRU so the one to replace is more clear

second cycle:

we have hit so we either need to write data in cache, flag dirty or read data and send back to cpu

if it's miss we have to read/write from main mem and also replace line based on replacement decision from LRU for the adjacent set 

if replacement is dirty we also must write back data to main memory so there will be recognition for htis and will stall pipeline and wait for memory to repsond

that has been written to 

*/

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

assign dirty_temp = tag_out[index_replace];
assign is_dirty = is_valid[index_replace] ? dirty_temp[23] : '0;



dec_exec d_e, d_e_next;
logic hit;





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


cache_decode cache_decode(
    .*
);



// below is indexing for data arrays
// because of set associative we have to referemce a module

logic [255:0] data_no_shift, second_wdata;
logic [31:0] write_no_shift, read_no_shift, second_wmask;

logic [31:0] mask_shift_val;
logic [31:0] write_shift_val;


assign data_no_shift = {224'b0, d_e.wd_small};
assign write_no_shift = {28'b0, d_e.small_w};
assign mask_shift_val = d_e.addr[4:2]*4;
assign write_shift_val = d_e.addr[4:2] *32;

assign second_wmask = write_no_shift << (mask_shift_val);
assign second_wdata = data_no_shift << (write_shift_val);


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


    // assigns for the arrays





// two things to do, update and replace 
// one tied to stage one and one tied to stage 2

logic [3:0] read_lru_set;

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
        .addr1      (d_e.set),
        .din1       (LRU_new),
        .dout1      (dummy)
    );

   

// below is execute stage 

logic [3:0] hit_ways;
 


 logic [31:0] indexed_data;

 logic [31:0] exact_bytes;
 logic [31:0] dfp_exact_bytes;
 logic [31:0] ufp_rdata_next;
 logic [31:0] dfp_addr_stage;



 state_types state;
 state_types next_state;

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
logic [255:0] temp, temp1;
 assign temp = (data[index_hit]>>(32*d_e.addr[4:2]));
 assign temp1 = (dfp_rdata>>(32*d_e.addr[4:2]));
 assign indexed_data = temp[31:0];
 assign dfp_exact_bytes = temp1[31:0];




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




// dont assume dirty after miss carry some bit somehow or something
// 
logic mask_valid;

assign mask_valid = d_e.read_mask != 4'b0000 || d_e.small_w != 4'b0000;

logic write_non_dirty, write_non_dirty_next;
always_ff @(posedge clk) begin

    write_non_dirty <= write_non_dirty_next;

end

logic [23:0] addr_temp;
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

        current_set[0] = d_e_next.set;
        current_set[3] = d_e_next.set;
        current_set[2] = d_e_next.set;
        current_set[1] = d_e_next.set;

    read_lru_set = d_e_next.set;

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
       


    unique case (state)



        idle: begin
          
            data_in = second_wdata;
            tag_in[index_replace] = {1'b1,d_e.tag};
      
            ufp_resp = '0;
            dfp_read = '0;
            write_stall = '0;
            read_stall = '0;
            write_non_dirty_next = '1;

            dfp_addr = 'x;
            write_stall = '1;
            dfp_write = '0;
            ufp_resp = '0;
            dfp_read = '0;




            if(mask_valid) begin

                if(hit) begin

                    write_stall = '0;
                    LRU_write = '0;
                    ufp_rdata = indexed_data;
                    ufp_resp = '1;

                end
                else begin
                  
                  dfp_addr = dfp_addr_stage;
                  dfp_read = '1;
                  next_state = miss;
                  read_stall = '1;
                  current_set[index_replace] = d_e.set;
                  read_lru_set = d_e.set;
                        
                end
            end
            else begin

                next_state = idle;
            
            end
            
        end

        
        miss: begin

            dfp_read = '1;
            dfp_addr = dfp_addr_stage;
            read_stall = '1;
            current_set[index_replace] = d_e.set;
            read_lru_set = d_e.set;
            tag_in[index_replace] = {1'b0, d_e.tag};

            if(dfp_resp) begin
             
                data_write[index_replace] = '0;
                tag_write[index_replace] = '0;
                write_mask[index_replace] = '1;
                data_in = dfp_rdata;
                current_set[index_replace] = d_e.set;
                read_lru_set = d_e.set;
                chip_select[index_replace] = '0;
                write_stall = '1;
                ufp_rdata_next = (d_e.write_enable) ? dfp_exact_bytes : 'x;
                next_state = done;
        
            end
            else begin
                next_state = miss;
            end
        end

        done : begin

            write_stall = '1;
            tag_in[index_replace] = {1'b0, d_e.tag};
            current_set[3] = d_e.set;
            current_set[2] = d_e.set;
            current_set[1] = d_e.set;
            current_set[0] = d_e.set;
            read_lru_set = d_e.set;
            dfp_addr = 'x;
            read_stall = '0;
            dfp_read = '0;
            v ='1;
            tag_write[index_hit] = '1;
            next_state = idle;
            write_non_dirty_next = '0;


        end


        default : begin
            next_state = idle;

        end

    endcase
 end





 
always_ff @(posedge clk) begin

    if(rst) begin
        state <= idle;
    end
    else begin
        state<= next_state;
    end

end







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
