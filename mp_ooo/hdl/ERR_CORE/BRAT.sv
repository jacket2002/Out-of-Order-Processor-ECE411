module BRAT
import rv32i_types::*;
import params::*;
#(
    parameter QUEUE_SIZE = CONTROL_Q_DEPTH
)
(
    input logic clk,
    input logic rst,

    input   logic   flush_by_branch,  // same as rst here
    // input   logic   [CONTROL_Q_DEPTH-1:0] control_bit_map,  

    input   logic   write_en, // this should be control_inst_checkpoint from decode, only write once, so should be combined with stall logic
    input   logic   read_en, // this should be branch_rosolved from br_fu

    input   logic   [FREE_LIST_PTR_WIDTH : 0] free_list_rd_ptr_in,  // three write_data
    input   logic   [PHYSICAL_REG_FILE_LENGTH-1:0] RAT_internal_map_in [32],
    input   logic   [31:0] RAT_internal_valid_map_in,

    input   logic [4:0] a_dest, // comes from the decoder (architectural)
    input   logic [PHYSICAL_REG_FILE_LENGTH-1:0] p_dest, // comes from whatever physical register got popped from the free list
    input   logic free_list_read_ack, // this comes from the free list because when a value is popped from free list, meaning dest_reg has been renamed, update the mapping
    
    input   cdb_entry_t     cdb_entry_md, cdb_entry_branch, cdb_entry_add, cdb_entry_mem,

    output   logic   [FREE_LIST_PTR_WIDTH : 0] free_list_rd_ptr_out,  // three write_data
    output   logic   [PHYSICAL_REG_FILE_LENGTH-1:0] RAT_internal_map_out [32],
    output   logic   [31:0] RAT_internal_valid_map_out,

    // output  logic read_ack, write_ack,
    output  logic queue_full , queue_empty

);

    localparam tmp_size = QUEUE_SIZE;
    localparam int size = $clog2(QUEUE_SIZE);

    logic [size:0] write_ptr, read_ptr;

    logic [PHYSICAL_REG_FILE_LENGTH-1:0] copy_internal_map [CONTROL_Q_DEPTH] [32];
    logic [31:0] copy_internal_valid_map [CONTROL_Q_DEPTH];
    logic [FREE_LIST_PTR_WIDTH : 0] copy_free_list_rd_ptr [CONTROL_Q_DEPTH];

    logic valid_add, valid_br, valid_md, valid_mem;

    assign queue_full = ((write_ptr[size-1:0] == read_ptr[size-1:0])&&(write_ptr[size] != read_ptr[size])) ? '1 : '0; // makes sure read_ptr is more thanone away
    assign queue_empty = (write_ptr == read_ptr) ? '1 : '0;

    assign valid_add = cdb_entry_add.valid;
    assign valid_br = cdb_entry_branch.valid;
    assign valid_md = cdb_entry_md.valid;
    assign valid_mem = cdb_entry_mem.valid;

    
    // write ptr
    always_ff @(posedge clk) begin

        if(rst|flush_by_branch) begin
            write_ptr <= '0;
        end
        else if(write_en&&!queue_full) begin
            write_ptr <= write_ptr + 1'b1;
        end
    end

    // read ptr
    always_ff @(posedge clk) begin

        if(rst|flush_by_branch) begin
            read_ptr <= '0;
        end
        else if(read_en&&!queue_empty) begin
            read_ptr <= read_ptr + 1'b1;
        end
    
    end

    // copy internal map, copy at the time when control_inst_checkpoint is high
    // if there is an ongoing writing at copy time (jal, jalr), do the same write as RAT
    always_ff @ (posedge clk) begin
        if(write_en && !queue_full) begin
            copy_internal_map[write_ptr[size-1:0]] <= RAT_internal_map_in;
            if (free_list_read_ack && p_dest != '0 && a_dest!='0) begin // if free list item has been popped, update new logical <-> physical mapping
                copy_internal_map[write_ptr[size-1:0]][a_dest] <= p_dest;
            end
        end
    end

    // copy free list pointer when control_inst_checkpoint is high
    // if free list read ack is also high, add 1 on copied value
    always_ff @ (posedge clk) begin
        if(write_en && !queue_full) begin
            if (free_list_read_ack) copy_free_list_rd_ptr[write_ptr[size-1:0]] <= free_list_rd_ptr_in + 1'b1;
            else copy_free_list_rd_ptr[write_ptr[size-1:0]] <= free_list_rd_ptr_in;
        end
    end

    // copy internal valid map
    // should be updated if the bit_map indicate the result is given by instruction comming before certain branch
    always_ff @ (posedge clk) begin

        for (int i = 0; i < QUEUE_SIZE; i++) begin
            if (valid_add) begin
                if (copy_internal_map[i][cdb_entry_add.arch_d_reg] == cdb_entry_add.phys_d_reg && cdb_entry_add.control_bit_map[i] == 1'b0) begin
                    copy_internal_valid_map[i][cdb_entry_add.arch_d_reg] <= '1;
                end
            end 

            if (valid_br) begin
                if (copy_internal_map[i][cdb_entry_branch.arch_d_reg] == cdb_entry_branch.phys_d_reg && cdb_entry_branch.control_bit_map[i] == 1'b0) begin
                    copy_internal_valid_map[i][cdb_entry_branch.arch_d_reg] <= '1;
                end
            end 

            if (valid_md) begin
                if (copy_internal_map[i][cdb_entry_md.arch_d_reg] == cdb_entry_md.phys_d_reg && cdb_entry_md.control_bit_map[i] == 1'b0) begin
                    copy_internal_valid_map[i][cdb_entry_md.arch_d_reg] <= '1;
                end
            end 

            if (valid_mem) begin
                if (copy_internal_map[i][cdb_entry_mem.arch_d_reg] == cdb_entry_mem.phys_d_reg && cdb_entry_mem.control_bit_map[i] == 1'b0) begin
                    copy_internal_valid_map[i][cdb_entry_mem.arch_d_reg] <= '1;
                end
            end
        end
        
        if(write_en && !queue_full) begin
            copy_internal_valid_map[write_ptr[size-1:0]] <= RAT_internal_valid_map_in;

            if (valid_add) begin
                if (RAT_internal_map_in[cdb_entry_add.arch_d_reg] == cdb_entry_add.phys_d_reg) begin
                    copy_internal_valid_map[write_ptr[size-1:0]][cdb_entry_add.arch_d_reg] <= '1;
                end
            end 

            if (valid_br) begin
                if (RAT_internal_map_in[cdb_entry_branch.arch_d_reg] == cdb_entry_branch.phys_d_reg) begin
                    copy_internal_valid_map[write_ptr[size-1:0]][cdb_entry_branch.arch_d_reg] <= '1;
                end
            end 

            if (valid_md) begin
                if (RAT_internal_map_in[cdb_entry_md.arch_d_reg] == cdb_entry_md.phys_d_reg) begin
                    copy_internal_valid_map[write_ptr[size-1:0]][cdb_entry_md.arch_d_reg] <= '1;
                end
            end 

            if (valid_mem) begin
                if (RAT_internal_map_in[cdb_entry_mem.arch_d_reg] == cdb_entry_mem.phys_d_reg) begin
                    copy_internal_valid_map[write_ptr[size-1:0]][cdb_entry_mem.arch_d_reg] <= '1;
                end
            end

        end
    end

    // setting read data
    always_comb begin

        if(read_en && !queue_empty) begin
            free_list_rd_ptr_out = copy_free_list_rd_ptr[read_ptr[size-1:0]];
            RAT_internal_map_out = copy_internal_map[read_ptr[size-1:0]];
            RAT_internal_valid_map_out = copy_internal_valid_map[read_ptr[size-1:0]];
        end
        else begin
            free_list_rd_ptr_out = 'x;
            for (int i = 0; i < 32; i++) begin
                RAT_internal_map_out[i] = 'x;
            end
            RAT_internal_valid_map_out = 'x;
        end

    end



endmodule : BRAT
