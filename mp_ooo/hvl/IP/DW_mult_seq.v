////////////////////////////////////////////////////////////////////////////////
//
//       This confidential and proprietary software may be used only
//     as authorized by a licensing agreement from Synopsys Inc.
//     In the event of publication, the following notice is applicable:
//
//                    (C) COPYRIGHT 2002 - 2021 SYNOPSYS INC.
//                           ALL RIGHTS RESERVED
//
//       The entire notice above must be reproduced on all authorized
//     copies.
//
// AUTHOR:    Aamir Farooqui                February 12, 2002
//
// VERSION:   Verilog Simulation Model for DW_mult_seq
//
// DesignWare_version: c7060fd6
// DesignWare_release: R-2020.09-DWBB_202009.4
//
////////////////////////////////////////////////////////////////////////////////

//------------------------------------------------------------------------------
//
//ABSTRACT:  Sequential Multiplier 
// Uses modeling functions from DW_Foundation.
//
//MODIFIED:
// 2/26/16 LMSU Updated to use blocking and non-blocking assigments in
//              the correct way
// 8/06/15 RJK Update to support VCS-NLP
// 2/06/15 RJK  Updated input change monitor for input_mode=0 configurations to better
//             inform designers of severity of protocol violations (STAR 9000851903)
// 5/20/14 RJK  Extended corruption of output until next start for configurations
//             with input_mode = 0 (STAR 9000741261)
// 9/25/12 RJK  Corrected data corruption detection to catch input changes
//             during the first cycle of calculation (related to STAR 9000505348)
// 1/5/12 RJK Change behavior when inputs change during calculation with
//          input_mode = 0 to corrupt output (STAR 9000505348)
//
//------------------------------------------------------------------------------

module DW_mult_seq ( clk, rst_n, hold, start, a,  b, complete, product);


// parameters 

  parameter  integer a_width     = 3; 
  parameter  integer b_width     = 3;
  parameter  integer tc_mode     = 0;
  parameter  integer num_cyc     = 3;
  parameter  integer rst_mode    = 0;
  parameter  integer input_mode  = 1;
  parameter  integer output_mode = 1;
  parameter  integer early_start = 0;
 
//-----------------------------------------------------------------------------

// ports 
  input clk, rst_n;
  input hold, start;
  input [a_width-1:0] a;
  input [b_width-1:0] b;

  output complete;
  output [a_width+b_width-1:0] product;

//-----------------------------------------------------------------------------
// synopsys translate_off

localparam signed [31:0] CYC_CONT = (input_mode==1 & output_mode==1 & early_start==0)? 3 :
                                    (input_mode==early_start & output_mode==0)? 1 : 2;

//-------------------Integers-----------------------
  integer count;
  integer next_count;
 

//-----------------------------------------------------------------------------
// wire and registers 

  wire clk, rst_n;
  wire hold, start;
  wire [a_width-1:0] a;
  wire [b_width-1:0] b;
  wire complete;
  wire [a_width+b_width-1:0] product;

  wire [a_width+b_width-1:0] temp_product;
  reg [a_width+b_width-1:0] ext_product;
  reg [a_width+b_width-1:0] next_product;
  wire [a_width+b_width-2:0] long_temp1,long_temp2;
  reg [a_width-1:0]   in1;
  reg [b_width-1:0]   in2;
  reg [a_width-1:0]   next_in1;
  reg [b_width-1:0]   next_in2;
 
  wire [a_width-1:0]   temp_a;
  wire [b_width-1:0]   temp_b;

  wire start_n;
  wire hold_n;
  reg ext_complete;
  reg next_complete;
 


