// module CDB_memXD
// import rv32i_types::*;
// import params::*;
// #(
//     LOAD_RS_SIZE = LOAD_RS_NUM,
//     STORE_QUEUE_SIZE = STORE_QUEUE_DEPTH
// )
// (
//     input   logic           clk,
//     input   logic           rst,

//     input   logic   load_write,
//     input   load_rs_entry_t load_rs_entry,
//     input   logic   store_write,
//     input   store_queue_entry_t store_queue_entry, 

//     input   logic [ROB_PTR_WIDTH : 0] ROB_read_ptr,

//     output  logic [PHYSICAL_REG_WIDTH - 1:0] rs1_mem, //outputs into Phys Reg File (we don't need rs2 for loads)
//     output  logic [PHYSICAL_REG_WIDTH - 1:0] rs2_mem,
//     input   logic   [31:0]  rs1_v_mem, 
//     input   logic   [31:0]  rs2_v_mem,

//     input   logic flush_by_branch,
//     input   cdb_entry_t     cdb_entry_mult, 
//     input   cdb_entry_t     cdb_entry_branch,
//     input   cdb_entry_t     cdb_entry_alu,
//     output  cdb_entry_t     cdb_entry_mem_out,

//     output  logic   rs_load_full,
//     output  logic   store_queue_full, 

//     output logic [STORE_QUEUE_DEPTH-1:0] older_store_map, // bit mask to designate 

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

//     // queues
//     load_rs_entry_t load_rs [LOAD_RS_SIZE];
//     store_queue_entry_t store_queue [STORE_QUEUE_SIZE];
//     store_forward_map_entry_t forward_map [FORWARD_MAP_SIZE];

//     logic [STORE_QUEUE_PTR_WIDTH:0] store_queue_read_ptr, store_queue_write_ptr;
//     logic store_queue_empty; 

//     // logic store_pop;

//     logic [STORE_QUEUE_DEPTH-1:0] bitmap; // bitmap used to check for dependencies and ready or not. 

//     logic rs_full;
//     logic [LOAD_RS_INDEX_BITS-1:0] load_serving_idx; // not going to have more than 16 RSs
//     logic garbage_dmem;

//     logic store_ready;
//     logic load_ready;

//     cdb_entry_t cdb_entry_mem;

//     logic old_stores_good;
//     logic [LOAD_RS_INDEX_BITS-1:0] load_rs_index_reg;

//     logic [3:0] mem_rmask_reg, mem_rmask;
//     logic [3:0] mem_wmask_reg, mem_wmask; 
//     logic [ROB_PTR_WIDTH:0] CDB_rob_reg;
//     logic [4:0] CDB_arch_reg;
//     logic [PHYSICAL_REG_FILE_LENGTH-1:0] CDB_phys_reg;
//     load_f3_t load_f3_reg; 
//     logic [1:0] addr_bottom_bits; // needed for load to shift data correctly. 
//     logic dmem_resp_reg; // valid
//     logic [ROB_PTR_WIDTH:0] rob_idx_reg; // rob_idx
//     logic [4:0] arch_d_reg_reg; // arch_d_reg
//     logic [PHYSICAL_REG_FILE_LENGTH-1:0] phys_d_reg_reg; // phys_d_reg
//     logic [31:0] dmem_rdata_reg; // rd_v (after shifting and calculation)
//     logic [31:0] actual_dmem_rdata_reg; // raw data you read from memory, passed into RVFI. 
//     logic [3:0] rvfi_wmask_reg, rvfi_rmask_reg;

//     // rvfi
//     logic [31:0] rs1_rdata_reg, rs2_rdata_reg;
//     // logic [31:0] rd_wdata_reg;
//     logic [ROB_PTR_WIDTH:0] rob_ptr_reg;
//     // logic inst_finished_reg;
//     logic [31:0] mem_addr_reg, mem_rdata_reg, mem_wdata_reg;

//     logic can_forward_reg;
//     logic [31:0] forwarded_rs1_data_reg, forwarded_rd_wdata_reg;
//     // assign forwarded_rd_wdata_reg = dmem_rdata_reg;
//     logic [ROB_PTR_WIDTH:0] forwarded_rob_ptr_reg;
//     logic [3:0] forwarded_mem_wmask_reg, forwarded_mem_rmask_reg;
//     logic [31:0] forwarded_mem_addr_reg, forwarded_mem_rdata_reg; 

//     logic [31:0] mem_addr;
//     logic [31:0] imm_v;
//     assign mem_addr = rs1_v_mem + imm_v; 

//     logic [31:0] rvfi_rd_wdata_tmp; // used to calculate the rd_wdata value

//     logic dmem_stall;
//     assign dmem_stall = (!dmem_resp && !(mem_wmask_reg == '0 && mem_rmask_reg == '0)) ? 1'b1 : 1'b0;

