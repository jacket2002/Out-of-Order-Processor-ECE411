module cpu
import params::*;
import rv32i_types::*;
(
    input   logic               clk,
    input   logic               rst,

    output  logic   [31:0]      bmem_addr,
    output  logic               bmem_read,
    output  logic               bmem_write,
    output  logic   [63:0]      bmem_wdata,
    input   logic               bmem_ready,

    input   logic   [31:0]      bmem_raddr,
    input   logic   [63:0]      bmem_rdata,
    input   logic               bmem_rvalid


);



logic [31:0] imem_addr, imem_rdata, dmem_addr, dmem_rdata, dmem_wdata, dmem_dfp_addr, imem_dfp_addr;
logic imem_resp, dmem_resp, dfp_resp_write;

logic [3:0] imem_rmask, dmem_wmask, dmem_rmask;


logic [255:0]  dmem_dfp_rdata, dmem_dfp_wdata,  imem_dfp_rdata;

logic dmem_dfp_read, dmem_dfp_write, imem_dfp_read, dmem_dfp_resp, imem_dfp_resp;
logic [1:0] adapter_write_count;

logic dfp_read, dfp_write, dfp_resp, icache_serviced;
logic [31:0] dfp_addr, dfp_raddr, imem_dfp_raddr, dmem_dfp_raddr;
logic [255:0] dfp_wdata, dfp_rdata;



// always_comb begin


//      unique case (mem_state) 

//           SERVICING_ICACHE : begin

//                // lower bmem signals for i cache
//                if(dmem_dfp_write || dmem_dfp_read) begin

//                     next_mem_state = SERVICING_DCACHE;
//                     /*
//                          Drive bmem signals for d cache 


//                     */




//                end
//                else begin


//                end



//           end

     


//           SERVICING_DCACHE : begin



//           end 

//           IDLE : begin

//                // drive bmem signals for dcache or icache depending on which acquires being serviced  




//           end

//      endcase



//           if(dmem_dfp_write || dmem_dfp_read) begin



//           end
//           else begin


//           end
//      else if (mem_state == DCACHE) begin


//      end
//      else begin



//      end



// end

/*
    input logic clk,
    input logic rst,

    // mem signals
    output logic [31:0] imem_addr, dmem_addr, dmem_wdata,
    output logic [3:0] imem_rmask, dmem_rmask, dmem_wmask,

    input logic [31:0] imem_rdata, dmem_rdata,
    input logic imem_resp, dmem_resp
*/
logic [STORE_QUEUE_PTR_WIDTH-1:0] dcache_store_idx;
logic [LOAD_RS_INDEX_BITS-1:0] dcache_load_idx, index_resp, index_write;
logic ready, dmem_resp_type, dcache_serviced;

always_comb begin
     dcache_load_idx = index_resp;
     dcache_store_idx = index_resp[STORE_QUEUE_PTR_WIDTH-1:0];

end





ERR_CORE ball_core (

     .clk (clk),
     .rst(rst),

     .imem_addr(imem_addr), 
     .imem_rmask(imem_rmask),
     .imem_rdata(imem_rdata),
     // .imem_rdata(bmem_rdata[31:0]),
     .imem_resp(imem_resp),

     .dmem_addr(dmem_addr),
     .dmem_rmask(dmem_rmask),
     .dmem_wmask(dmem_wmask),
     .dmem_rdata(dmem_rdata),
     .dmem_wdata(dmem_wdata),
     .dmem_resp(dmem_resp),
     .dmem_ready(ready),
     .dcache_load_idx(dcache_load_idx),
     .dcache_store_idx(dcache_store_idx),
     .index_write(index_write),
     .dmem_resp_type(dmem_resp_type)


    
);


non_blocking_cache D_CACHE(

     .clk (clk),
     .rst (rst),
     .ufp_addr(dmem_addr),
     .ufp_rmask(dmem_rmask),
     .ufp_wmask(dmem_wmask),
     .ufp_rdata(dmem_rdata),
     .ufp_wdata(dmem_wdata),
     .ufp_resp(dmem_resp),

     .dfp_addr(dmem_dfp_addr),
     .dfp_read (dmem_dfp_read),
     .dfp_write (dmem_dfp_write),
     .dfp_rdata (dmem_dfp_rdata),
     .dfp_wdata (dmem_dfp_wdata),
     .dfp_resp (dmem_dfp_resp),
     .dcache_serviced(dcache_serviced),
     .dfp_raddr(dmem_dfp_raddr), 
     .dfp_resp_write(dfp_resp_write),
     .index_resp(index_resp),
     .index_write(index_write),
     .dmem_resp_type(dmem_resp_type),
     .ready(ready)
);



cache_read I_CACHE(

     .clk (clk),
     .rst(rst),
     .ufp_addr(imem_addr),
     .ufp_rmask(imem_rmask),
     .ufp_wmask('0),
     .ufp_rdata(imem_rdata),
     .ufp_wdata('x),
     .ufp_resp(imem_resp),

     .dfp_addr(imem_dfp_addr),
     .dfp_read (imem_dfp_read),
     .dfp_write (),
     .dfp_rdata (imem_dfp_rdata),
     .dfp_wdata (),
     .dfp_resp (imem_dfp_resp),
     .icache_serviced(icache_serviced)
);

cache_arbiter cache_arbiter_0 (
     .clk(clk),
     .rst(rst),
     .imem_dfp_raddr(),
     .dmem_dfp_raddr(dmem_dfp_raddr),
     .imem_dfp_read_after(icache_serviced),
     .dfp_resp_write(dfp_resp_write),
     .*
);


cacheline_adapter cacheline_adapter (

     .clk(clk),
     .rst(rst),

     .addr(bmem_addr),
     .read(bmem_read),
     .write(bmem_write),
     .wdata(bmem_wdata), 
     .ready(bmem_ready),
     // .adapter_write_count(adapter_write_count),
     .raddr(bmem_raddr),
     .rdata(bmem_rdata), 
     .rvalid(bmem_rvalid),

     .*
     // === dfp signals ===

     // .dfp_addr(imem_dfp_addr),
     // .dfp_read(imem_dfp_read),
     // .dfp_write('0),
     // .dfp_wdata('x),

     // .dfp_rdata(imem_dfp_rdata), 
     // .dfp_raddr(),
     // .dfp_resp(imem_dfp_resp)
); 





endmodule : cpu