//-----------------------------------------------------------------------------
  
  
 
  initial begin : parameter_check
    integer param_err_flg;

    param_err_flg = 0;
    
    
    if (b_width < 3) begin
      param_err_flg = 1;
      $display(
	"ERROR: %m :\n  Invalid value (%d) for parameter b_width (lower bound: 3)",
	b_width );
    end
    
    if ( (a_width < 3) || (a_width > b_width) ) begin
      param_err_flg = 1;
      $display(
	"ERROR: %m :\n  Invalid value (%d) for parameter a_width (legal range: 3 to b_width)",
	a_width );
    end
    
    if ( (num_cyc < 3) || (num_cyc > a_width) ) begin
      param_err_flg = 1;
      $display(
	"ERROR: %m :\n  Invalid value (%d) for parameter num_cyc (legal range: 3 to a_width)",
	num_cyc );
    end
    
    if ( (tc_mode < 0) || (tc_mode > 1) ) begin
      param_err_flg = 1;
      $display(
	"ERROR: %m :\n  Invalid value (%d) for parameter tc_mode (legal range: 0 to 1)",
	tc_mode );
    end
    
    if ( (rst_mode < 0) || (rst_mode > 1) ) begin
      param_err_flg = 1;
      $display(
	"ERROR: %m :\n  Invalid value (%d) for parameter rst_mode (legal range: 0 to 1)",
	rst_mode );
    end
    
    if ( (input_mode < 0) || (input_mode > 1) ) begin
      param_err_flg = 1;
      $display(
	"ERROR: %m :\n  Invalid value (%d) for parameter input_mode (legal range: 0 to 1)",
	input_mode );
    end
    
    if ( (output_mode < 0) || (output_mode > 1) ) begin
      param_err_flg = 1;
      $display(
	"ERROR: %m :\n  Invalid value (%d) for parameter output_mode (legal range: 0 to 1)",
	output_mode );
    end
    
    if ( (early_start < 0) || (early_start > 1) ) begin
      param_err_flg = 1;
      $display(
	"ERROR: %m :\n  Invalid value (%d) for parameter early_start (legal range: 0 to 1)",
	early_start );
    end
    
    if ( (input_mode===0 && early_start===1) ) begin
      param_err_flg = 1;
      $display(
	"ERROR: %m : Invalid parameter combination: when input_mode=0, early_start=1 is not possible" );
    end

  
    if ( param_err_flg == 1) begin
      $display(
        "%m :\n  Simulation aborted due to invalid parameter value(s)");
      $finish;
    end

  end // parameter_check 


