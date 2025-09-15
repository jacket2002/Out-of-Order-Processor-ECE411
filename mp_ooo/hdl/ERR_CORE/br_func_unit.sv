module br_func_unit
import rv32i_types::*;
import params::*;
 
(

    input logic [31:0] pc, imm, rs1_v, rs2_v,

    input branch_f3_t cmp_op,

    input  logic jalr_inst,  // is it jalr

    // input logic branch,  // is it branch
  
    // input logic cmp_alu,  // is this slt
    input logic use_imm_in_compare, // we need this use imm in compare because only SLTI uses immediate value for comparison. 

    output logic cmp, // cmp result

    output logic [31:0] add // ALU_result for auipc


);

logic [31:0] cmp_a, cmp_b, jalr_special;
logic br_en;

assign cmp_a = rs1_v;
assign cmp_b = rs2_v;



// instantiate functional units


logic unsigned [31:0] cmp_au, cmp_bu;
logic signed [31:0] cmp_as, cmp_bs;


assign cmp_au = unsigned'(cmp_a);
assign cmp_as = signed'(cmp_a);
assign cmp_bu = (use_imm_in_compare) ? unsigned'(imm) : unsigned'(cmp_b);
assign cmp_bs = (use_imm_in_compare) ? signed'(imm) : signed'(cmp_b);

always_comb begin
        unique case (cmp_op)
            branch_f3_beq : br_en = (cmp_au == cmp_bu);
            branch_f3_bne : br_en = (cmp_au != cmp_bu);
            branch_f3_blt : br_en = (cmp_as <  cmp_bs);
            branch_f3_bge : br_en = (cmp_as >=  cmp_bs);
            branch_f3_bltu: br_en = (cmp_au <  cmp_bu);
            branch_f3_bgeu: br_en = (cmp_au >=  cmp_bu);
            default       : br_en = 1'bx;
        endcase
    end


assign jalr_special = rs1_v+imm;

always_comb begin 

    add = (jalr_inst) ? (jalr_special & 32'hfffffffe) : imm+pc; // pc target
    cmp =  br_en; // branch enable. 
    // cmp = br_en;

end






























endmodule
