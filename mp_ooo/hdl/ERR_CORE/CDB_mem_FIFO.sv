// module CDB_mem
// import rv32i_types::*;
// import params::*;
// #(
//     QUEUE_SIZE = MEM_QUEUE_DEPTH
// )
// (
//     input logic clk,
//     input logic rst, 

//     input  logic   flush_by_branch, 

//     input logic write_en, // mem_write from dispatch. 
//     input mem_rs_entry_t load_store_queue_entry, // w_data

//     input   cdb_entry_t     cdb_entry_mult, 
//     input   cdb_entry_t     cdb_entry_br,
//     input   cdb_entry_t     cdb_entry_add,

//     input  logic [ROB_PTR_WIDTH:0] ROB_read_ptr,
//     output cdb_entry_t cdb_entry_mem_out, 
//     output logic queue_full, queue_empty,

//     output  logic [PHYSICAL_REG_WIDTH - 1:0] rs1_mem, //outputs into Phys Reg File (we don't need rs2)
//     output  logic [PHYSICAL_REG_WIDTH - 1:0] rs2_mem,
//     input   logic   [31:0]  rs1_v_mem, 
//     input   logic   [31:0]  rs2_v_mem,


//     // DCache signals
//     // inputs from D cache
//     // input logic [31:0] dmem_raddr, // not needed for now because we force in order memory requests.
//     input logic [31:0] dmem_rdata,
//     input logic dmem_resp,
//     // outputs into D Cache
//     output logic [31:0] dmem_addr, dmem_wdata,
//     output logic [3:0] dmem_wmask, dmem_rmask,
    
//     // rvfi signals
//     output logic [31:0] rvfi_rs1_rdata_mem, rvfi_rs2_rdata_mem,
//     output logic [31:0] rvfi_rd_wdata_mem, 
//     output logic [ROB_PTR_WIDTH:0] rvfi_issue_execute_rob_ptr_mem, 
//     output logic rvfi_inst_finished_mem,
//     output logic [3:0] rvfi_mem_wmask, rvfi_mem_rmask,
//     output logic [31:0] rvfi_mem_addr, rvfi_mem_rdata, rvfi_mem_wdata
// );

//     localparam tmp_size = QUEUE_SIZE;
//     localparam int size = $clog2(QUEUE_SIZE);

//     mem_rs_entry_t mem [tmp_size];

//     logic [MEM_QUEUE_PTR_WIDTH:0] write_ptr, read_ptr;

    

//     logic read_en; // pop when request is initiated. 

//     assign queue_full = ((write_ptr[size-1:0] == read_ptr[size-1:0])&&(write_ptr[size] != read_ptr[size])) ? '1 : '0; // makes sure read_ptr is more thanone away
//     assign queue_empty = (write_ptr == read_ptr) ? '1 : '0;

//     assign rs1_mem = mem[read_ptr[size-1:0]].phys_r1;
//     assign rs2_mem = mem[read_ptr[size-1:0]].phys_r2;

//     logic [3:0] mem_rmask_reg, mem_rmask;
//     logic [3:0] mem_wmask_reg, mem_wmask; 
//     logic [ROB_PTR_WIDTH:0] CDB_rob_reg;
//     logic [4:0] CDB_arch_reg;
//     logic [PHYSICAL_REG_FILE_LENGTH-1:0] CDB_phys_reg;
//     logic dmem_stall;
//     assign dmem_stall = (!dmem_resp && !(mem_wmask_reg == '0 && mem_rmask_reg == '0)) ? 1'b1 : 1'b0;
//     logic load_store_reg;
//     load_f3_t load_f3_reg; 
//     logic [1:0] addr_bottom_bits; // needed for load to shift data correctly. 
//     logic [31:0] mem_addr; 
//     logic dmem_resp_reg; // valid
//     logic [ROB_PTR_WIDTH:0] rob_idx_reg; // rob_idx
//     logic [4:0] arch_d_reg_reg; // arch_d_reg
//     logic [PHYSICAL_REG_FILE_LENGTH-1:0] phys_d_reg_reg; // phys_d_reg
//     logic [31:0] dmem_rdata_reg; // rd_v (after shifting and calculation)
//     logic [31:0] actual_dmem_rdata_reg; // raw data you read from memory, passed into RVFI. 
//     logic [3:0] rvfi_wmask_reg, rvfi_rmask_reg;

