import "DPI-C" function string getenv(input string env_name);
module top_tb;
    timeunit 1ps;
    timeprecision 1ps;

    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, "+all");
    end

    int timeout = 10000000;
    int clock_half_period_ps;
    initial begin
        $value$plusargs("CLOCK_PERIOD_PS_ECE411=%d", clock_half_period_ps);
        clock_half_period_ps = clock_half_period_ps / 2;
    end

    bit clk;
    always #(clock_half_period_ps) clk = ~clk;

    bit rst;
    task generate_reset;
        begin
            rst = 1'b1;
            repeat (2) @(posedge clk);
            rst <= 1'b0;
        end
    endtask

    mem_itf_banked bmem_itf(.*);
    mon_itf #(.CHANNELS(8)) mon_itf(
        .*
    );

    // random_tb random_tb(.itf(bmem_itf)); // For randomized testing
    dram_w_burst_frfcfs_controller banked_memory(.itf(bmem_itf));
    monitor #(.CHANNELS(8)) monitor(.itf(mon_itf));

    cpu dut(
        .clk(clk),
        .rst(rst),

        .bmem_ready(bmem_itf.ready),
        .bmem_raddr(bmem_itf.raddr),
        .bmem_rdata(bmem_itf.rdata),
        .bmem_rvalid(bmem_itf.rvalid),

        .bmem_addr(bmem_itf.addr),
        .bmem_read(bmem_itf.read),
        .bmem_write(bmem_itf.write),
        .bmem_wdata(bmem_itf.wdata)
    );

    `include "../../hvl/common/rvfi_reference.svh"

    always @(posedge clk) begin
        if (mon_itf.halt[0]) begin
            $finish;
        end
        if (timeout == 0) begin
            $error("TB Error: Timed out");
            $fatal;
        end
        // if (bmem_itf.error != 0 || mon_itf.error != 0) begin
        //     repeat (2) @(posedge clk);
        //     $fatal;
        // end
        timeout <= timeout - 1;
    end

    initial begin
        generate_reset();
        // @(posedge clk);

        // #10000ns;
        // $finish;
    end

endmodule