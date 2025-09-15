module cache_arbiter
import rv32i_types::*;
// arbiter between cache and adapter
(
    input   logic               clk,
    input   logic               rst,

    // take two set of signals from iCache dCache, choose one set send to adapter
    input   logic   [31:0]  imem_dfp_addr,
    input   logic           imem_dfp_read,
    // input   logic           imem_dfp_write,
    // input   logic   [255:0] imem_dfp_wdata,

    input   logic   [31:0]  dmem_dfp_addr,
    input   logic           dmem_dfp_read,
    input   logic           dmem_dfp_write,
    input   logic   [255:0] dmem_dfp_wdata,

    output   logic   [31:0]  dfp_addr,
    output   logic           dfp_read,
    output   logic           dfp_write,
    output   logic   [255:0] dfp_wdata,

    // signal from adapter, give to cache
    input  logic   [255:0] dfp_rdata, 
    input  logic   [31:0]  dfp_raddr,
    // input  logic   [1:0]   adapter_write_count,
    input  logic           dfp_resp,

    input   logic           bmem_ready,

    output  logic   [255:0] imem_dfp_rdata, 
    output  logic   [31:0]  imem_dfp_raddr,
    output  logic           imem_dfp_resp, 

    output  logic   [255:0] dmem_dfp_rdata, 
    output  logic   [31:0]  dmem_dfp_raddr,
    output  logic           dmem_dfp_resp,
    output  logic           dcache_serviced,
    output  logic          imem_dfp_read_after,
    input   logic          dfp_resp_write
);

Arbiter_state state, next_state;
logic request_i, request_d, icache_serviced;
assign request_i = imem_dfp_read;
assign request_d = dmem_dfp_write || dmem_dfp_read;


always_ff @(posedge clk) begin

    if(rst) begin
        state <= idle_arbiter;
    end
    else begin
        state<= next_state;
    end
    imem_dfp_read_after <= (imem_dfp_read_after) ? !imem_dfp_resp: icache_serviced;


end

always_comb begin  
    dfp_addr = 'x;
    dfp_read = 'x;
    dfp_write = 'x;
    dfp_wdata = 'x;
    next_state = idle_arbiter;
    dcache_serviced = '0;
    icache_serviced = '0;
    
    unique case (state)
    
        idle_arbiter: begin
            dfp_addr = 'x;
            dfp_read = '0;
            dfp_write = '0;
            dfp_wdata = 'x;
            next_state = idle_arbiter;
            if (request_i) begin
                dfp_addr = imem_dfp_addr;
                dfp_read = imem_dfp_read;
                dfp_write = '0;
                next_state = idle_arbiter;
                icache_serviced = bmem_ready;
            end
            else if (request_d) begin
                dfp_addr = dmem_dfp_addr;
                dfp_read = dmem_dfp_read;
                dfp_write = dmem_dfp_write;
                dfp_wdata = dmem_dfp_wdata;
                dcache_serviced = bmem_ready;
                next_state = (dmem_dfp_write) ? serving_dcache : idle_arbiter;
            end 
        end

        serving_dcache: begin
            dfp_addr = dmem_dfp_addr;
            dfp_read = dmem_dfp_read;
            dfp_write = dmem_dfp_write;
            dfp_wdata = dmem_dfp_wdata;
            next_state = serving_dcache;
            dcache_serviced = bmem_ready;
            
            if (dfp_resp_write) begin
               next_state = idle_arbiter;
            end
        end

        default: begin end

    endcase

end

always_comb begin
    imem_dfp_rdata = 'x;
    imem_dfp_raddr = 'x;
    imem_dfp_resp = '0;  

    dmem_dfp_rdata = 'x;
    dmem_dfp_raddr = 'x;
    dmem_dfp_resp = '0;  

    if(dfp_resp) begin


        if((imem_dfp_addr == dfp_raddr) && imem_dfp_read_after) begin
             imem_dfp_rdata = dfp_rdata;
             imem_dfp_raddr = dfp_raddr;
             imem_dfp_resp = '1;
        end
        else begin
            dmem_dfp_rdata = dfp_rdata;
            dmem_dfp_raddr = dfp_raddr;
            dmem_dfp_resp = '1;
        end

    end
end




endmodule
