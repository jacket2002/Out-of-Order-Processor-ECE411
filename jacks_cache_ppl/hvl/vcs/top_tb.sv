module top_tb;
    //---------------------------------------------------------------------------------
    // Waveform generation.
    //---------------------------------------------------------------------------------
    

    //---------------------------------------------------------------------------------
    // TODO: Declare cache port signals:
    //---------------------------------------------------------------------------------

    logic [31:0] addr;
    logic [3:0] r_mask;
    logic [3:0] w_mask;
    logic [31:0] rdata;
    logic [31:0] wdata;
    logic  ufp_resp;



    //---------------------------------------------------------------------------------
    // TODO: Generate a clock:
    //---------------------------------------------------------------------------------

    bit clk;

    initial clk = 1'b1;
    always #2ns clk = ~clk;
    bit rst;
    int timeout = 10000000;

    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, "+all");
        rst = 1'b1;
        repeat (2) @(posedge clk);
        rst <= 1'b0;
    end
    mem_itf_wo_mask mem_itf(.*);
    simple_memory_256_wo_mask simple_memory(.itf(mem_itf)); 

    //---------------------------------------------------------------------------------
    // TODO: Write a task to generate reset:
    //---------------------------------------------------------------------------------


    //---------------------------------------------------------------------------------
    // TODO: Instantiate the DUT and physical memory:
    //---------------------------------------------------------------------------------
    
    cache dut(

    .clk(clk),
    .rst(rst),

    .ufp_addr(addr),
    .ufp_rmask(r_mask),
    .ufp_wmask(w_mask),
    .ufp_rdata(rdata),
    .ufp_wdata(wdata),
    .ufp_resp(ufp_resp),


    .dfp_addr(mem_itf.addr [0]),
    .dfp_read(mem_itf.read[0] ),
    .dfp_write(mem_itf.write[0]),
    .dfp_rdata(mem_itf.rdata[0]),
    .dfp_wdata(mem_itf.wdata[0]),
    .dfp_resp(mem_itf.resp [0])

    );




    
    

    //---------------------------------------------------------------------------------
    // TODO: Write tasks to test various functionalities:
    //---------------------------------------------------------------------------------
    
    //   tage : 0000 0000 0000 0000 0000 000   set : 0000    offset : 00000
    
    int i;
        int  j;
    

        task stimulus2();
        

        logic [31:0] dont_care_addr, temp;

           int i;

        dont_care_addr = 'x; 
        addr = '0;
        temp = addr;
        r_mask = 4'b0000;
        w_mask = 4'b0000;
        wdata = 'x;
        repeat(2) @(posedge clk);



        j =1;

        for (i = 0; i<16; ++i) begin

           
            r_mask = 4'b0000;
            w_mask = 4'b1111;
            wdata = 'd4;
            
             @(posedge clk);

             addr = dont_care_addr;
             w_mask = '0;
             wdata = 'x;

             @(posedge clk iff ufp_resp);
              temp = temp + (32'h00000020);
            addr = temp;

            
      
        end

        temp = '0;
        temp = temp+512*j;
        addr = temp;
        j =2;

        for (i = 0; i<16; ++i) begin

            r_mask = 4'b0000;
            w_mask = 4'b1111;
            wdata = 'd4;
            
             @(posedge clk);

             addr = dont_care_addr;
             w_mask = '0;
             wdata = 'x;

             @(posedge clk iff ufp_resp);
              temp = temp + (32'h00000020);
            addr = temp;

            
      
        end

        temp = '0;
        temp = temp+512*j;
        addr = temp;
        j =3;


        for (i = 0; i<16; ++i) begin

            r_mask = 4'b0000;
            w_mask = 4'b1111;
            wdata = 'd4;
            
             @(posedge clk);

             addr = dont_care_addr;
             w_mask = '0;
             wdata = 'x;

             @(posedge clk iff ufp_resp);
              temp = temp + (32'h00000020);
            addr = temp;
            
      
        end


        temp = '0;
        temp = temp+512*j;
        addr = temp;


        for (i = 0; i<16; ++i) begin

            r_mask = 4'b0000;
            w_mask = 4'b1111;
            wdata = 'd4;
            
             @(posedge clk);

             addr = dont_care_addr;
             w_mask = '0;
             wdata = 'x;

             @(posedge clk iff ufp_resp);
              temp = temp + (32'h00000020);
            addr = temp;
            
      
        end






             dont_care_addr = 'x; 
        addr = '0;
        temp = addr;
        r_mask = 4'b0000;
        w_mask = 4'b0000;
        wdata = 'x;
        repeat(2) @(posedge clk);



        j =1;

        for (i = 0; i<16; ++i) begin

           
            r_mask = 4'b1111;
            w_mask = 4'b0000;
            
             @(posedge clk);

             
              temp = temp + (32'h00000020);
            addr = temp;

            
      
        end

        temp = '0;
        temp = temp+512*j;
        addr = temp;
        j =2;

        for (i = 0; i<16; ++i) begin

            r_mask = 4'b1111;
            w_mask = 4'b0000;
            
             @(posedge clk);

        
              temp = temp + (32'h00000020);
            addr = temp;

            
      
        end

        temp = '0;
        temp = temp+512*j;
        addr = temp;
        j =3;


        for (i = 0; i<16; ++i) begin

            r_mask = 4'b1111;
            w_mask = 4'b0000;
            
             @(posedge clk);

          
              temp = temp + (32'h00000020);
            addr = temp;
            
      
        end


        temp = '0;
        temp = temp+512*j;
        addr = temp;


        for (i = 0; i<16; ++i) begin

            r_mask = 4'b1111;
            w_mask = 4'b0000;
            
            @(posedge clk);

         
            temp = temp + (32'h00000020);
            addr = temp;

            
      
        end

        r_mask = 4'b0000;
        w_mask = 4'b1111;
        addr = 'h00000FE0;
        wdata = 'd4;


        @(posedge clk );

        r_mask = 4'b0000;
        w_mask = 4'b0000;
        addr = 'x;
        wdata = 'x;

        @(posedge clk iff ufp_resp);

        r_mask = 4'b0000;
        w_mask = 4'b1111;
        addr = 'h00000FE0;
        wdata = 'd4;


        @(posedge clk );

           r_mask = 4'b0000;
        w_mask = 4'b1111;
        addr = 'h00000FE0;
        wdata = 'd4;


        @(posedge clk );

           r_mask = 4'b1111;
        w_mask = 4'b0000;
        addr = 'h00000FE0;
        wdata = 'x;


        @(posedge clk );










        


     




    endtask : stimulus2


    //---------------------------------------------------------------------------------
    // TODO: Main initial block that calls your tasks, then calls $finish
    //---------------------------------------------------------------------------------

    initial begin
        // stimulus(
        //    addr, r_mask, w_mask, wdata
        // );

        // #500ns;

        // stimulus2(
        //    addr, r_mask, w_mask, wdata
        // );
        // #100ns
 repeat(2) @(posedge clk);

        stimulus2();



        #300ns;

        $finish;

    end




      always @(posedge clk) begin
     
        if (timeout == 0) begin
            $error("TB Error: Timed out");
            $fatal;
        end
        if (mem_itf.error != 0) begin
            repeat (2) @(posedge clk);
            $fatal;
        end
        timeout <= timeout - 1;
    end

endmodule : top_tb