//     assign store_queue_full = ((store_queue_write_ptr[STORE_QUEUE_PTR_WIDTH-1:0] == store_queue_read_ptr[STORE_QUEUE_PTR_WIDTH-1:0])&&(store_queue_write_ptr[STORE_QUEUE_PTR_WIDTH] != store_queue_read_ptr[STORE_QUEUE_PTR_WIDTH])) ? '1 : '0; // makes sure read_ptr is more thanone away
//     assign store_queue_empty = (store_queue_read_ptr == store_queue_write_ptr) ? '1 : '0;

//     // write_ptr logic
//     always_ff @ (posedge clk) begin
//         if (rst | flush_by_branch) begin
//             store_queue_write_ptr <= '0;
//         end else if (store_write && !store_queue_full) begin
//             store_queue_write_ptr <= store_queue_write_ptr + 1'b1;
//         end
//     end

//     // read_ptr logic
//     always_ff @ (posedge clk) begin
//         if (rst | flush_by_branch) begin
//             store_queue_read_ptr <= '0;
//         end else if (store_ready && !store_queue_empty) begin
//             store_queue_read_ptr <= store_queue_read_ptr + 1'b1;
//         end
//     end

//     // // pop logic for SQ
//     // always_comb begin
//     //     store_pop = '0;
//     //     if (store_queue[store_queue_read_ptr[STORE_QUEUE_PTR_WIDTH-1:0]].rob_idx[ROB_PTR_WIDTH-1:0] == ROB_read_ptr[ROB_PTR_WIDTH-1:0]) begin
//     //         store_pop = '1;
//     //     end
//     // end

//     // writing logic for SQ
//     always_ff @ (posedge clk) begin
//         if (rst | flush_by_branch) begin
//             for (int i = 0; i < STORE_QUEUE_SIZE; i++) begin
//                 store_queue[i] <= '0;
//             end
//         end else begin
//             if (store_write && !store_queue_full) begin
//                 store_queue[store_queue_write_ptr[STORE_QUEUE_PTR_WIDTH-1:0]] <= store_queue_entry;
//             end

//             // if (store_ready && ((dmem_resp && !garbage_dmem) || (!dmem_resp && (mem_wmask_reg == '0 && mem_rmask_reg == '0)))) begin
//             if (store_ready && !dmem_stall) begin
//                 store_queue[store_queue_read_ptr[STORE_QUEUE_PTR_WIDTH-1:0]].req_sent <= '1;
//             end

//             for (int i = 0; i < STORE_QUEUE_SIZE; i++) begin
//                 if (cdb_entry_alu.valid) begin
//                     if (store_queue[i].phys_r1 == cdb_entry_alu.phys_d_reg && cdb_entry_alu.phys_d_reg != '0) begin
//                         store_queue[i].phys_r1_valid <= '1;
//                     end

//                     if (store_queue[i].phys_r2 == cdb_entry_alu.phys_d_reg && cdb_entry_alu.phys_d_reg != '0) begin
//                         store_queue[i].phys_r2_valid <= '1;
//                     end
//                 end

//                 if (cdb_entry_mult.valid) begin
//                     if (store_queue[i].phys_r1 == cdb_entry_mult.phys_d_reg && cdb_entry_mult.phys_d_reg != '0) begin
//                         store_queue[i].phys_r1_valid <= '1;
//                     end

//                     if (store_queue[i].phys_r2 == cdb_entry_mult.phys_d_reg && cdb_entry_mult.phys_d_reg != '0) begin
//                         store_queue[i].phys_r2_valid <= '1;
//                     end
//                 end

//                 if (cdb_entry_branch.valid) begin
//                     if (store_queue[i].phys_r1 == cdb_entry_branch.phys_d_reg && cdb_entry_branch.phys_d_reg != '0) begin
//                         store_queue[i].phys_r1_valid <= '1;
//                     end

//                     if (store_queue[i].phys_r2 == cdb_entry_branch.phys_d_reg && cdb_entry_branch.phys_d_reg != '0) begin
//                         store_queue[i].phys_r2_valid <= '1;
//                     end
//                 end

//                 if (cdb_entry_mem.valid) begin
//                     if (store_queue[i].phys_r1 == cdb_entry_mem.phys_d_reg && cdb_entry_mem.phys_d_reg != '0) begin
//                         store_queue[i].phys_r1_valid <= '1;
//                     end

//                     if (store_queue[i].phys_r2 == cdb_entry_mem.phys_d_reg && cdb_entry_mem.phys_d_reg != '0) begin
//                         store_queue[i].phys_r2_valid <= '1;
//                     end
//                 end
//             end
//         end
//     end