//------------------------------------------------------------------------------

  assign start_n      = ~start;
  assign complete     = ext_complete & start_n;

  assign temp_a       = (in1[a_width-1])? (~in1 + 1'b1) : in1;
  assign temp_b       = (in2[b_width-1])? (~in2 + 1'b1) : in2;
  assign long_temp1   = temp_a*temp_b;
  assign long_temp2   = ~(long_temp1 - 1'b1);
  assign temp_product = (tc_mode)? (((in1[a_width-1] ^ in2[b_width-1]) && (|long_temp1))?
                                {1'b1,long_temp2} : {1'b0,long_temp1}) : in1*in2;

// Begin combinational next state assignments
  always @ (start or hold or a or b or count or in1 or in2 or
            temp_product or ext_product or ext_complete) begin
    if (start === 1'b1) begin                     // Start operation
      next_in1      = a;
      next_in2      = b;
      next_count    = 0;
      next_complete = 1'b0;
      next_product  = {a_width+b_width{1'bX}};
    end else if (start === 1'b0) begin            // Normal operation
      if (hold === 1'b0) begin
        if (count >= (num_cyc+CYC_CONT-4)) begin
          next_in1      = in1;
          next_in2      = in2;
          next_count    = count; 
          next_complete = 1'b1;
          next_product  = temp_product;
        end else if (count === -1) begin
          next_in1      = {a_width{1'bX}};
          next_in2      = {b_width{1'bX}};
          next_count    = -1; 
          next_complete = 1'bX;
          next_product  = {a_width+b_width{1'bX}};
        end else begin
          next_in1      = in1;
          next_in2      = in2;
          next_count    = count+1; 
          next_complete = 1'b0;
          next_product  = {a_width+b_width{1'bX}};
        end
      end else if (hold === 1'b1) begin           // Hold operation
        next_in1      = in1;
        next_in2      = in2;
        next_count    = count; 
        next_complete = ext_complete;
        next_product  = ext_product;
      end else begin                              // hold == x
        next_in1      = {a_width{1'bX}};
        next_in2      = {b_width{1'bX}};
        next_count    = -1;
        next_complete = 1'bX;
        next_product  = {a_width+b_width{1'bX}};
      end
    end else begin                                // start == x
      next_in1      = {a_width{1'bX}};
      next_in2      = {b_width{1'bX}};
      next_count    = -1;
      next_complete = 1'bX;
      next_product  = {a_width+b_width{1'bX}};
    end
  end
// end combinational next state assignments

generate
  if (rst_mode == 0) begin : GEN_RM_EQ_0

  // Begin sequential assignments
    always @ ( posedge clk or negedge rst_n ) begin: ar_register_PROC
      if (rst_n === 1'b0) begin                   // initialize everything asyn reset
        count        <= 0;
        in1          <= 0;
        in2          <= 0;
        ext_product  <= 0;
        ext_complete <= 0;
      end else if (rst_n === 1'b1) begin          // rst_n == 1
        count        <= next_count;
        in1          <= next_in1;
        in2          <= next_in2;
        ext_product  <= next_product;
        ext_complete <= next_complete & start_n;
      end else begin                              // rst_n == X
        in1          <= {a_width{1'bX}};
        in2          <= {b_width{1'bX}};
        count        <= -1;
        ext_product  <= {a_width+b_width{1'bX}};
        ext_complete <= 1'bX;
      end 
   end // ar_register_PROC

  end else  begin : GEN_RM_NE_0

  // Begin sequential assignments
    always @ ( posedge clk ) begin: sr_register_PROC 
      if (rst_n === 1'b0) begin                   // initialize everything asyn reset
        count        <= 0;
        in1          <= 0;
        in2          <= 0;
        ext_product  <= 0;
        ext_complete <= 0;
      end else if (rst_n === 1'b1) begin          // rst_n == 1
        count        <= next_count;
        in1          <= next_in1;
        in2          <= next_in2;
        ext_product  <= next_product;
        ext_complete <= next_complete & start_n;
      end else begin                              // rst_n == X
        in1          <= {a_width{1'bX}};
        in2          <= {b_width{1'bX}};
        count        <= -1;
        ext_product  <= {a_width+b_width{1'bX}};
        ext_complete <= 1'bX;
      end 
   end // ar_register_PROC

  end
endgenerate

  wire corrupt_data;

generate
  if (input_mode == 0) begin : GEN_IM_EQ_0

    localparam [0:0] NO_OUT_REG = (output_mode == 0)? 1'b1 : 1'b0;
    reg [a_width-1:0] ina_hist;
    reg [b_width-1:0] inb_hist;
    wire next_corrupt_data;
    reg  corrupt_data_int;
    wire data_input_activity;
    reg  init_complete;
    wire next_alert1;
    integer change_count;

    assign next_alert1 = next_corrupt_data & rst_n & init_complete &
                                    ~start & ~complete;

    if (rst_mode == 0) begin : GEN_A_RM_EQ_0
      always @ (posedge clk or negedge rst_n) begin : ar_hist_regs_PROC
	if (rst_n === 1'b0) begin
	    ina_hist        <= a;
	    inb_hist        <= b;
	    change_count    <= 0;

	  init_complete   <= 1'b0;
	  corrupt_data_int <= 1'b0;
	end else begin
	  if ( rst_n === 1'b1) begin
	    if ((hold != 1'b1) || (start == 1'b1)) begin
	      ina_hist        <= a;
	      inb_hist        <= b;
	      change_count    <= (start == 1'b1)? 0 :
	                         (next_alert1 == 1'b1)? change_count + 1 : change_count;
	    end

	    init_complete   <= init_complete | start;
	    corrupt_data_int<= next_corrupt_data | (corrupt_data_int & ~start);
	  end else begin
	    ina_hist        <= {a_width{1'bx}};
	    inb_hist        <= {b_width{1'bx}};
	    change_count    <= -1;
	    init_complete   <= 1'bx;
	    corrupt_data_int <= 1'bX;
	  end
	end
      end
    end else begin : GEN_A_RM_NE_0
      always @ (posedge clk) begin : sr_hist_regs_PROC
	if (rst_n === 1'b0) begin
	    ina_hist        <= a;
	    inb_hist        <= b;
	    change_count    <= 0;
	  init_complete   <= 1'b0;
	  corrupt_data_int <= 1'b0;
	end else begin
	  if ( rst_n === 1'b1) begin
	    if ((hold != 1'b1) || (start == 1'b1)) begin
	      ina_hist        <= a;
	      inb_hist        <= b;
	      change_count    <= (start == 1'b1)? 0 :
	                         (next_alert1 == 1'b1)? change_count + 1 : change_count;
	    end

	    init_complete   <= init_complete | start;
	    corrupt_data_int<= next_corrupt_data | (corrupt_data_int & ~start);
	  end else begin
	    ina_hist        <= {a_width{1'bx}};
	    inb_hist        <= {b_width{1'bx}};
	    init_complete    <= 1'bx;
	    corrupt_data_int <= 1'bX;
	    change_count     <= -1;
	  end
	end
      end
    end // GEN_A_RM_NE_0

    assign data_input_activity =  (((a !== ina_hist)?1'b1:1'b0) |
				 ((b !== inb_hist)?1'b1:1'b0)) & rst_n;

    assign next_corrupt_data = (NO_OUT_REG | ~complete) &
                              (data_input_activity & ~start &
					~hold & init_complete);

`ifdef UPF_POWER_AWARE
  `protected
U>=0T_.31F]_Xc9]ELY-/U,L\KaB[^Q\-7AH8[)e3dZ(eP?9&dH>&),KFbN=)g<A
<f<D+:Y.<=MEXfSaIF8Oa.b73LN<BI4MC3UO;5A-f>.<g/TD]_8VUY7L<<3Y0J3Q
9a-O+V;?,/,K1P8U.]YD4X8DaeU[<DFHL#:P6QO_#YB7fQOO3\;Jda;ZSL>0T+FW
3-)4gUN+-_C_L(H_eQcX-@5\G(=a5I::)8_R]b26AgD8L2CE3d)A5J_M?@5:T:0O
YM61dTI96T=eR+72DQ7Ca_FQLL1P9cbTRIX@,?dLYZb]bZ>@E(\-/-_O/75ddA]I
->>\WE?:gB8^C?J[c^G0ABB28@O.S,7;dMU#JN\K#\e]7(GH,:Od@KF+WT_GP5KG
^/71W?>4350_E2N7f0+3e7;A:e9D#J5JEFNI:&)YSI)L@_/>IUNfdFJ@e^W4F2e/
7C:<ZW5HBg[MZS@B\cMGM9R.K@dI,^^\3OV^F^JI?(fdNOe[Y[;@8>eJV3+4Cfg.
LL,TX#HM1/gPW6f^T,;8750AgK@-Eb=GfLf8c6RD;)ALLG@QV;R/NS8&bbS_dOJ?
Q(b^,@)Z5/aZeBYCHH<HYS3b3&.&(.#&6\N)A(LR]Q&HJ[I58ZZJ[PYEV/KGgP>I
fTJW&YNPDA/Gf]JHZEgE#]=87\=K2dgWR4FE56^?bUa->K#@:M+-G<e.6GKDbU8M
6?9RK-b]fKbQE&SVcVSD;0,AO(#M.\S>R,E80@4F.^B<b,Q6bRUI,1d4QWRTGJ>c
.VEI>[B)2.CEYZcZB^01\ac:6YFG1#JY#&FO2INc>MN#2#9CNSf&EJ38,f=)65a7
S[U2JbdM?<bMU@DDH>CAN;HSA(U+CZ#.KXJUH>:ZVCM^[NHHOE6d_-#_WXQ5BRE>
1=3MJAPYVYKY^5f9)<Ldd,JDE+U&^A05:bAaOS>b&B^1.VU=L_^Be<0X(Y-,X\gI
<NJWa4]8?&c:Ad3U0WNE#-e-[gPY^XG@KK]L@YBQVbN<cbDaNG#9f<_:66-SXaU+
HY@;BZ+11c[ZQW6[aFfbIH6fQ\e\X><WL9.A9K,\,QJXR82_.fI5J;X4]_P8^)-@
X:&eC+D,f3<LWKgH7H2T[N;4^(0H68E=2=G2+a0XFfVa0^f6_K\#1U<#&Uf@<_X\
g(R);TP^HP@#;c^gC8Pa:=BZ/;/R1J=/(W@cEa9<TYAS]W^]&_..LF)&P=AL-QF]
8g3I+:;[@PUVD_7@eVG<H>8;\/M\)9HVYB9-VYU<KLdBNS2Oc#K1U(Rf[K6XOe12
[,N=g2?4UD47]d0/<S]=#WF/<6=b+EOV8:Bc.I45.f[2@DH\0_RD>Ab9:WG4SUb3
0@1;:f.(>F.;PA[X)?\./UTN6F>RT3_^dC^X\2B1R#J-SeZa=Q^U.N;+?HMK)U1S
K1X:165IW1V#g)54g+3?;;fSbaTZ<bMK_+fOQ9YST_K?U1fTA:aSTb<9g&PK</L3
Mb7fY+>,>@bTV>#d_]1&:J7FS>2b.39>,3=GdIQcY5)QOR=,Qf=9RL>TRH,#1bbX
@4+<C0+)(#L,<R>IC?R#fA48+-J;2KcH>1749(7XNJQ[Saa)#AF=f>C(#_<@/+/Z
O2CF^34T8=18a[KX[&_<4Z_N2IgC^QcSV&VN3-6AEJXUVH@2D>-00KA[/)25YD3^
C-Oc^\+PD-E#.5-[;BUDULc]7B2adVX&/F><DXZWDdW?BJFeYVHLMSd#&R3;X,Kb
HXW4-;/F@#VU&f&DP\,P+MOETOWM_]5EB[AM:B0aJ?5_P82VK@S57.=R8>=aYOD=
SIaUd&:S_PAO+SI>MESB-P2c(6RS8+V(A(;W=5EH/?ZcA(B1NAS/S^M2V8<4D6cG
/]BLE:&bc:(6.aOQ1E\9NX<EH6a[ff;1BA_[-P0KBZQAKQGT1]f+FCa:<E8eEVGa
#f>&K8W5dU\Hc(D.JB]b6FLR\(\?+VPEU,ggGM(YPFXMLDW^CBA;WF(C;R+PR?>W
T>d8?VH<VA5S_:J9/\4EeL+\M0/;M#@MIc<D^0>bV7YVWJ,;<0XFZ76E/)7[KbNI
)f[VI#WQCPF&;M9;N.ANFFbU;(0MOcZ?6.X=CNW9^1@(TSSZG\@a,,Q4MdYO>T>2
\&MTg#,a?4.a]ZHQ;=5IL]RA=:R6,:[2OTSN5gT#1>Q6eNd>=;I.X;T_F2A+L7,8
K#@\<\EbV(-</C+^Tg89^e->+5WI1TO>Y[,Rab>@BK?S1BCd&2<57QL?H2O&)#PG
J3QWC7Y\8.F5(F0Y@V_d1Mff9Y//D_I^af2OYZI89OM.)Jb+M@W2abM(B&.BAG>M
6c8BU<7GJA6I5\DRM6_#;2^5gQa[:N>H1;+cEBfJ8F#2S:;fJA?3])Fg@#1]0(e/
7S+08KT#H2_0g8-#2WK@B@W<L:Oe4Q8Ab>+O>O>K&HfBZ^_GAf4M^#><(]])<.74
,02SA?0a)LW+)#gQE^=G\)a<;F<VP2e@^94g2PJ9/F++4U0-,K2++]90]ac2WN5Z
YbfBCcJZ]&^fYOLXTB\Z=+)GSUW#c0J>[2S[Z;34#@gf))YNbdQ>FgNY&&/33d=d
4gId-C&>d/e</Y#a;Xa\;(87&VL4LR;9f2>IIZX/_5g)a8,;MIUE#UPW?>M._LO(
I<BM?LC+@[L<0$
`endprotected

`else
    always @ (posedge clk) begin : corrupt_alert_PROC
      integer updated_count;

      updated_count = change_count;

      if (next_alert1 == 1'b1) begin
`ifndef DW_SUPPRESS_WARN
          $display ("WARNING: %m:\n at time = %0t: Operand input change on DW_mult_seq during calculation (configured without an input register) will cause corrupted results if operation is allowed to complete.", $time);
`endif
	updated_count = updated_count + 1;
      end

      if (((rst_n & init_complete & ~start & ~complete & next_complete) == 1'b1) &&
          (updated_count > 0)) begin
	$display(" ");
	$display("############################################################");
	$display("############################################################");
	$display("##");
	$display("## Error!! : from %m");
	$display("##");
	$display("##    This instance of DW_mult_seq has encountered %0d change(s)", updated_count);
	$display("##    on operand input(s) after starting the calculation.");
	$display("##    The instance is configured with no input register.");
	$display("##    So, the result of the operation was corrupted.  This");
	$display("##    message is generated at the point of completion of");
	$display("##    the operation (at time %0d), separate warning(s) were", $time );
`ifndef DW_SUPPRESS_WARN
	$display("##    generated earlier during calculation.");
`else
	$display("##    suppressed earlier during calculation.");
`endif
	$display("##");
	$display("############################################################");
	$display("############################################################");
	$display(" ");
      end
    end
`endif

    assign corrupt_data = corrupt_data_int;

  if (output_mode == 0) begin : GEN_OM_EQ_0
    reg  alert2_issued;
    wire next_alert2;

    assign next_alert2 = next_corrupt_data & rst_n & init_complete &
                                     ~start & complete & ~alert2_issued;

`ifdef UPF_POWER_AWARE
  `protected
@E1<,@ZGOSH:W7V;[4SFNM8.:PG6>cL9MFF#0\E334:L2AY:?+Ee))e<cd0e;CV5
gd@+AGCP2]&g5D]9;-1P[ENe/dYJ(61U).@G0d:H2V?2fCa\&71g0J8]SO3;ZMTe
XM=-DB9Q^9W+5=aJJS=[J\K(FGV-)CUX4V+L(8HLO8fZZ.PR7P]38\0FV5XF0[)d
<B<T-@\gF2PcP>e.9?c+_\gAB6<5USL.<)[C-g,dCJbUCDIRL>fKFV//XN#.Hb/b
ASDA-I]D4\fR7/N0b>M6=<)]-TK3>^fN^dYNF:Q]g(JP3+PdP5[2Y<&-84RN.Fad
&?FAA>/B0+PE/K?3OZBf?T7L0QLHMTK2(OK;?/UJPRf:MfA_P=I&L&Z9GN?6X,G4
cZG\@YcL<J=]HK;^dZYUFXc?/0.P+O:\]@S[__1J4)VVD6]97?JOP/J95_4&M[2+
YIVNU#D/DReVdf,\15FCd#Q+fcP]ETbWFO-eP8Y?OM/OSP)T]MJHI?bKE,9d6Dc9
AQX_::RJdLYZ>^1R0<F]:/PbENeFe-2;K&DaIa_P4>)@;Eg9VSX+G[)Cc#JFBYcY
SF?OP:]BLF8+QDQPLDDC3@g(@9]R.H1LdU9=CU7=;4NM6YADESd9Q6EHMAYRILY_
VF5Q,^&1?b86MX/NX2M:9(P6==66;15P>$
`endprotected

`else
    always @ (posedge clk) begin : corrupt_alert2_PROC
      if (next_alert2 == 1'b1) begin
`ifndef DW_SUPPRESS_WARN
          $display ("WARNING: %m:\n at time = %0t: Operand input change on DW_mult_seq during calculation (configured with neither input nor output register) causes output to no longer retain result of previous operation.", $time);
`endif
      end
    end
`endif

    if (rst_mode == 0) begin : GEN_AI_REG_AR
      always @ (posedge clk or negedge rst_n) begin : ar_alrt2_reg_PROC
        if (rst_n == 1'b0) alert2_issued <= 1'b0;

	  else alert2_issued <= ~start & (alert2_issued | next_alert2);
      end
    end else begin : GEN_AI_REG_SR
      always @ (posedge clk) begin : sr_alrt2_reg_PROC
        if (rst_n == 1'b0) alert2_issued <= 1'b0;

	  else alert2_issued <= ~start & (alert2_issued | next_alert2);
      end
    end

  end  // GEN_OM_EQ_0

  // GEN_IM_EQ_0
  end else begin : GEN_IM_NE_0
    assign corrupt_data = 1'b0;
  end // GEN_IM_NE_0
endgenerate

  assign product      = ((((input_mode==0)&&(output_mode==0)) || (early_start == 1)) && start == 1'b1) ?
			  {a_width+b_width{1'bX}} :
                          (corrupt_data === 1'b0)? ext_product : {a_width+b_width{1'bX}};


 
`ifndef DW_DISABLE_CLK_MONITOR
`ifndef DW_SUPPRESS_WARN
  always @ (clk) begin : P_monitor_clk 
    if ( (clk !== 1'b0) && (clk !== 1'b1) && ($time > 0) )
      $display ("WARNING: %m:\n at time = %0t: Detected unknown value, %b, on clk input.", $time, clk);
    end // P_monitor_clk 
`endif
`endif
// synopsys translate_on

endmodule