//     // garbage dmem resp
//     logic garbage_dmem;
//     always_ff @ (posedge clk) begin
//         if (rst) garbage_dmem <= 1'b0;
//         else if (flush_by_branch & (dmem_stall||(read_en && !(mem_rmask == '0 && mem_wmask == '0)))) garbage_dmem <= 1'b1;
//         else if (dmem_resp) garbage_dmem <= 1'b0;
//     end

//     // rvfi signals
//     logic [31:0] rs1_rdata_reg, rs2_rdata_reg, rd_wdata_reg;
//     logic [ROB_PTR_WIDTH:0] rob_ptr_reg;
//     logic inst_finished_reg;
//     logic [31:0] mem_addr_reg, mem_rdata_reg, mem_wdata_reg;

//     // write_ptr
//     always_ff @(posedge clk) begin

//         if(rst | flush_by_branch) begin
//             write_ptr <= '0;
//         end
//         else if(write_en&&!queue_full) begin
//             write_ptr <= write_ptr + 1'b1;
//         end
    
//     end

//     // read_ptr
//     always_ff @ (posedge clk) begin
//         if (rst | flush_by_branch) begin
//             read_ptr <= '0;
//         end else if (read_en && !queue_empty) begin
//             read_ptr <= read_ptr + 1'b1;
//         end
//     end
//     // writing data 
//     always_ff @ (posedge clk) begin
//         if (rst | flush_by_branch) begin
//             for (int i = 0; i < QUEUE_SIZE; i++) begin
//                 mem[i] <= '0;
//             end
//         end else begin
//             if (write_en && !queue_full) begin
//                 mem[write_ptr[size-1:0]] <= load_store_queue_entry;
//             end

//             for (int i = 0; i < MEM_QUEUE_DEPTH; i++) begin
//                 if (cdb_entry_add.valid) begin
//                     if (mem[i].phys_r1 == cdb_entry_add.phys_d_reg && cdb_entry_add.phys_d_reg != '0) begin
//                         mem[i].phys_r1_valid <= '1;
//                     end

//                     if (mem[i].phys_r2 == cdb_entry_add.phys_d_reg && cdb_entry_add.phys_d_reg != '0) begin
//                         mem[i].phys_r2_valid <= '1;
//                     end
//                 end

//                 if (cdb_entry_mult.valid) begin
//                     if (mem[i].phys_r1 == cdb_entry_mult.phys_d_reg && cdb_entry_mult.phys_d_reg != '0) begin
//                         mem[i].phys_r1_valid <= '1;
//                     end

//                     if (mem[i].phys_r2 == cdb_entry_mult.phys_d_reg && cdb_entry_mult.phys_d_reg != '0) begin
//                         mem[i].phys_r2_valid <= '1;
//                     end
//                 end

//                 if (cdb_entry_br.valid) begin
//                     if (mem[i].phys_r1 == cdb_entry_br.phys_d_reg && cdb_entry_br.phys_d_reg != '0) begin
//                         mem[i].phys_r1_valid <= '1;
//                     end

//                     if (mem[i].phys_r2 == cdb_entry_br.phys_d_reg && cdb_entry_br.phys_d_reg != '0) begin
//                         mem[i].phys_r2_valid <= '1;
//                     end
//                 end

//                 if (cdb_entry_mem_out.valid) begin
//                     if (mem[i].phys_r1 == cdb_entry_mem_out.phys_d_reg && cdb_entry_mem_out.phys_d_reg != '0) begin
//                         mem[i].phys_r1_valid <= '1;
//                     end

