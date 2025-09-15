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
    logic read_ack, write_ack;

    fifo #(
        .DATA_WIDTH(32), 
        .QUEUE_SIZE(8)) dut(.*);

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

    task test_full;
        begin
            repeat(2) begin
                for (int i=0; i<40; i++) begin
                    @(posedge clk);
                    if (!queue_full) begin
                        write_data <= (i%2 == 0)? $urandom : write_data;
                        write_en <= (i%2 == 0)? 1'b1 : 1'b0;
                        golden_queue.push_back(write_data);
                    end
                end
                #50;
            end
        end
    endtask;

    task test_write2_read2_write16;
        begin
            for (int i=0; i<40; i++) begin
                @(posedge clk);
                read_en <= 1'b0;
                if (!queue_full) begin
                    write_data <= (i%2 == 0)? $urandom : write_data;
                    write_en <= (i%2 == 0)? 1'b1 : 1'b0;
                end
            end
            // #50ns;
        end
        begin
            for (int i=0; i<4; i++) begin
                @(posedge clk);
                if (!queue_empty) begin
                    // write_data <= (i%2 == 0)? $urandom : write_data;
                    read_en <= (i%2 == 0)? 1'b1 : 1'b0;
                end
            end
            // #50ns;
        end
        begin
            for (int i=0; i<40; i++) begin
                @(posedge clk);
                if (!queue_full) begin
                    write_data <= (i%2 == 0)? $urandom : write_data;
                    write_en <= (i%2 == 0)? 1'b1 : 1'b0;
                end
            end
        end
        begin
            for (int i=0; i<40; i++) begin
                @(posedge clk);
                if (!queue_empty) begin
                    read_en <= (i%2 == 0)? 1'b1 : 1'b0;
                end
            end
            #50;
        end
    endtask

    initial begin
        generate_reset();
        @ (posedge clk);
        test_write2_read2_write16();
        // test_full();
        $finish;
    end

endmodule : top_tb