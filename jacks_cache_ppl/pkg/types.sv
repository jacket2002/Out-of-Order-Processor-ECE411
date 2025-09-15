package ppl_cache_types;


 typedef struct packed {


    logic [31:0] addr;
    logic [22:0] tag;
    logic [3:0]  set;
    logic [4:0]  offset;
    logic chip_select;
    logic write_enable; //active low
    logic [32:0] write_mask ; // active high
    logic [255:0] write_data;
    logic [3:0] read_mask;
    logic [3:0] small_w;

    logic [31:0] wd_small;


    



 } dec_exec;



   typedef enum logic [2:0] {
        idle       = 3'b000,
        miss = 3'b011,
        dirty  = 3'b100,
        done   = 3'b101,
        idle_d_a = 3'b111
 
   
   } state_types;




endpackage