//                     if (mem[i].phys_r2 == cdb_entry_mem_out.phys_d_reg && cdb_entry_mem_out.phys_d_reg != '0) begin
//                         mem[i].phys_r2_valid <= '1;
//                     end
//                 end
//             end
//         end
//     end

 
//     // initiate request logic
//     always_comb begin
//         if (!mem[read_ptr[size-1:0]].load_store) begin // we only initiate load request when all arguments are ready.
//             if (mem[read_ptr[size-1:0]].phys_r1_valid) begin // argument is ready. 
//                 if (!dmem_resp && !(mem_wmask_reg == '0 && mem_rmask_reg == '0)) begin 
//                     read_en = '0;
//                 end else begin
//                     read_en = !garbage_dmem && !queue_empty; // send request. 
//                 end
//             end else begin // not valid, waiting on CDB. 
//                 read_en = '0;
//             end
//         end else begin // We only initiate store request when all arguments are ready and it's the head of the ROB. 
//             if (mem[read_ptr[size-1:0]].phys_r1_valid && mem[read_ptr[size-1:0]].phys_r2_valid) begin
//                 if (mem[read_ptr[size-1:0]].rob_idx[ROB_PTR_WIDTH-1:0] == ROB_read_ptr[ROB_PTR_WIDTH-1:0]) begin
//                     if (!dmem_resp && !(mem_wmask_reg == '0 && mem_rmask_reg == '0)) begin  
//                         read_en = '0;
//                     end else begin
//                         read_en = !garbage_dmem && !queue_empty;
//                     end
//                 end else begin
//                     read_en = '0;
//                 end
//             end else begin
//                 read_en = '0;
//             end
//         end
//     end
//     // address calculation
//     assign mem_addr = rs1_v_mem + mem[read_ptr[size-1:0]].imm;

//     // mask logic
//     always_comb begin
//         mem_rmask = '0;
//         mem_wmask = '0;
//         if (!mem[read_ptr[size-1:0]].load_store) begin
//             unique case (mem[read_ptr[size-1:0]].load_type) 
//                 load_f3_lb, load_f3_lbu: mem_rmask = 4'b0001 << mem_addr[1:0];
//                 load_f3_lh, load_f3_lhu: mem_rmask = 4'b0011 << mem_addr[1:0];
//                 load_f3_lw: mem_rmask = 4'b1111;
//                 default: mem_rmask = 'x;
//             endcase
//         end else begin
//             unique case (mem[read_ptr[size-1:0]].store_type) 
//                 store_f3_sb: mem_wmask = 4'b0001 << mem_addr[1:0];
//                 store_f3_sh: mem_wmask = 4'b0011 << mem_addr[1:0];
//                 store_f3_sw: mem_wmask = 4'b1111;
//                 default: mem_wmask = 'x;
//             endcase
//         end
//     end

//     // difference is that when dmem_rdata comes, next cycle we put on the CDB. 
//     always_ff @ (posedge clk) begin
//         if (rst|flush_by_branch) begin
//             mem_rmask_reg <= '0;
//             mem_wmask_reg <= '0;
//             load_store_reg <= '0;
//             addr_bottom_bits <= '0;
//             rob_idx_reg <= '0;
//             arch_d_reg_reg <= '0;
//             phys_d_reg_reg <= '0;
//         end else if (!dmem_stall) begin
//             mem_rmask_reg <= mem_rmask;
//             mem_wmask_reg <= mem_wmask; 
//             load_store_reg <= (mem_rmask != '0) ? 1'b0 : 1'b1; // 0-> load, 1->store
//             load_f3_reg <= mem[read_ptr[size-1:0]].load_type;
//             addr_bottom_bits <= mem_addr[1:0];
//             rob_idx_reg <= mem[read_ptr[size-1:0]].rob_idx;
//             arch_d_reg_reg <= mem[read_ptr[size-1:0]].arch_d_reg;
//             phys_d_reg_reg <= mem[read_ptr[size-1:0]].phys_d_reg;
//             if (!read_en) begin
//                 mem_rmask_reg <= '0;
//                 mem_wmask_reg <= '0; 
//             end 
//         end 
//     end