//     logic match_found;
//     logic [FORWARD_MAP_PTR_SIZE-1:0] forward_map_write_ptr;
//     logic [FORWARD_MAP_PTR_SIZE-1:0] match_idx;
//     // forward map
//     always_ff @ (posedge clk) begin
//         if (rst) begin
//             forward_map_write_ptr <= '0;
//         end else if (!match_found && store_ready) begin
//             forward_map_write_ptr <= forward_map_write_ptr + 1'b1;
//         end
//     end 

//     always_ff @ (posedge clk) begin
//         if (rst) begin
//             for (int i = 0; i < FORWARD_MAP_SIZE; i++) begin
//                 forward_map[i] <= '0;
//             end
//         end else begin
//             if (match_found && store_ready) begin
//                 unique case(store_queue[store_queue_read_ptr[STORE_QUEUE_PTR_WIDTH-1:0]].store_type) 
//                     store_f3_sb: begin
//                         forward_map[match_idx].data[8*mem_addr[1:0] +: 8] <= rs2_v_mem[7:0];
//                         forward_map[match_idx].valid_forward_bytes[mem_addr] <= 1'b1;
//                     end
//                     store_f3_sh: begin
//                         forward_map[match_idx].data[16*mem_addr[1]   +: 16] <= rs2_v_mem[15:0];
//                         forward_map[match_idx].valid_forward_bytes[mem_addr[1]+:2] <= 2'b11;
//                     end
//                     store_f3_sw: begin
//                         forward_map[match_idx].data <= rs2_v_mem;
//                         forward_map[match_idx].valid_forward_bytes <= '1;
//                     end
//                 endcase
//             end else if (!match_found && store_ready) begin
//                 forward_map[forward_map_write_ptr].addr <= mem_addr;
//                 forward_map[forward_map_write_ptr].valid_forward_bytes <= '0;
//                 unique case(store_queue[store_queue_read_ptr[STORE_QUEUE_PTR_WIDTH-1:0]].store_type) 
//                     store_f3_sb: begin
//                         forward_map[forward_map_write_ptr].data[8*mem_addr[1:0] +: 8] <= rs2_v_mem[7:0];
//                         forward_map[forward_map_write_ptr].valid_forward_bytes[mem_addr] <= 1'b1;
//                     end
//                     store_f3_sh: begin
//                         forward_map[forward_map_write_ptr].data[16*mem_addr[1]   +: 16] <= rs2_v_mem[15:0];
//                         forward_map[forward_map_write_ptr].valid_forward_bytes[mem_addr[1]+:2] <= 2'b11;
//                     end
//                     store_f3_sw: begin
//                         forward_map[forward_map_write_ptr].data <= rs2_v_mem;
//                         forward_map[forward_map_write_ptr].valid_forward_bytes <= '1;
//                     end
//                 endcase
//             end
//         end
//     end

//     always_comb begin
//         match_found = '0;
//         match_idx = '0;
//         if (store_ready) begin
//             for (int i = 0; i < FORWARD_MAP_SIZE; i++) begin
//                 if (forward_map[i].addr[31:2] == mem_addr[31:2]) begin
//                     match_found = '1;
//                     match_idx = FORWARD_MAP_PTR_SIZE'(i);
//                     break;
//                 end
//             end
//         end
//     end

//     // bit map
//     always_ff @ (posedge clk) begin
//         if (rst | flush_by_branch) begin
//             bitmap <= '0;
//         end else begin
//             if (store_write && !store_queue_full) begin
//                 bitmap[store_queue_write_ptr[STORE_QUEUE_PTR_WIDTH-1:0]] <= 1'b1;
//             end 
//             if (store_ready && !store_queue_empty) begin
//                 bitmap[store_queue_read_ptr[STORE_QUEUE_PTR_WIDTH-1:0]] <= 1'b0;
//             end
//         end
//     end
//     assign older_store_map = bitmap;

//     // garbage dmem resp
//     always_ff @ (posedge clk) begin
//         if (rst) garbage_dmem <= 1'b0;
//         // else if (flush_by_branch & (dmem_stall||(read_en && !(mem_rmask == '0 && mem_wmask == '0)))) garbage_dmem <= 1'b1;
//         else if (flush_by_branch & (dmem_stall||((store_ready || load_ready) && !(mem_rmask == '0 && mem_wmask == '0)))) garbage_dmem <= 1'b1;
//         else if (dmem_resp) garbage_dmem <= 1'b0;
//     end

