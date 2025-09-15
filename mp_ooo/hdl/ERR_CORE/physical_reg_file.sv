module physical_reg_file
import rv32i_types::*;
import params::*;
(
    input   logic           clk,
    input   logic           rst,
    input   logic           regf_we_alu, regf_we_mul, regf_we_br, regf_we_mem,
    input   logic   [31:0]  rd_v_alu, rd_v_mul, rd_v_br, rd_v_mem,
    input   logic   [PHYSICAL_REG_WIDTH - 1:0]   rs1_alu, rs2_alu, rd_alu, rs1_mul, rs2_mul, rd_mul, rs1_br, rs2_br, rd_br, rs1_mem, rs2_mem, rd_mem,
    output  logic   [31:0]  rs1_v_alu, rs2_v_alu, rs1_v_mul, rs2_v_mul, rs1_v_br, rs2_v_br, rs1_v_mem, rs2_v_mem
);
//  use unique port for every RS
            logic   [31:0]  data [PHYSICAL_REG_NUM];

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < PHYSICAL_REG_NUM; i++) begin
                data[i] <= '0;
            end
        end else  begin // We want to reserve p0 and p1, p0 always 0, p1 represent immediate value? or do nothing
            if (regf_we_alu && (rd_alu != '0)) data[rd_alu] <= rd_v_alu;
            if (regf_we_mul && (rd_mul != '0)) data[rd_mul] <= rd_v_mul;
            if (regf_we_br && (rd_br != '0)) data[rd_br] <= rd_v_br;
            if (regf_we_mem && (rd_mem != '0)) data[rd_mem] <= rd_v_mem;
        end
    end

    always_comb begin
        rs1_v_alu = (rs1_alu != '0) ? data[rs1_alu] : '0;
        rs2_v_alu = (rs2_alu != '0) ? data[rs2_alu] : '0;
        rs1_v_mul = (rs1_mul != '0) ? data[rs1_mul] : '0;
        rs2_v_mul = (rs2_mul != '0) ? data[rs2_mul] : '0;
        rs1_v_br = (rs1_br != '0) ? data[rs1_br] : '0;
        rs2_v_br = (rs2_br != '0) ? data[rs2_br] : '0;
        rs1_v_mem = (rs1_mem != '0) ? data[rs1_mem] : '0;
        rs2_v_mem = (rs2_mem != '0) ? data[rs2_mem] : '0;
    end

endmodule : physical_reg_file
