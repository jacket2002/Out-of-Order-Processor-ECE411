module cache_decode
import params::*;
import rv32i_types::*;
 (
    input   logic   [31:0]  ufp_addr,
    input   logic   [3:0]   ufp_rmask,
    input   logic   [3:0]   ufp_wmask,
    input   logic   [31:0]  ufp_wdata,
    input   logic [LOAD_RS_INDEX_BITS-1:0] index_write,
    

    output dec_exec d_e_next

);


logic [255:0] data_no_shift;
logic [31:0] write_no_shift, read_no_shift;

logic [4:0] mask_shift_val;
logic [7:0] write_shift_val;

assign d_e_next.small_w = ufp_wmask;
assign d_e_next.wd_small = ufp_wdata;
assign d_e_next.tag = ufp_addr[31:9];
assign d_e_next.set_idx = ufp_addr[8:5];
assign d_e_next.offset = ufp_addr[4:0];
assign d_e_next.chip_select = !(ufp_wmask[0] || ufp_wmask[1] || ufp_wmask[2] || ufp_wmask[3] || ufp_rmask[0] || ufp_rmask[1] || ufp_rmask[2] || ufp_rmask[3]);
assign d_e_next.write_enable = !(ufp_wmask[0] || ufp_wmask[1] || ufp_wmask[2] || ufp_wmask[3]);
assign d_e_next.write_mask = 'x;
assign d_e_next.write_data = 'x;
assign d_e_next.addr = ufp_addr;
assign d_e_next.read_mask = ufp_rmask;
assign d_e_next.index = index_write;


endmodule
