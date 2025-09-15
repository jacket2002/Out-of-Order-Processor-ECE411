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

    output  logic   [255:0] imem_dfp_rdata, 
    output  logic   [31:0]  imem_dfp_raddr,
    output  logic           imem_dfp_resp, 

    output  logic   [255:0] dmem_dfp_rdata, 
    output  logic   [31:0]  dmem_dfp_raddr,
    output  logic           dmem_dfp_resp
);

Arbiter_state state, next_state;
logic request_i, request_d;
logic latched_request_i;

logic begin_fetch_nextline;
logic fetch_nextline_sig, stop_fetch_nextline_sig, invalidate_nextline_buffer;
logic [31:0] nextline_addr;

logic valid_nextline_buffer;
logic [255:0] nextline_buffer;
logic [31:0] nextline_buffer_addr;

assign request_i = imem_dfp_read;
assign request_d = dmem_dfp_write || dmem_dfp_read;

always_ff @(posedge clk) begin

    if(rst) begin
        latched_request_i <= '0;
    end
    else begin
        latched_request_i<= request_i;
    end

end

always_ff @(posedge clk) begin

    if(rst) begin
        state <= idle_arbiter;
    end
    else begin
        state<= next_state;
    end

end

always_ff @(posedge clk) begin

    if(rst) begin
        begin_fetch_nextline <= '0;
        nextline_addr <= 'x;
    end
    else begin
        if (fetch_nextline_sig) begin
            begin_fetch_nextline <= '1;
            nextline_addr <= imem_dfp_addr + 'd32;
        end
        else if (stop_fetch_nextline_sig) begin_fetch_nextline <= '0;
    end
end

always_ff @(posedge clk) begin

    if(rst) begin
        valid_nextline_buffer <= '0;
        nextline_buffer <= 'x;
        nextline_buffer_addr <= 'x;
    end
    else begin
        if (stop_fetch_nextline_sig) begin
            valid_nextline_buffer <= '1;
            nextline_buffer <= dfp_rdata;
            nextline_buffer_addr <= dfp_raddr;
        end
        else if (invalidate_nextline_buffer) valid_nextline_buffer <= '0;
    end
end

always_comb begin  
    dfp_addr = 'x;
    dfp_read = 'x;
    dfp_write = 'x;
    dfp_wdata = 'x;
    imem_dfp_rdata = 'x;
    imem_dfp_raddr = 'x;
    imem_dfp_resp = '0;  

    dmem_dfp_rdata = 'x;
    dmem_dfp_raddr = 'x;
    dmem_dfp_resp = '0;  
    next_state = idle_arbiter;
    fetch_nextline_sig = '0;
    stop_fetch_nextline_sig = '0;
    invalidate_nextline_buffer = '0;
    
    unique case (state)
    
        idle_arbiter: begin
            dfp_addr = 'x;
            dfp_read = '0;
            dfp_write = '0;
            dfp_wdata = 'x;
            next_state = idle_arbiter;
            if (request_i && !(valid_nextline_buffer && imem_dfp_addr[31:5] == nextline_buffer_addr[31:5])) begin
                dfp_addr = imem_dfp_addr;
                dfp_read = imem_dfp_read;
                dfp_write = '0;
                next_state = serving_icache;
            end
            else if (request_d) begin
                dfp_addr = dmem_dfp_addr;
                dfp_read = dmem_dfp_read;
                dfp_write = dmem_dfp_write;
                dfp_wdata = dmem_dfp_wdata;
                next_state = serving_dcache;
            end 
            else if (begin_fetch_nextline) begin
                dfp_addr = nextline_addr;
                dfp_read = '1;
                dfp_write = '0;
                next_state = fetching_nextline;
            end
        end

        serving_icache: begin
            dfp_addr = imem_dfp_addr;
            dfp_read = imem_dfp_read;
            dfp_write = '0;
            next_state = serving_icache;
            if (dfp_resp) begin
                fetch_nextline_sig = '1;
                imem_dfp_rdata = dfp_rdata;
                imem_dfp_raddr = dfp_raddr;
                imem_dfp_resp = '1;
                next_state = idle_arbiter;
                if (request_d) begin
                    next_state = serving_dcache;
                end
            end
        end

        serving_dcache: begin
            dfp_addr = dmem_dfp_addr;
            dfp_read = dmem_dfp_read;
            dfp_write = dmem_dfp_write;
            dfp_wdata = dmem_dfp_wdata;
            next_state = serving_dcache;
            if (dfp_resp) begin
                dmem_dfp_rdata = dfp_rdata;
                dmem_dfp_raddr = dfp_raddr;
                dmem_dfp_resp = '1;
                next_state = idle_arbiter;
                if (request_i && !(valid_nextline_buffer && imem_dfp_addr[31:5] == nextline_buffer_addr[31:5])) begin
                    next_state = serving_icache;
                end
            end
        end

        fetching_nextline: begin
            dfp_addr = nextline_addr;
            dfp_read = '1;
            dfp_write = '0;
            next_state = fetching_nextline;
            if (dfp_resp) begin
                // imem_dfp_rdata = dfp_rdata;
                // imem_dfp_raddr = dfp_raddr;
                // imem_dfp_resp = '1;
                stop_fetch_nextline_sig = '1;
                next_state = idle_arbiter;
            end
        end

        // nextline_hit: begin
        //     dfp_read = '0;
        //     dfp_write = '0;
        //     imem_dfp_rdata = nextline_buffer;
        //     imem_dfp_raddr = imem_dfp_addr;
        //     imem_dfp_resp = '1;
        //     next_state = idle_arbiter;
        //     fetch_nextline_sig = '1;
        //     invalidate_nextline_buffer = '1;
        // end

        default: begin end

    endcase

    if (request_i && latched_request_i && valid_nextline_buffer && imem_dfp_addr[31:5] == nextline_buffer_addr[31:5]) begin
        imem_dfp_rdata = nextline_buffer;
        imem_dfp_raddr = imem_dfp_addr;
        imem_dfp_resp = '1;
        fetch_nextline_sig = '1;
        invalidate_nextline_buffer = '1;
    end

end


endmodule
