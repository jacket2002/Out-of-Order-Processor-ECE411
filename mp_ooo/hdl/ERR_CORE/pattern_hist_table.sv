module pattern_hist_table #(
            parameter               S_INDEX     = 4,
            parameter               WIDTH       = 2
)(
    input   logic                   clk0,
    input   logic                   rst0,
    input   logic   [S_INDEX-1:0]   addr0,
    output  logic   [WIDTH-1:0]     dout0,
    input   logic                   web1,
    input   logic   [S_INDEX-1:0]   addr1,
    input   logic   [WIDTH-1:0]     din1
);

            localparam              NUM_SETS    = 2**S_INDEX;
            logic   [WIDTH-1:0]     internal_array [NUM_SETS];

    always_ff @(posedge clk0) begin
        if (rst0) begin
            for (int i = 0; i < NUM_SETS; i++) begin
                internal_array[i] <= '0;
            end
        end else begin
            if (!web1) begin
                internal_array[addr1] <= din1;
            end
        end
    end

    always_comb begin
        dout0 = (!web1 && (addr0 == addr1)) ? din1 : internal_array[addr0];
    end

endmodule : pattern_hist_table