//     logic can_forward;
//     logic [31:0] forward_rdata; 
//     // figure out which to serve, probably use this part to also perform store-forwarding. 
//     always_comb begin
//         load_ready = '0;
//         load_serving_idx = '0;
//         old_stores_good = '1;
//         can_forward = '0;
//         forward_rdata = '0;
//         for (int unsigned i = 0; i < LOAD_RS_SIZE; i++) begin
//             if (load_rs[i].phys_r1_valid && !load_rs[i].finished && !load_rs[i].req_sent) begin
//                 if (load_rs[i].store_bitmap == '0) begin
//                     old_stores_good = '1;
//                 end else begin
//                     for (int j = 0; j < STORE_QUEUE_SIZE; j++) begin
//                         if (load_rs[i].store_bitmap[j] == '1 && !store_queue[j].req_sent) begin
//                             old_stores_good = '0;
//                             break;
//                         end
//                     end
//                 end

                
//                 if (old_stores_good && dmem_stall) begin // during a store, we can forward loads.
//                     // load_ready = '1;
//                     load_serving_idx = LOAD_RS_INDEX_BITS'(i);
//                     for (int k = 0; k < FORWARD_MAP_SIZE; k++) begin
//                         // load_ready = '1;
//                         if (mem_addr[31:2] == forward_map[k].addr[31:2]) begin

//                             can_forward = !(|(~forward_map[k].valid_forward_bytes & mem_rmask));
//                             if (can_forward) begin
//                                 load_ready = '1;
//                                 if (mem_rmask[0]) begin
//                                     forward_rdata[7:0] = forward_map[k].data[7:0];
//                                 end

//                                 if (mem_rmask[1]) begin
//                                     forward_rdata[15:8] = forward_map[k].data[15:8];
//                                 end

//                                 if (mem_rmask[2]) begin
//                                     forward_rdata[23:16] = forward_map[k].data[23:16];
//                                 end

//                                 if (mem_rmask[3]) begin
//                                     forward_rdata[31:24] = forward_map[k].data[31:24];
//                                 end

//                                 break;
//                             end
//                         end
//                     end

//                 end 
//                 else if (old_stores_good && ((dmem_resp && !garbage_dmem) || (!dmem_resp && (mem_wmask_reg == '0 && mem_rmask_reg == '0)))) begin
//                     load_ready = '1;
//                     load_serving_idx = LOAD_RS_INDEX_BITS'(i);
//                     break;
//                 end
//             end
//         end
//     end

//     // decide between whether to serve from load RS or from store queue.
//     // always serve older stores first, then send loads out of order. 
//     // logic giant_if;
//     // assign giant_if = !store_queue[store_queue_read_ptr[STORE_QUEUE_PTR_WIDTH-1:0]].req_sent && store_queue[store_queue_read_ptr[STORE_QUEUE_PTR_WIDTH-1:0]].phys_r1_valid && store_queue[store_queue_read_ptr[STORE_QUEUE_PTR_WIDTH-1:0]].phys_r2_valid && store_queue[store_queue_read_ptr[STORE_QUEUE_PTR_WIDTH-1:0]].rob_idx[ROB_PTR_WIDTH-1:0] == ROB_read_ptr[ROB_PTR_WIDTH-1:0];
//     always_comb begin
//         store_ready = '0;
//         // if(giant_if) begin
//         if (!store_queue[store_queue_read_ptr[STORE_QUEUE_PTR_WIDTH-1:0]].req_sent) begin
//             if (store_queue[store_queue_read_ptr[STORE_QUEUE_PTR_WIDTH-1:0]].phys_r1_valid && store_queue[store_queue_read_ptr[STORE_QUEUE_PTR_WIDTH-1:0]].phys_r2_valid) begin
//                 if (store_queue[store_queue_read_ptr[STORE_QUEUE_PTR_WIDTH-1:0]].rob_idx[ROB_PTR_WIDTH-1:0] == ROB_read_ptr[ROB_PTR_WIDTH-1:0]) begin
//                     if (dmem_stall) begin
//                         store_ready = '0;
//                     end else begin
//                         store_ready = !garbage_dmem && !store_queue_empty;
//                     end
//                 end
//             end
//         end
//         // end
//     end

//     // determine which physical registers to read from. 
//     always_comb begin
//         if (store_ready) begin
//             rs1_mem = store_queue[store_queue_read_ptr[STORE_QUEUE_PTR_WIDTH-1:0]].phys_r1;
//             rs2_mem = store_queue[store_queue_read_ptr[STORE_QUEUE_PTR_WIDTH-1:0]].phys_r2;
//             imm_v = store_queue[store_queue_read_ptr[STORE_QUEUE_PTR_WIDTH-1:0]].imm;
//         end 
//         // else if (load_ready) begin
//         //     rs1_mem = load_rs[load_serving_idx].phys_r1; 
//         //     rs2_mem = '0;
//         //     imm_v = load_rs[load_serving_idx].imm; 
//         // end 
//         // else begin
//         //     rs1_mem = '0;
//         //     rs2_mem = '0;
//         //     imm_v = '0;
//         // end
//         else begin
//             rs1_mem = load_rs[load_serving_idx].phys_r1; 
//             rs2_mem = '0;
//             imm_v = load_rs[load_serving_idx].imm; 
//         end
//     end

