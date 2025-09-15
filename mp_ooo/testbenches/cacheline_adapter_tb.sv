import "DPI-C" function string getenv(input string env_name);
module top_tb;
    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, "+all");
    end

    bit clk;
    always #2ns clk = ~clk;
    int timeout = 10000;
    always @(posedge clk) begin
        if (timeout == 0) begin
            $error("TB Error: Timed out");
            $fatal;
        end
        timeout <= timeout - 1;
    end

    // cpu side output signals to cache
    logic [31:0] ufp_addr;
    logic [3:0] ufp_rmask, ufp_wmask;
    logic [32:0] ufp_wdata;

    // cpu side input signals from cache.
    logic [31:0] ufp_rdata;
    logic ufp_resp;

    // cache side output signals to adapter:
    logic [31:0] dfp_addr;
    logic dfp_read, dfp_write;
    logic [255:0] dfp_wdata;

    // cache side input signals from adapter:
    logic [255:0] dfp_rdata;
    logic [31:0] dfp_raddr;
    logic dfp_resp;

    // adapter side output signals to main memory:
    logic [31:0] main_mem_addr;
    logic main_mem_read, main_mem_write;
    logic [63:0] main_mem_wdata;

    // adapter side input signals from main memory:
    logic [63:0] main_mem_rdata;
    logic [31:0] main_mem_raddr;
    logic main_mem_rvalid;
    logic main_mem_ready;
    logic [1:0] adapter_write_count;

    bit rst;
    task generate_reset;
        begin
            rst = 1'b1;
            repeat (2) @(posedge clk);
            dfp_read <= '0;
            dfp_write <= '0;
            rst <= 1'b0;
        end
    endtask

    mem_itf_banked bmem_itf(.*);
    dram_w_burst_frfcfs_controller banked_memory(.itf(bmem_itf));

    cacheline_adapter dut(
        .clk(clk),
        .rst(rst),

        .addr(bmem_itf.addr),
        .read(bmem_itf.read),
        .write(bmem_itf.write),
        .wdata(bmem_itf.wdata),

        .ready(bmem_itf.ready),
        .raddr(bmem_itf.raddr),
        .rdata(bmem_itf.rdata),
        .rvalid(bmem_itf.rvalid),

        .* // dfp external inputs and outputs.
    );


    initial begin
        generate_reset();
        @(posedge clk);
        dfp_addr <= 'x;
        dfp_read <= '0;
        dfp_write <= '0;
        dfp_wdata <= 'x;
        #40ns;

        // @(posedge clk);
        // dfp_addr <= 32'h1eceb000;
        // dfp_read <= '0;
        // dfp_write <= '1;
        // dfp_wdata <= 256'hcafebabedeadbeefbeefbabecafedeadb0bacafe123456782345678934567890;

        // @ (posedge clk);
        // @ (posedge clk);
        // @ (posedge clk);
        // @ (posedge clk);
        // dfp_addr <= 'x;
        // dfp_write <= '0;

        // @(posedge clk);
        // dfp_addr <= 32'h2eceb000;
        // dfp_read <= '0;
        // dfp_write <= '1;
        // dfp_wdata <= 256'h1111111122222222333333334444444455555555666666667777777788888888;

        // @ (posedge clk);
        // @ (posedge clk);
        // @ (posedge clk);
        // @ (posedge clk);
        // dfp_addr <= 'x;
        // dfp_write <= '0;

        // @(posedge clk);
        // dfp_addr <= 32'h3eceb000;
        // dfp_read <= '0;
        // dfp_write <= '1;
        // dfp_wdata <= 256'h9999999900000000aaaaaaaabbbbbbbbccccccccddddddddeeeeeeeeffffffff;

        // @ (posedge clk);
        // @ (posedge clk);
        // @ (posedge clk);
        // @ (posedge clk);
        // dfp_addr <= 'x;
        // dfp_write <= '0;
        

        @ (posedge clk);
        dfp_read <= '1;
        dfp_write <= '0;
        dfp_wdata <= 'x;
        dfp_addr <= 32'h1eceb000;

        @ (posedge clk);
        dfp_addr <= 32'h1eceb020;
        
        @ (posedge clk);
        dfp_addr <= 32'h1eceb040;

        @ (posedge clk);
        dfp_addr <= 32'h1eceb060;

        @ (posedge clk);
        dfp_addr <= 32'h1eceb080;

        @ (posedge clk);
        dfp_addr <= 32'h1eceb0a0;

        @ (posedge clk);
        dfp_addr <= 32'h1eceb0c0;
        
        @ (posedge clk);
        dfp_addr <= 32'h1eceb0e0;

        @ (posedge clk);
        dfp_addr <= 32'h1eceb100;

        @ (posedge clk);
        dfp_addr <= 32'h1eceb120;

        @ (posedge clk);
        dfp_addr <= 32'h1eceb140;

        @ (posedge clk);
        dfp_addr <= 32'h1eceb160;

        @ (posedge clk);
        dfp_addr <= 32'h1eceb180;

        @ (posedge clk);
        dfp_addr <= 32'h1eceb1a0;

        @ (posedge clk);
        dfp_addr <= 32'h1eceb1c0;

        @ (posedge clk);
        dfp_addr <= 32'h1eceb1e0;

        @ (posedge clk);
        dfp_addr <= 32'h1eceb200;

        @ (posedge clk);
        dfp_addr <= 32'h1eceb220;

        @ (posedge clk);
        dfp_addr <= 32'h1eceb240;

        @ (posedge clk);
        dfp_addr <= 32'h1eceb260;

        @ (posedge clk);
        dfp_addr <= 32'h1eceb280;

        @ (posedge clk);
        dfp_addr <= 32'h1eceb2a0;

        @ (posedge clk);
        dfp_addr <= 32'h1eceb2c0;

        // @ (posedge clk);
        // dfp_addr <= 32'h1eceb2e0;

        // @ (posedge clk);
        // dfp_addr <= 32'h1eceb300;

        // @ (posedge clk);
        // dfp_addr <= 32'h1eceb320;

        // @ (posedge clk);
        // dfp_addr <= 32'h1eceb340;

        // @ (posedge clk);
        // dfp_addr <= 32'h1eceb360;

        // @ (posedge clk);
        // dfp_addr <= 32'h1eceb380;

        // @ (posedge clk);
        // dfp_addr <= 32'h1eceb3a0;

        // repeat (500) begin 
        //     @ (posedge clk);
        //     dfp_addr <= dfp_addr + 8'h20;
        // end


        @ (posedge clk);
        wait(bmem_itf.ready);
        
        @ (posedge clk);
        dfp_read <= '0;
        
        

        #1000ns;
        $finish;
    end

endmodule