//     // initiating a request.
//     logic [31:0] dmem_wdata_out; // intermediate variable so we can pass it to RVFI as well. 
//     always_comb begin
//         dmem_addr = 'x;
//         dmem_rmask = '0;
//         dmem_wmask = '0;
//         dmem_wdata_out = 'x;
//         if (read_en) begin
//             dmem_addr = {mem_addr[31:2], 2'b00}; // align the address to 4 bytes
//             dmem_rmask = mem_rmask;
//             dmem_wmask = mem_wmask;
//             unique case(mem[read_ptr[size-1:0]].store_type)
//                 store_f3_sb: dmem_wdata_out[8 *mem_addr[1:0] +: 8 ] = rs2_v_mem[7:0];
//                 store_f3_sh: dmem_wdata_out[16*mem_addr[1]   +: 16] = rs2_v_mem[15:0];
//                 store_f3_sw: dmem_wdata_out = rs2_v_mem;
//                 default: dmem_wdata_out = '0;
//             endcase
//         end
//     end

//     assign dmem_wdata = dmem_wdata_out; 

//     always_ff @ (posedge clk) begin
//         if (rst|flush_by_branch) begin
//             dmem_resp_reg <= '0;
//             dmem_rdata_reg <= '0;
//             actual_dmem_rdata_reg <= '0;
//         end else begin
//             if (dmem_resp && !garbage_dmem) begin
//                 dmem_resp_reg <= '1;
//                 if (!load_store_reg) begin // load
//                     actual_dmem_rdata_reg <= dmem_rdata; 
//                     unique case(load_f3_reg)
//                         load_f3_lb: dmem_rdata_reg <= {{24{dmem_rdata[7 +8 *addr_bottom_bits[1:0]]}}, dmem_rdata[8 *addr_bottom_bits[1:0] +: 8 ]};
//                         load_f3_lbu: dmem_rdata_reg <= {{24{1'b0}}, dmem_rdata[8 *addr_bottom_bits[1:0] +: 8 ]};
//                         load_f3_lh: dmem_rdata_reg <= {{16{dmem_rdata[15+16*addr_bottom_bits[1]  ]}}, dmem_rdata[16*addr_bottom_bits[1]   +: 16]};
//                         load_f3_lhu: dmem_rdata_reg <= {{16{1'b0}}, dmem_rdata[16*addr_bottom_bits[1]   +: 16]};
//                         load_f3_lw: dmem_rdata_reg <= dmem_rdata;
//                         default: dmem_rdata_reg <= 'x;
//                     endcase
//                 end else begin // store
//                     dmem_rdata_reg <= '0;
//                 end
//             end else begin
//                 dmem_resp_reg <= '0;
//             end
//         end
//     end

    
//     assign inst_finished_reg = dmem_resp_reg; // rvfi signals
//     assign rd_wdata_reg = dmem_rdata_reg;
//     always_ff @ (posedge clk) begin // on read enable, latch basically everything other than mem_rdata, rd_wdata
//         // if (rst|flush_by_branch) begin
//         //     rs1_rdata_reg <= '0;
//         //     rs2_rdata_reg <= '0;
//         //     rob_ptr_reg   <= '0;
//         //     mem_addr_reg  <= '0;
//         //     mem_wdata_reg <= '0;
//         //     rvfi_wmask_reg <= '0;
//         //     rvfi_rmask_reg <= '0;
//         // end 
//         // else 
//         if (read_en) begin
//             // if (!dmem_resp) begin
//                 rvfi_wmask_reg <= mem_wmask;
//                 rvfi_rmask_reg <= mem_rmask;
//                 rs1_rdata_reg <= rs1_v_mem;
//                 rs2_rdata_reg <= rs2_v_mem;
//                 rob_ptr_reg   <= mem[read_ptr[size-1:0]].rob_idx; // store rob ptr before pop
//                 mem_addr_reg  <= mem_addr;
//                 mem_wdata_reg <= dmem_wdata_out;
//             // end
//         end
//     end
    