//     //mask logic
//     always_comb begin
//         mem_rmask = '0;
//         mem_wmask = '0;
//         if (store_ready) begin
//             unique case (store_queue[store_queue_read_ptr[STORE_QUEUE_PTR_WIDTH-1:0]].store_type) 
//                 store_f3_sb: mem_wmask = 4'b0001 << mem_addr[1:0];
//                 store_f3_sh: mem_wmask = 4'b0011 << mem_addr[1:0];
//                 store_f3_sw: mem_wmask = 4'b1111;
//                 default: mem_wmask = 'x;
//             endcase
//         end else begin
//             unique case (load_rs[load_serving_idx].load_type) 
//                 load_f3_lb, load_f3_lbu: mem_rmask = 4'b0001 << mem_addr[1:0];
//                 load_f3_lh, load_f3_lhu: mem_rmask = 4'b0011 << mem_addr[1:0];
//                 load_f3_lw: mem_rmask = 4'b1111;
//                 default: mem_rmask = 'x;
//             endcase
//         end
//     end

//     always_ff @ (posedge clk) begin
//         // if (rst|flush_by_branch) begin
//         if (rst | flush_by_branch) begin
//             mem_rmask_reg <= '0;
//             mem_wmask_reg <= '0;
//             addr_bottom_bits <= '0;
//             rob_idx_reg <= '0;
//             arch_d_reg_reg <= '0;
//             phys_d_reg_reg <= '0;
//             load_f3_reg <= load_f3_lw;
//         end else if (!dmem_stall) begin
//             mem_rmask_reg <= mem_rmask;
//             mem_wmask_reg <= mem_wmask; 

//             if (store_ready) begin
//                 rob_idx_reg <= store_queue[store_queue_read_ptr[STORE_QUEUE_PTR_WIDTH-1:0]].rob_idx;
//                 arch_d_reg_reg <= '0;
//                 phys_d_reg_reg <= '0;
//             end else if (load_ready && !can_forward) begin
//                 load_f3_reg <= load_rs[load_serving_idx].load_type;
//                 addr_bottom_bits <= mem_addr[1:0];
//                 rob_idx_reg <= load_rs[load_serving_idx].rob_idx;
//                 arch_d_reg_reg <= load_rs[load_serving_idx].arch_d_reg;
//                 phys_d_reg_reg <= load_rs[load_serving_idx].phys_d_reg;
//             end else begin
//                 mem_rmask_reg <= '0;
//                 mem_wmask_reg <= '0; 
//             end
//         end 
//     end

//     // pass dmem signals
//     logic [31:0] dmem_wdata_out; // intermediate variable so we can pass it to RVFI as well. 
//     always_comb begin
//         dmem_addr = 'x;
//         dmem_rmask = '0;
//         dmem_wmask = '0;
//         dmem_wdata_out = 'x;
//         if (can_forward) begin
//             dmem_rmask = '0;
//             dmem_wmask = '0;
//         end else begin
//             if ((store_ready && !store_queue[store_queue_read_ptr[STORE_QUEUE_PTR_WIDTH-1:0]].req_sent) || (load_ready && !load_rs[load_serving_idx].req_sent)) begin
//                 dmem_addr = {mem_addr[31:2], 2'b00}; // align the address to 4 bytes
//                 dmem_rmask = mem_rmask;
//                 dmem_wmask = mem_wmask;
//                 if (store_ready) begin
//                     unique case(store_queue[store_queue_read_ptr[STORE_QUEUE_PTR_WIDTH-1:0]].store_type)
//                         store_f3_sb: dmem_wdata_out[8 *mem_addr[1:0] +: 8 ] = rs2_v_mem[7:0];
//                         store_f3_sh: dmem_wdata_out[16*mem_addr[1]   +: 16] = rs2_v_mem[15:0];
//                         store_f3_sw: dmem_wdata_out = rs2_v_mem;
//                         default: dmem_wdata_out = '0;
//                     endcase
//                 end else if (load_ready) begin
//                     dmem_wdata_out = '0;
//                 end
//             end
//         end
//     end

//     assign dmem_wdata = dmem_wdata_out;

//     // keeps track of the serving idx to that on dmem_resp, we can update the entry to finished. 
//     always_ff @ (posedge clk) begin
//         if (rst | flush_by_branch) begin
//             load_rs_index_reg <= '0;
//         end else if (load_ready && !can_forward) begin
//             load_rs_index_reg <= load_serving_idx; 
//         end
//     end

