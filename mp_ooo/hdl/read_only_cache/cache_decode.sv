module cache_decode_read
import rv32i_types::*;
 (
    input   logic   [31:0]  ufp_addr,
    input   logic   [3:0]   ufp_rmask,
    input   logic   [3:0]   ufp_wmask,
    input   logic   [31:0]  ufp_wdata,
    

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
assign d_e_next.chip_select =  !(ufp_rmask[0] || ufp_rmask[1] || ufp_rmask[2] || ufp_rmask[3]);
assign d_e_next.write_enable = '0;
assign d_e_next.write_mask = '0;
assign d_e_next.write_data = '0;
assign d_e_next.addr = ufp_addr;
assign d_e_next.read_mask = ufp_rmask;


endmodule
