module RAT
import rv32i_types::*;
import params::*;
#(

    parameter DATA_WIDTH = PHYSICAL_REG_FILE_LENGTH
)
(
    input logic clk,
    input logic rst,

    input  logic   flush_by_branch,
    input  logic [CONTROL_Q_PTR_WIDTH : 0]   control_read_ptr,

    //input from BRAT
    input  logic   [PHYSICAL_REG_FILE_LENGTH-1:0] RAT_internal_map_out [32],
    input  logic   [31:0] RAT_internal_valid_map_out,
    // outputs to BRAT
    output   logic   [PHYSICAL_REG_FILE_LENGTH-1:0] RAT_internal_map_in [32],
    output   logic   [31:0] RAT_internal_valid_map_in,

    // duplicated signal from RRF
    // input   logic   [PHYSICAL_REG_FILE_LENGTH-1:0]  rd_v,
    // input   logic   [4:0]   rd_s,

    input logic [4:0] rs1_arc, // both come from the decoder (architectural)
    input logic [4:0] rs2_arc,

    input logic [4:0] a_dest, // comes from the decoder (architectural)
    input logic [DATA_WIDTH-1:0] p_dest, // comes from whatever physical register got popped from the free list
    input logic free_list_read_ack, // this comes from the free list because when a value is popped from free list, meaning dest_reg has been renamed, update the mapping
    
    // input logic CDB_valid, // this comes from functional unit, when execution is finished, this will allow you to update the valid bit if the mapping remained the same. 

    // input logic [4:0] CDB_logical_d_reg, // these two will be set by the functional unit
    // input logic [DATA_WIDTH-1:0] CDB_phys_d_reg,
    input cdb_entry_t cdb_entry_md, cdb_entry_branch, cdb_entry_add, cdb_entry_mem,

    output logic [DATA_WIDTH-1:0] ps1,
    output logic [DATA_WIDTH-1:0] ps2,
    output logic ps1_valid, // these valids mean that the value of rs1 or rs2 can be found by its mapping to the RAT
    output logic ps2_valid
);

    logic [DATA_WIDTH-1:0] internal_map [32];
    logic [31:0] internal_valid_map;
    logic valid_add, valid_br, valid_md, valid_mem;

    assign valid_add = cdb_entry_add.valid;
    assign valid_br = cdb_entry_branch.valid;
    assign valid_md = cdb_entry_md.valid;
    assign valid_mem = cdb_entry_mem.valid;

    assign RAT_internal_map_in = internal_map;
    assign RAT_internal_valid_map_in = internal_valid_map;

    // internal map
    always_ff @ (posedge clk) begin
        if (rst) begin
            for (int i = 0; i < 32; i++) begin
                internal_map[i] <= '0;
            end
        end 
        else if (flush_by_branch) begin
            internal_map <= RAT_internal_map_out;
        end
        else
        begin
            if (free_list_read_ack && p_dest != '0 && a_dest!='0) begin // if free list item has been popped, update new logical <-> physical mapping
                internal_map[a_dest] <= p_dest;
            end
        end
    end

    // internal valid map
    always_ff @ (posedge clk) begin
        if (rst) begin
            internal_valid_map <= '1;
        end 
        else if (flush_by_branch) begin
            internal_valid_map <= RAT_internal_valid_map_out;
            if (valid_add) begin
                if (RAT_internal_map_out[cdb_entry_add.arch_d_reg] == cdb_entry_add.phys_d_reg && cdb_entry_add.control_bit_map[control_read_ptr[CONTROL_Q_PTR_WIDTH-1 : 0]] == 1'b0) begin
                    internal_valid_map[cdb_entry_add.arch_d_reg] <= '1;
                end
            end 

            if (valid_br) begin
                if (RAT_internal_map_out[cdb_entry_branch.arch_d_reg] == cdb_entry_branch.phys_d_reg && cdb_entry_branch.control_bit_map[control_read_ptr[CONTROL_Q_PTR_WIDTH-1 : 0]] == 1'b0) begin
                    internal_valid_map[cdb_entry_branch.arch_d_reg] <= '1;
                end
            end 

            if (valid_md) begin
                if (RAT_internal_map_out[cdb_entry_md.arch_d_reg] == cdb_entry_md.phys_d_reg && cdb_entry_md.control_bit_map[control_read_ptr[CONTROL_Q_PTR_WIDTH-1 : 0]] == 1'b0) begin
                    internal_valid_map[cdb_entry_md.arch_d_reg] <= '1;
                end
            end 

            if (valid_mem) begin
                if (RAT_internal_map_out[cdb_entry_mem.arch_d_reg] == cdb_entry_mem.phys_d_reg && cdb_entry_mem.control_bit_map[control_read_ptr[CONTROL_Q_PTR_WIDTH-1 : 0]] == 1'b0) begin
                    internal_valid_map[cdb_entry_mem.arch_d_reg] <= '1;
                end
            end
        end
        else begin

            if (valid_add) begin
                if (internal_map[cdb_entry_add.arch_d_reg] == cdb_entry_add.phys_d_reg) begin
                    internal_valid_map[cdb_entry_add.arch_d_reg] <= '1;
                end
            end 

            if (valid_br) begin
                if (internal_map[cdb_entry_branch.arch_d_reg] == cdb_entry_branch.phys_d_reg) begin
                    internal_valid_map[cdb_entry_branch.arch_d_reg] <= '1;
                end
            end 

            if (valid_md) begin
                if (internal_map[cdb_entry_md.arch_d_reg] == cdb_entry_md.phys_d_reg) begin
                    internal_valid_map[cdb_entry_md.arch_d_reg] <= '1;
                end
            end 

            if (valid_mem) begin
                if (internal_map[cdb_entry_mem.arch_d_reg] == cdb_entry_mem.phys_d_reg) begin
                    internal_valid_map[cdb_entry_mem.arch_d_reg] <= '1;
                end
            end

            if (free_list_read_ack && a_dest != '0) begin // if free list item has been popped, update this entry to not valid (i.e. busy)
                internal_valid_map[a_dest] <= '0;
            end 
        end
    end

    always_comb begin
        ps1_valid = internal_valid_map[rs1_arc];
        ps2_valid = internal_valid_map[rs2_arc];

        if (valid_add && internal_map[cdb_entry_add.arch_d_reg] == cdb_entry_add.phys_d_reg && cdb_entry_add.arch_d_reg == rs1_arc) 
            ps1_valid = '1;
        if (valid_br && internal_map[cdb_entry_branch.arch_d_reg] == cdb_entry_branch.phys_d_reg && cdb_entry_branch.arch_d_reg == rs1_arc)
            ps1_valid = '1;
        if (valid_md && internal_map[cdb_entry_md.arch_d_reg] == cdb_entry_md.phys_d_reg && cdb_entry_md.arch_d_reg == rs1_arc)
            ps1_valid = '1;
        if (valid_mem && internal_map[cdb_entry_mem.arch_d_reg] == cdb_entry_mem.phys_d_reg && cdb_entry_mem.arch_d_reg == rs1_arc)
            ps1_valid = '1;
        
        if (valid_add && internal_map[cdb_entry_add.arch_d_reg] == cdb_entry_add.phys_d_reg && cdb_entry_add.arch_d_reg == rs2_arc) 
            ps2_valid = '1;
        if (valid_br && internal_map[cdb_entry_branch.arch_d_reg] == cdb_entry_branch.phys_d_reg && cdb_entry_branch.arch_d_reg == rs2_arc)
            ps2_valid = '1;
        if (valid_md && internal_map[cdb_entry_md.arch_d_reg] == cdb_entry_md.phys_d_reg && cdb_entry_md.arch_d_reg == rs2_arc)
            ps2_valid = '1;
        if (valid_mem && internal_map[cdb_entry_mem.arch_d_reg] == cdb_entry_mem.phys_d_reg && cdb_entry_mem.arch_d_reg == rs2_arc)
            ps2_valid = '1;
        
    end

    always_comb begin
        // ps1 = (free_list_read_ack && p_dest != '0 && a_dest!='0 && a_dest == rs1_arc)? p_dest : internal_map[rs1_arc];
        // ps2 = (free_list_read_ack && p_dest != '0 && a_dest!='0 && a_dest == rs2_arc)? p_dest : internal_map[rs2_arc];
        // ps1 = (free_list_read_ack && p_dest != '0 && a_dest!='0 )? p_dest : internal_map[rs1_arc];
        // ps2 = (free_list_read_ack && p_dest != '0 && a_dest!='0 )? p_dest : internal_map[rs2_arc];
        ps1 = internal_map[rs1_arc];
        ps2 = internal_map[rs2_arc];
    end



endmodule : RAT