//     // post response calculation on loads for CDB. 
//     always_ff @ (posedge clk) begin
//         if (rst | flush_by_branch) begin
//             dmem_resp_reg <= '0;
//             dmem_rdata_reg <= '0;
//             actual_dmem_rdata_reg <= '0;
//         end else begin
//             if (load_ready && can_forward) begin
//                 dmem_resp_reg <= '1;
//                 actual_dmem_rdata_reg <= forward_rdata;
//                 unique case(load_rs[load_serving_idx].load_type)
//                     load_f3_lb: dmem_rdata_reg <= {{24{forward_rdata[7 +8 *mem_addr[1:0]]}}, forward_rdata[8 *mem_addr[1:0] +: 8 ]};
//                     load_f3_lbu: dmem_rdata_reg <= {{24{1'b0}}, forward_rdata[8 *mem_addr[1:0] +: 8 ]};
//                     load_f3_lh: dmem_rdata_reg <= {{16{forward_rdata[15+16*mem_addr[1]  ]}}, forward_rdata[16*mem_addr[1]   +: 16]};
//                     load_f3_lhu: dmem_rdata_reg <= {{16{1'b0}}, forward_rdata[16*mem_addr[1]   +: 16]};
//                     load_f3_lw: dmem_rdata_reg <= forward_rdata;
//                     default: dmem_rdata_reg <= 'x;
//                 endcase
//             end
//             else if (dmem_resp && !garbage_dmem) begin
//                 dmem_resp_reg <= '1;
//                 if (mem_rmask_reg != '0) begin // load
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
//                     actual_dmem_rdata_reg <= '0;
//                     dmem_rdata_reg <= '0;
//                 end
//             end else begin
//                 dmem_resp_reg <= '0;
//             end
//         end
//     end
    
//     // ------------------------- RVFI --------------------------------
//     // assign inst_finished_reg = (can_forward)? '1 : dmem_resp_reg;
//     // assign rd_wdata_reg = (can_forward)? forward_rdata : dmem_rdata_reg;
//     always_ff @ (posedge clk) begin // on read enable, latch basically everything other than mem_rdata, rd_wdata
//         if (store_ready) begin
//             rvfi_wmask_reg <= mem_wmask;
//             rvfi_rmask_reg <= mem_rmask;
//             rs1_rdata_reg <= rs1_v_mem;
//             rs2_rdata_reg <= rs2_v_mem;
//             rob_ptr_reg   <= store_queue[store_queue_read_ptr[STORE_QUEUE_PTR_WIDTH-1:0]].rob_idx; // store rob ptr before pop
//             mem_addr_reg  <= mem_addr;
//             mem_wdata_reg <= dmem_wdata_out;
//         end else if (load_ready && !can_forward) begin
//             rvfi_wmask_reg <= mem_wmask;
//             rvfi_rmask_reg <= mem_rmask;
//             rs1_rdata_reg <= rs1_v_mem;
//             rs2_rdata_reg <= rs2_v_mem;
//             rob_ptr_reg   <= load_rs[load_serving_idx].rob_idx; // store rob ptr before pop
//             mem_addr_reg  <= mem_addr;
//             mem_wdata_reg <= dmem_wdata_out;
//         end
//     end

//     logic [31:0] forwarded_rd_wdata_tmp;
//     always_comb begin
//         forwarded_rd_wdata_tmp = '0;
//         if (can_forward && !dmem_resp) begin
//             unique case(load_rs[load_serving_idx].load_type)
//                 load_f3_lb: forwarded_rd_wdata_tmp = {{24{forward_rdata[7 +8 *mem_addr[1:0]]}}, forward_rdata[8 *mem_addr[1:0] +: 8 ]};
//                 load_f3_lbu: forwarded_rd_wdata_tmp = {{24{1'b0}}, forward_rdata[8 *mem_addr[1:0] +: 8 ]};
//                 load_f3_lh: forwarded_rd_wdata_tmp = {{16{forward_rdata[15+16*mem_addr[1]  ]}}, forward_rdata[16*mem_addr[1]   +: 16]};
//                 load_f3_lhu: forwarded_rd_wdata_tmp = {{16{1'b0}}, forward_rdata[16*mem_addr[1]   +: 16]};
//                 load_f3_lw: forwarded_rd_wdata_tmp = forward_rdata;
//                 default: forwarded_rd_wdata_tmp = 'x;
//             endcase
//         end
//     end

//     logic forward_finished;
//     logic req_finished; 
//     logic forward_finish_now;
//     assign rvfi_inst_finished_mem = forward_finished || req_finished || forward_finish_now;

//     assign req_finished = (dmem_resp && !garbage_dmem);
//     assign forward_finished = (can_forward_reg && !dmem_resp); // for case where we can forward but we receive dmem_resp
//     assign forward_finish_now = (can_forward && !dmem_resp);

