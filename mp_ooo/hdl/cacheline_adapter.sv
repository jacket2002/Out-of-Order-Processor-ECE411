module cacheline_adapter
import rv32i_types::*;
(
    input   logic               clk,
    input   logic               rst,

    // burst mem side
    output  logic   [31:0]     addr,
    output  logic              read,
    output  logic              write,
    output  logic   [63:0]     wdata, 
    input   logic              ready,
    input   logic   [31:0]     raddr,
    input   logic   [63:0]     rdata, 
    input   logic              rvalid,
    
    // cache side
    input   logic   [31:0]  dfp_addr,
    input   logic           dfp_read,
    input   logic           dfp_write,
    input   logic   [255:0] dfp_wdata,

    output  logic   [255:0] dfp_rdata, 
    output  logic   [31:0]  dfp_raddr,

    // output  logic   [1:0]   adapter_write_count,
    // output  logic           dfp_ready,
    output  logic           dfp_resp
);

    logic [1:0] rvalid_count, write_count;
    logic [191:0] rdata_buffer;
    logic read_0;

    logic send_read_request_on_ready;

    always_ff @(posedge clk) begin
        if (rst) send_read_request_on_ready <= '0;
        else begin
            if (read_0 && ready) send_read_request_on_ready <= '1;
            // next cycle after resp, able to get next read request
            else if (rvalid_count == 2'b11) send_read_request_on_ready <= '0;
        end
    end

    assign read_0 = send_read_request_on_ready? '0: dfp_read;
    assign addr = send_read_request_on_ready? 'x: dfp_addr;
    assign read = read_0;
    // These part can be done in cache module with logic 'ready' from burst mem

    // always_ff @(posedge clk) begin
    //     if (rst) shadow_addr <= '0;
    //     else begin 
    //         if (ready)  shadow_addr <= dfp_addr;
    //         else shadow_addr <= shadow_addr;
    //     end 
    // end

    // always_ff @(posedge clk) begin
    //     if (rst) ready_reg <= '0;
    //     else begin 
    //         ready_reg <= ready;
    //     end 
    // end

    // always_comb begin
    //     if (ready_reg) addr <= dfp_addr;
    //     else addr <= shadow_addr;
    // end

    always_ff @(posedge clk) begin
        if (rst) begin rvalid_count <= '0; rdata_buffer <= '0; end
        else begin 
            if (rvalid)  begin 
                
                if (rvalid_count != 2'b11) begin rvalid_count <= rvalid_count + 1'b1; rdata_buffer[rvalid_count * 64 +: 64] <= rdata; end
                else rvalid_count <= '0;
            end
        end 
    end

    always_comb begin
        if (rvalid_count == 2'b11) begin
            dfp_resp = '1;
            dfp_rdata = {rdata,rdata_buffer[191:0]};
            dfp_raddr = raddr;
        end
        // when giving request before getting response, the logic here will be incorrect
        // Possibly write happens at the same time as rvalid?
        else if (write_count == 2'b11 && ready) begin
            dfp_resp = '1;
            dfp_rdata = 'x;
            dfp_raddr = 'x;
        end
        else begin
            dfp_resp = '0;
            dfp_rdata = 'x;
            dfp_raddr = 'x;
        end
    end

    // Cache hold write request for four ready cycle, read request for one ready cycle
    always_ff @(posedge clk) begin
        if (rst) write_count <= '0;
        else begin 
            if (dfp_write & ready)  begin 
                if (write_count != 2'b11) begin write_count <= write_count + 1'b1; end
                else write_count <= '0;
            end
        end 
    end

    always_comb begin
        wdata = dfp_wdata[write_count * 64 +: 64];
        write = dfp_write;
    end

    // assign adapter_write_count = write_count;


endmodule : cacheline_adapter
