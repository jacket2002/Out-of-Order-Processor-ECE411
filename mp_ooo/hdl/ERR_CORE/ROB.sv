module ROB
import rv32i_types::*;
import params::*;
 #(
    parameter QUEUE_SIZE = 16
)
(

    input rob_entry_t write_data,
    input logic write_en,
    input logic clk,
    input logic rst,

    input logic flush_by_branch,
    input logic ROB_store_commit_flag,

    // input logic read_en,
    output rob_entry_t read_data,
    output logic queue_full, queue_empty,
    output logic read_ack, write_ack,
    output logic [ROB_PTR_WIDTH:0] ROB_write_ptr,
    output logic [ROB_PTR_WIDTH:0] ROB_read_ptr, // for L/S QUEUE

    // need extra logic to find and modify certain entry based on CDB, want to record rob_index in RS entry
    // output logic [63:0] order_of_latest,
    // output logic [63:0] order_of_oldest,
    // output logic [PHYSICAL_REG_WIDTH - 1:0] phys_rd_branch_sel, phys_rd_md_sel, phys_rd_alu_sel,
    // output logic [4:0]    logical_rd_branch, logical_rd_md, logical_rd_alu,
    // output logic [31:0]   phys_rd_branch_val, phys_rd_md_val, phys_rd_alu_val,
    // ROB and phys reg take valid from CDB

    input cdb_entry_t cdb_entry_md, cdb_entry_branch, cdb_entry_add, cdb_entry_mem,

    // rvfi
    output logic [ROB_PTR_WIDTH:0] rvfi_ROB_read_ptr
);

localparam tmp_size = QUEUE_SIZE;
localparam int size = $clog2(QUEUE_SIZE);

rob_entry_t mem [tmp_size];
logic [size:0] write_ptr, read_ptr;

// rob_entry_t read_data_next;
logic start, read_start;
logic read_en;

assign read_en = (mem[read_ptr[ROB_PTR_WIDTH-1:0]].ready_to_commit == '1) ? 1'b1 : 1'b0;

assign rvfi_ROB_read_ptr = read_ptr;

assign queue_full = ((write_ptr[size-1:0] == read_ptr[size-1:0])&&(write_ptr[size] != read_ptr[size])) ? '1 : '0; // makes sure read_ptr is more thanone away
assign queue_empty = (write_ptr == read_ptr) ? '1 : '0;
assign ROB_write_ptr = write_ptr;
assign ROB_read_ptr = read_ptr; 

// write ptr
always_ff @(posedge clk) begin

    if(rst) begin
        write_ptr <= '0;
    end
    else if (flush_by_branch) begin // at this cycle, cdb branch is valid
        write_ptr <= cdb_entry_branch.rob_idx + 1'b1; // this will set ROB to branch rob_idx + 1
    end
    else if(write_en&&!queue_full) begin
        write_ptr <= write_ptr + 1'b1;
    end
 
end

// read ptr
always_ff @(posedge clk) begin

    if(rst) begin
        read_ptr <= '0;
    end
    else if(read_en&&!queue_empty) begin
        read_ptr <= read_ptr + 1'b1;
    end
 
end

// setting read data
always_comb begin

    if(read_en && !queue_empty) begin
        // if(mem[read_ptr[size-1:0]].ready_to_commit) begin
            read_data = mem[read_ptr[size-1:0]];
            read_ack = '1;
        // end
        // else begin
        //     read_data = '0;
        //     read_ack = '0;
        // end
    end
    else begin

        read_data = '0;
        read_ack = '0;

    end

end

//writing data

logic [size-1:0] blank;
assign blank =write_ptr[size-1:0]; 

always_ff @(posedge clk) begin



    if(write_en && !queue_full) begin
        mem[write_ptr[size-1:0]] <= write_data;
        write_ack <= '1;

    end
    else begin
        write_ack <= '0;
        
    end

    if (cdb_entry_branch.valid) begin 
        mem[cdb_entry_branch.rob_idx[ROB_PTR_WIDTH-1:0]].ready_to_commit <= '1; 
        // mem[cdb_entry_branch.rob_idx[ROB_PTR_WIDTH-1:0]].br_en <= branch_en;
        // mem[cdb_entry_branch.rob_idx[ROB_PTR_WIDTH-1:0]].pc_target <= pc_target;
    end
    if (cdb_entry_md.valid) begin mem[cdb_entry_md.rob_idx[ROB_PTR_WIDTH-1:0]].ready_to_commit <= '1; end
    if (cdb_entry_add.valid) begin mem[cdb_entry_add.rob_idx[ROB_PTR_WIDTH-1:0]].ready_to_commit <= '1; end
    if (cdb_entry_mem.valid) begin mem[cdb_entry_mem.rob_idx[ROB_PTR_WIDTH-1:0]].ready_to_commit <= '1; end
    if (ROB_store_commit_flag) begin mem[read_ptr[ROB_PTR_WIDTH-1:0]].ready_to_commit <= '1; end
end

// always_comb begin
    
//     if (cdb_entry_branch.valid) begin 

//         phys_rd_branch_sel =  mem[cdb_entry_branch.rob_pointer].phys_d_reg;
//         phys_rd_branch_val = cdb_entry_branch.rd_v;
//         logical_rd_branch = mem[cdb_entry_branch.rob_pointer].arch_d_reg;

        

//     end
//     else begin

//         phys_rd_branch_sel =  '0;
//         phys_rd_branch_val = 'x;
//         logical_rd_branch='0;

//     end
//      if (cdb_entry_md.valid) begin

//         phys_rd_md_sel =  mem[cdb_entry_md.rob_pointer].phys_d_reg;
//         phys_rd_md_val = cdb_entry_md.rd_v;
//         logical_rd_md = mem[cdb_entry_md.rob_pointer].arch_d_reg;
        

//      end
//      else begin

//         phys_rd_md_sel =  '0;
//         phys_rd_md_val = 'x;
//         logical_rd_md='0;

//      end
//      if (cdb_entry_md.valid) begin

//         phys_rd_alu_sel =  mem[cdb_entry_alu.rob_pointer].phys_d_reg;
//         phys_rd_alu_val = cdb_entry_alu.rd_v;
//         logical_rd_alu = mem[cdb_entry_alu.rob_pointer].arch_d_reg;

//      end 
//      else begin

//         phys_rd_alu_sel = '0;
//         phys_rd_alu_val = 'x;
//         logical_rd_alu ='0;
        
//      end



// end


endmodule