//     always_ff @ (posedge clk) begin
//         if (load_ready && can_forward) begin
//             unique case(load_rs[load_serving_idx].load_type)
//                 load_f3_lb: forwarded_rd_wdata_reg <= {{24{forward_rdata[7 +8 *mem_addr[1:0]]}}, forward_rdata[8 *mem_addr[1:0] +: 8 ]};
//                 load_f3_lbu: forwarded_rd_wdata_reg <= {{24{1'b0}}, forward_rdata[8 *mem_addr[1:0] +: 8 ]};
//                 load_f3_lh: forwarded_rd_wdata_reg <= {{16{forward_rdata[15+16*mem_addr[1]  ]}}, forward_rdata[16*mem_addr[1]   +: 16]};
//                 load_f3_lhu: forwarded_rd_wdata_reg <= {{16{1'b0}}, forward_rdata[16*mem_addr[1]   +: 16]};
//                 load_f3_lw: forwarded_rd_wdata_reg <= forward_rdata;
//                 default: forwarded_rd_wdata_reg <= 'x;
//             endcase
//         end
//     end
    
//     always_comb begin
//         if (dmem_resp && !garbage_dmem) begin
//             if (mem_rmask_reg != '0) begin
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

//     always_ff @ (posedge clk) begin
//         if (rst | flush_by_branch) begin
//             can_forward_reg <= '0;
//         end else begin
//             if (dmem_resp && !garbage_dmem) begin
//                 if (can_forward) begin
//                     can_forward_reg <= '1;
//                 end else if (can_forward_reg == '1) begin
//                     can_forward_reg <= can_forward_reg;
//                 end
//             end else begin
//                 can_forward_reg <= '0;
//             end
//         end
//     end

    


//     always_ff @ (posedge clk) begin
//         if (can_forward) begin
//             forwarded_rs1_data_reg <= rs1_v_mem;
//             forwarded_rob_ptr_reg <= load_rs[load_serving_idx].rob_idx;
//             forwarded_mem_wmask_reg <= mem_wmask;
//             forwarded_mem_rmask_reg <= mem_rmask; 
//             forwarded_mem_addr_reg <= mem_addr;
//             forwarded_mem_rdata_reg <= forward_rdata;
//         end 
//     end

//     // forwarded_rd_wdata_reg needs to be held until 



//     always_comb begin
//         if ((dmem_resp && !garbage_dmem)) begin // same cycle as response, provide data to RVFI. 
//             rvfi_rs1_rdata_mem = rs1_rdata_reg;
//             rvfi_rs2_rdata_mem = rs2_rdata_reg;
//             rvfi_rd_wdata_mem = rvfi_rd_wdata_tmp;
//             rvfi_issue_execute_rob_ptr_mem = rob_ptr_reg;
//             rvfi_mem_wmask = rvfi_wmask_reg;
//             rvfi_mem_rmask = rvfi_rmask_reg;
//             rvfi_mem_addr = mem_addr_reg;
//             rvfi_mem_rdata = dmem_rdata;
//             rvfi_mem_wdata = mem_wdata_reg;
//         end else if (can_forward && !dmem_resp) begin
//             rvfi_rs1_rdata_mem = rs1_v_mem;
//             rvfi_rs2_rdata_mem = '0;
//             rvfi_rd_wdata_mem = forwarded_rd_wdata_tmp;
//             rvfi_issue_execute_rob_ptr_mem = load_rs[load_serving_idx].rob_idx;
//             rvfi_mem_wmask = mem_wmask;
//             rvfi_mem_rmask = mem_rmask;
//             rvfi_mem_addr = mem_addr;
//             rvfi_mem_rdata = forward_rdata;
//             rvfi_mem_wdata = '0;
//         end 
//         else if (can_forward_reg && !dmem_resp) begin
//             rvfi_rs1_rdata_mem = forwarded_rs1_data_reg;
//             rvfi_rs2_rdata_mem = '0;
//             rvfi_rd_wdata_mem = forwarded_rd_wdata_reg;
//             rvfi_issue_execute_rob_ptr_mem = forwarded_rob_ptr_reg;
//             rvfi_mem_wmask = forwarded_mem_wmask_reg;
//             rvfi_mem_rmask = forwarded_mem_rmask_reg;
//             rvfi_mem_addr = forwarded_mem_addr_reg;
//             rvfi_mem_rdata = forwarded_mem_rdata_reg;
//             rvfi_mem_wdata = '0;
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
//     // -------------- RVFI -------------------------------------------