//     assign rvfi_inst_finished_mem = dmem_resp && !garbage_dmem;
//     logic [31:0] rvfi_rd_wdata_tmp; // used to calculate the rd_wdata value
//     always_comb begin
//         if (dmem_resp && !garbage_dmem) begin
//             if (!load_store_reg) begin
//                 unique case(load_f3_reg)
//                     load_f3_lb: rvfi_rd_wdata_tmp = {{24{dmem_rdata[7 +8 *addr_bottom_bits[1:0]]}}, dmem_rdata[8 *addr_bottom_bits[1:0] +: 8 ]};
//                     load_f3_lbu: rvfi_rd_wdata_tmp = {{24{1'b0}}, dmem_rdata[8 *addr_bottom_bits[1:0] +: 8 ]};
//                     load_f3_lh: rvfi_rd_wdata_tmp = {{16{dmem_rdata[15+16*addr_bottom_bits[1]  ]}}, dmem_rdata[16*addr_bottom_bits[1]   +: 16]};
//                     load_f3_lhu: rvfi_rd_wdata_tmp = {{16{1'b0}}, dmem_rdata[16*addr_bottom_bits[1]   +: 16]};
//                     load_f3_lw: rvfi_rd_wdata_tmp = dmem_rdata;
//                     default: rvfi_rd_wdata_tmp = 'x;
//                 endcase
//             end else begin
//                 rvfi_rd_wdata_tmp = '0;
//             end
//         end else begin
//             rvfi_rd_wdata_tmp = 'x;
//         end 
//     end
//     always_comb begin
//         if (dmem_resp && !garbage_dmem) begin // one cycle after response, provide all latched data to RVFI. 
//             rvfi_rs1_rdata_mem = rs1_rdata_reg;
//             rvfi_rs2_rdata_mem = rs2_rdata_reg;
//             rvfi_rd_wdata_mem = rvfi_rd_wdata_tmp;
//             rvfi_issue_execute_rob_ptr_mem = rob_ptr_reg;
//             rvfi_mem_wmask = rvfi_wmask_reg;
//             rvfi_mem_rmask = rvfi_rmask_reg;
//             rvfi_mem_addr = mem_addr_reg;
//             rvfi_mem_rdata = dmem_rdata;
//             rvfi_mem_wdata = mem_wdata_reg;
//         end else begin
//             rvfi_rs1_rdata_mem = '0;
//             rvfi_rs2_rdata_mem = '0;
//             rvfi_rd_wdata_mem = '0;
//             rvfi_issue_execute_rob_ptr_mem = '0;
//             rvfi_mem_wmask = '0;
//             rvfi_mem_rmask = '0;
//             rvfi_mem_addr = '0;
//             rvfi_mem_rdata = '0;
//             rvfi_mem_wdata = '0;
//         end
//     end

//     // CDB values. 
//     always_ff @ (posedge clk) begin
//         if (rst|flush_by_branch) begin
//             CDB_rob_reg <=  '0;
//             CDB_arch_reg <= '0;
//             CDB_phys_reg <= '0;
//         end
//         else if (dmem_resp && !garbage_dmem) begin
//             CDB_rob_reg <= rob_idx_reg;
//             CDB_arch_reg <= arch_d_reg_reg;
//             CDB_phys_reg <= phys_d_reg_reg;
//         end
//     end
//     assign cdb_entry_mem_out.valid = dmem_resp_reg;
//     assign cdb_entry_mem_out.rob_idx = CDB_rob_reg;
//     assign cdb_entry_mem_out.arch_d_reg = CDB_arch_reg;
//     assign cdb_entry_mem_out.phys_d_reg = CDB_phys_reg;
//     assign cdb_entry_mem_out.rd_v = dmem_rdata_reg;

// endmodule : CDB_mem

