module load_buffer
import rv32i_types::*;
import params::*;
(

    input logic [31:0] load_addr,

    input logic [ROB_DEPTH] rob_pointer,

    input logic [3:0] rmask, wmask,

    input logic load_we,

    input logic [31:0] store_addr,

    input logic store_we,

    output logic [31:0] dmem_addr,

    output  logic [3:0] dmem_wmask, dmem_rmask, dmem_wdata,

    input logic [31:0] dmem_rdata, dmem_raddr,

    input logic dmem_resp,

    output cdb_entry_t cdb_load

);

// make load buffer different size, and store typical things inside of rob entry

load_state_types load_state;

logic [LOAD_BUFFER_DATA-1:0] mem_load [LOAD_BUFFER_SIZE]; // we need extra bit for finished

logic [STORE_BUFFER_DATA-1:0] mem_store [STORE_BUFFER_SIZE]; // we need extra bit for finished

logic [36:0] temp, temp1, temp2;


// write for loads 
logic [LOAD_BUFFER_SIZE] load_write_new_i, store_write_new_i;
logic found_space_load, found_space_store;
always_ff @(posedge clk) begin

    if(rst) begin

        for(int unsigned i = 0; i< (LOAD_BUFFER_SIZE); i++)begin
            mem_load[i] <= '0;
        end
        
    end

    // change to comn
    else if(found_space_load) begin 

        mem_load[load_write_new_i] <= {rob_pointer, 1'b1, rmask, load_addr};
    end

    if() begin


    end
end

always_comb begin

    found_space_load = '0;

     if(rst) begin

        for(int unsigned i = 0; i< (LOAD_BUFFER_SIZE); i++)begin
            mem_store[i] <= '0;
        end
        
    end


    if(load_we) begin 
        for(int unsigned i = 0; i< (LOAD_BUFFER_SIZE); i++) begin
            temp = mem_load[i];
            
            if(!temp[36]) begin
                found_space_load = '1;
                load_write_new_i = i;
                break;
            end
        end
    end

    if(resp_we_load) begin
        //update bit

    end


end


// write for stores

always_ff @(posedge clk) begin

    if(rst) begin

        for(int unsigned i = 0; i< (STORE_BUFFER_SIZE); i++)begin
            mem_store[i] <= '0;
        end
        
    end
    else if(found_space_store) begin 

        mem_load[store_write_new_i] <= {rob_pointer, 1'b1, wmask, store_addr};
    end

    if() begin


    end

end

always_comb begin

    found_space_store = '0;
    if(store_we) begin 
        for(int unsigned i = 0; i< (STORE_BUFFER_SIZE); i++) begin
            temp1 = mem_store[i];
            if(!temp1[36]) begin
                found_space_store = '1;
                store_write_new_i = i;
                break;
            end

        end
    end

    if(resp_we_store) begin
        //update bit

    end

end




// our service 
always_ff @(posedge clk) begin

    if(rst) begin

        dmem_addr <= 'x;
        dmem_wdata <= 'x;
        dmem_wmask <= '0;
        dmem_rmask <= '0;
        load_state <= search_load;

    end
    else begin

        
    end

end

logic [31:0] dmem_addr_next, cdb_rdata;
logic [3:0] dmem_wmask_next, dmem_rmask_next;

logic [LOAD_BUFFER_SIZE] load_index_next, load_index;

logic [STORE_BUFFER_SIZE] store_index_next, store_index;

logic resp_we_load, resp_we_store, cdb_initiate_next, cdb_initiate;

always_comb begin
        
        cdb_iniate_next = '0;

        resp_we_load = '0;
        unique case (load_state)

            search_load :  begin

                next_state = search_store;

                for(int unsigned i = 0; i< (LOAD_BUFFER_SIZE); i++) begin
                    temp2 = mem_load[i];
                    if(temp2[36]) begin
                        dmem_addr_next = temp2[31:0];
                        dmem_rmask_next = temp2[35:32];
                        dmem_wmask_next = '0;
                        next_state = wait_resp_load;
                        break;
                    end
                end

            end

            search_store :  begin

                next_state = search_store;

                for(int unsigned i = 0; i< (STORE_BUFFER_SIZE); i++) begin
                    temp2 = mem_store[i];
                    if(temp2[36]) begin
                        dmem_addr_next = temp2[31:0];
                        dmem_wmask_next = temp2[35:32];
                        dmem_rmask_next = '0;
                        next_state = wait_resp_store;
                        break;
                    end
                end



            end


            wait_resp_load : begin

                next_state = wait_resp_load;
              

                if(dmem_resp) begin

                    resp_we_load = '1;
                    load_index_next = '0;
                    dmem_rdata_next
                    next_state = search_load;
                    cdb_initiate_next = '1;

                  for(int unsigned i = 0; i< (STORE_BUFFER_SIZE); i++) begin
                        temp2 = mem_store[i];
                        if(temp2[36]) begin
                            dmem_addr_next = temp2[31:0];
                            dmem_rmask_next = temp2[35:32];
                            dmem_wmask_next = '0;
                            next_state = wait_resp_store;
                            break;
                        end
                  end

                end

                end


            wait_resp_store : begin


                 next_state = wait_resp_load;

                if(dmem_resp) begin
                    resp_we_store = '1;
                    store_index_next = '0;
                    next_state = search_store;
                  // have the critical path so may as well search and use pipeline
                    for(int unsigned i = 0; i< (LOAD_BUFFER_SIZE); i++) begin
                        temp2 = mem_load[i];
                        if(temp2[36]) begin
                            dmem_addr_next = temp2[31:0];
                            dmem_rmask_next = temp2[35:32];
                            dmem_wmask_next = '0;
                            next_state = wait_resp_load;
                            break;
                        end
                    end
                end



            end

        endcase 


end


   typedef struct packed {

      logic valid;
      logic [ROB_DEPTH] rob_pointer;
      logic [3:0] ps1;
      logic [3:0] ps2;
      logic [31:0] rd_v;

      
   } cdb_entry_t;

// cdb load stuff
always_ff @ (posedge clk) begin




    if(cdb_iniate) begin

        cdb_load.valid = '1;
        cdb_load.rob_pointer = data[LOAD_STORE_BUFFER_DATA-1 : LOAD_STORE_BUFFER_DATA-ROB_DEPTH];




    end






end





















endmodule