//     // --------------------------------- CDB -----------------------------
//     always_ff @ (posedge clk) begin
//         // if (rst|flush_by_branch) begin
//         if (rst | flush_by_branch) begin
//             CDB_rob_reg <=  '0;
//             CDB_arch_reg <= '0;
//             CDB_phys_reg <= '0;
//         end
//         else if (dmem_resp && !garbage_dmem) begin
//             CDB_rob_reg <= rob_idx_reg;
//             CDB_arch_reg <= arch_d_reg_reg;
//             CDB_phys_reg <= phys_d_reg_reg;
//         end
//         else if (can_forward && !dmem_resp) begin
//             CDB_rob_reg <= load_rs[load_serving_idx].rob_idx;
//             CDB_arch_reg <= load_rs[load_serving_idx].arch_d_reg;
//             CDB_phys_reg <= load_rs[load_serving_idx].phys_d_reg;
//         end
//     end
//     assign cdb_entry_mem.valid = dmem_resp_reg;
//     assign cdb_entry_mem.rob_idx = CDB_rob_reg;
//     assign cdb_entry_mem.arch_d_reg = CDB_arch_reg;
//     assign cdb_entry_mem.phys_d_reg = CDB_phys_reg;
//     assign cdb_entry_mem.rd_v = dmem_rdata_reg;

//     // Load reservation station
//     always_ff @(posedge clk) begin
//         if(rst | flush_by_branch) begin
//             for (int i = 0; i < LOAD_RS_SIZE; i++) begin
//                 load_rs[i].finished <= 1'b1;
//                 load_rs[i].req_sent <= 1'b0;
//                 load_rs[i].load_type <= load_f3_lw;
//                 load_rs[i].imm <= '0;
//                 load_rs[i].arch_d_reg <= '0;
//                 load_rs[i].phys_d_reg <= '0;
//                 load_rs[i].phys_r1 <= '0;
//                 load_rs[i].phys_r2 <= '0;
//                 load_rs[i].phys_r1_valid <= '0; 
//                 load_rs[i].phys_r2_valid <= '0; 
//                 load_rs[i].rob_idx <= '0;
//                 load_rs[i].store_bitmap <= '0;
//             end 
//         end
//         else begin
//             if(!rs_full & load_write) begin
//                 for (int i = 0; i < LOAD_RS_SIZE; i++) begin
//                     if (load_rs[i].finished == 1'b1) begin
//                         load_rs[i] <= load_rs_entry;
//                         break;
//                     end
//                 end 
//             end

//             if (load_ready && can_forward) begin
//                 load_rs[load_serving_idx].req_sent <= '1;
//                 load_rs[load_serving_idx].finished <= '1;
//             end else if (load_ready && !can_forward && !garbage_dmem) begin
//                 load_rs[load_serving_idx].req_sent <= '1;
//             end

//             if (dmem_resp && !garbage_dmem && mem_rmask_reg != '0) begin // we got a sucessful resp for a read.
//                 load_rs[load_rs_index_reg].finished <= '1;
//             end

//             if (store_ready) begin
//                 for (int i = 0; i < LOAD_RS_SIZE; i++) begin
//                     load_rs[i].store_bitmap[store_queue_read_ptr[STORE_QUEUE_PTR_WIDTH-1:0]] <= 1'b0;
//                 end
//             end

//             //  exec finished, set corresponding finish to 1; set invalid operand to valid
//             for (int i = 0; i < LOAD_RS_SIZE; i++) begin
//                 if (load_rs[i].finished == 1'b0) begin
//                     if (cdb_entry_branch.valid) begin
//                         if (cdb_entry_branch.phys_d_reg == load_rs[i].phys_r1) begin
//                             load_rs[i].phys_r1_valid <= 1'b1;
//                         end
//                     end 
                
//                     if (cdb_entry_alu.valid) begin
//                     // for (int i = 0; i < ALU_RS_NUM; i++) begin
//                         if (cdb_entry_alu.phys_d_reg == load_rs[i].phys_r1) begin
//                             load_rs[i].phys_r1_valid <= 1'b1;
//                         end
//                     end 

//                     if (cdb_entry_mult.valid) begin
//                     // for (int i = 0; i < ALU_RS_NUM; i++) begin
//                         if (cdb_entry_mult.phys_d_reg == load_rs[i].phys_r1) begin
//                             load_rs[i].phys_r1_valid <= 1'b1;
//                         end
//                     end 

//                     if (cdb_entry_mem.valid) begin
//                         if (cdb_entry_mem.phys_d_reg == load_rs[i].phys_r1) begin
//                             load_rs[i].phys_r1_valid <= 1'b1;
//                         end
//                     end
//                 end
//             end
//         end
//     end

//     assign cdb_entry_mem_out = cdb_entry_mem;

//     always_comb begin
//         rs_full = '1;
//         for (int i = 0; i < LOAD_RS_SIZE; i++) begin
//             if (load_rs[i].finished == 1'b1) begin
//                 rs_full = '0;
//                 break;
//             end 
//         end
//     end

//     assign rs_load_full = rs_full;




// endmodule