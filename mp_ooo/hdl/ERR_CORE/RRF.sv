module RRF
import rv32i_types::*;
import params::*;
(
    input   logic           clk,
    input   logic           rst,
    input   logic           we,  // basically going to be ROB commit
    input   logic   [PHYSICAL_REG_FILE_LENGTH-1:0]  rd_v,
    input   logic   [4:0]   rd_s,

    output  logic   [PHYSICAL_REG_FILE_LENGTH-1:0]  rrf_data [32],
    output  logic   [PHYSICAL_REG_FILE_LENGTH-1:0]  rs1_v // goes into the freelist. 
);




logic   [PHYSICAL_REG_FILE_LENGTH-1:0]  data [32];

assign rrf_data = data;

 always_ff @(posedge clk) begin
    if (rst) begin
        for (int unsigned i = 0; i < 32; i++) begin
            data[i] <= PHYSICAL_REG_FILE_LENGTH'(i);
            // data[i] <= i;
        end
    end else if (we && (rd_s != 5'd0)) begin 
        data[rd_s] <= rd_v;
    end
end

always_comb begin
    rs1_v = (rd_s != 5'd0) ? data[rd_s] : '0;
    // rs2_v = (rs2_s != 5'd0) ? data[rs2_s] : '0;
end






















endmodule 
