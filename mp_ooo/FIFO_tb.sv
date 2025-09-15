module top_tb;
    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, "+all");
    end

    bit clk = '0;
    always #2ns clk = ~clk;

    logic [31:0] write_data;
    logic write_en;

    logic read_en;
    logic [31:0] read_data;
    logic queue_full, queue_empty;

    fifo #(
        .DATA_WIDTH(32), 
        .QUEUE_SIZE(16)) dut(.*);

    logic [31:0] golden_queue[$], rdata;

    bit rst;
    task generate_reset;
        begin
            rst = 1'b1;
            repeat (2) @(posedge clk);
            write_en <= '0;
            read_en <= '0;
            rst <= 1'b0;
        end
    endtask

    initial begin
        generate_reset();
        @ (posedge clk);
        repeat(2) begin
            for (int i=0; i<40; i++) begin
                @(posedge clk);
                write_en <= (i%2 == 0)? 1'b1 : 1'b0;
                if (write_en && !queue_full) begin
                    write_data <= $urandom;
                    golden_queue.push_back(write_data);
                end
            end
            #50;
        end
        $finish;
    end

    // initial begin
    //     generate_reset();
    //     repeat(2) begin
    //         for (int i=0; i<30; i++) begin
    //             @(posedge clk);
    //             read_en <= (i%2 == 0)? 1'b1 : 1'b0;
    //             if (read_en && !queue_empty) begin
    //             // #1;
    //             rdata <= golden_queue.pop_front();
    //             #1;
    //             if((read_data !== rdata)) $error("Time = %0t: Comparison Failed: expected wr_data = %h, rd_data = %h", $time, write_data, rdata);
    //             else $display("Time = %0t: Comparison Passed: wr_data = %h and rd_data = %h",$time, rdata, read_data);
    //             end
    //         end
    //         #50;
    //     end

    //     $finish;
    // end

endmodule : top_tb