// import "DPI-C" function string getenv(input string env_name);

module top_tb_top;

    timeunit 1ps;
    timeprecision 1ps;

    int clock_half_period_ps = getenv("ECE411_CLOCK_PERIOD_PS").atoi() / 2;

    bit clk;
    always #(clock_half_period_ps) clk = ~clk;

    bit rst;

    int timeout = 10000000; // in cycles, change according to your needs

    // mem_itf_banked bmem_itf(.*);
    // banked_memory banked_memory(.itf(bmem_itf));

    // mon_itf #(.CHANNELS(8)) mon_itf(.*);
    // monitor #(.CHANNELS(8)) monitor(.itf(mon_itf));

    // cpu dut(
    //     .clk            (clk),
    //     .rst            (rst),

    //     .bmem_addr  (bmem_itf.addr  ),
    //     .bmem_read  (bmem_itf.read  ),
    //     .bmem_write (bmem_itf.write ),
    //     .bmem_wdata (bmem_itf.wdata ),
    //     .bmem_ready (bmem_itf.ready ),
    //     .bmem_raddr (bmem_itf.raddr ),
    //     .bmem_rdata (bmem_itf.rdata ),
    //     .bmem_rvalid(bmem_itf.rvalid)
    // );

    `include "rvfi_reference.svh"

    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, "+all");
        rst = 1'b1;
        repeat (2) @(posedge clk);
        rst <= 1'b0;
    end

    logic [31:0] write_data;
    logic write_en;

    logic read_en;
    logic [31:0] read_data;
    logic queue_full, queue_empty;

    fifo fifo_inst(.*);

    logic [31:0] golden_queue[$], rdata;

    // always @(posedge clk) begin
    //     for (int unsigned i=0; i < 8; ++i) begin
    //         if (mon_itf.halt[i]) begin
    //             $finish;
    //         end
    //     end
    //     if (timeout == 0) begin
    //         $error("TB Error: Timed out");
    //         $finish;
    //     end
    //     if (mon_itf.error != 0) begin
    //         repeat (5) @(posedge clk);
    //         $finish;
    //     end
    //     if (bmem_itf.error != 0) begin
    //         repeat (5) @(posedge clk);
    //         $finish;
    //     end
    //     timeout <= timeout - 1;
    // end

    initial begin
        repeat(2) begin
            for (int i=0; i<10; i++) begin
                @(posedge clk);
                write_en <= (i%2 == 0)? 1'b1 : 1'b0;
                if (write_en & !queue_full) begin
                    write_data <= $urandom;
                    golden_queue.push_back(write_data);
                end
            end
            #50;
        end
    end

    // initial begin
    //     repeat(2) begin
    //     for (int i=0; i<10; i++) begin
    //         @(posedge clk);
    //         read_en <= (i%2 == 0)? 1'b1 : 1'b0;
    //         if (read_en & !queue_empty) begin
    //         #1;
    //         rdata <= golden_queue.pop_front();
    //         if(read_data !== rdata) $error("Time = %0t: Comparison Failed: expected wr_data = %h, rd_data = %h", $time, write_data, rdata);
    //         else $display("Time = %0t: Comparison Passed: wr_data = %h and rd_data = %h",$time, rdata, read_data);
    //         end
    //     end
    //     #50;
    // end

    $finish;

endmodule
