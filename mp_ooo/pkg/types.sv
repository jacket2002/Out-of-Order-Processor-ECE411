package params;
   // localparam PHYSICAL_REG_FILE_DEPTH = 128;
   localparam PHYSICAL_REG_FILE_LENGTH = 6; // will be the exponent
   localparam INSTRUCTION_QUEUE_DEPTH = 8;
   localparam ROB_DEPTH = 16;
   localparam ROB_PTR_WIDTH = $clog2(ROB_DEPTH);
   localparam ROB_ENTRY_WIDTH = 1 + PHYSICAL_REG_FILE_LENGTH + 5;
   localparam PHYSICAL_REG_WIDTH = PHYSICAL_REG_FILE_LENGTH;
   localparam PHYSICAL_REG_NUM = ROB_DEPTH + 32;
   localparam ALU_RS_NUM = 4;
   localparam ALU_RS_INDEX_BITS = $clog2(ALU_RS_NUM);
   localparam MULT_RS_NUM = 4;
   localparam MULT_RS_INDEX_BITS = $clog2(MULT_RS_NUM);
   localparam BR_RS_NUM = 2;
   localparam BR_RS_INDEX_BITS = $clog2(BR_RS_NUM);
   localparam MEM_RS_NUM = 3;
   localparam MEM_RS_INDEX_BITS = $clog2(MEM_RS_NUM);
   localparam MEM_QUEUE_DEPTH = 8;
   // localparam MEM_QUEUE_PTR_WIDTH = $clog2(MEM_QUEUE_DEPTH);
   localparam FREE_LIST_QUEUE_LENGTH = PHYSICAL_REG_NUM - 32;

   // separate load store queue paramters 
   localparam ADDR_RS_NUM = 13;
   localparam ADDR_RS_INDEX_BITS = $clog2(ADDR_RS_NUM);
   localparam LOAD_RS_NUM = 5;
   localparam LOAD_RS_INDEX_BITS = $clog2(LOAD_RS_NUM);
   localparam STORE_QUEUE_DEPTH = 8;
   localparam STORE_QUEUE_PTR_WIDTH = $clog2(STORE_QUEUE_DEPTH);
   localparam MEM_QUEUE_PTR_WIDTH = STORE_QUEUE_PTR_WIDTH;
   localparam FORWARD_MAP_SIZE = 4;
   localparam FORWARD_MAP_PTR_SIZE = $clog2(FORWARD_MAP_SIZE);
   localparam FREE_LIST_PTR_WIDTH = $clog2(FREE_LIST_QUEUE_LENGTH);
   localparam CONTROL_Q_DEPTH = 4;
   localparam CONTROL_Q_PTR_WIDTH = $clog2(CONTROL_Q_DEPTH);
endpackage

package rv32i_types;
   import params::*;
   typedef enum logic [2:0] {
      arith_f3_add   = 3'b000, // check logic 30 for sub if op_reg op
      arith_f3_sll   = 3'b001,
      arith_f3_slt   = 3'b010,
      arith_f3_sltu  = 3'b011,
      arith_f3_xor   = 3'b100,
      arith_f3_sr    = 3'b101, // check logic 30 for logical/arithmetic
      arith_f3_or    = 3'b110,
      arith_f3_and   = 3'b111
   } arith_f3_t;

   typedef enum logic [2:0] {
      alu_op_add     = 3'b000,
      alu_op_sll     = 3'b001,
      alu_op_sra     = 3'b010,
      alu_op_sub     = 3'b011,
      alu_op_xor     = 3'b100,
      alu_op_srl     = 3'b101,
      alu_op_or      = 3'b110,
      alu_op_and     = 3'b111
   } alu_ops_t;

   typedef enum logic [2:0] {
      load_f3_lb     = 3'b000,
      load_f3_lh     = 3'b001,
      load_f3_lw     = 3'b010,
      load_f3_lbu    = 3'b100,
      load_f3_lhu    = 3'b101
   } load_f3_t;

   typedef enum logic [2:0] {
      store_f3_sb    = 3'b000,
      store_f3_sh    = 3'b001,
      store_f3_sw    = 3'b010
   } store_f3_t;

   typedef enum logic [2:0] {
      m_mul          = 3'b000,
      m_mulh         = 3'b001,
      m_mulhsu       = 3'b010,
      m_mulhu        = 3'b011,
      m_div          = 3'b100,
      m_divu         = 3'b101,
      m_rem          = 3'b110,
      m_remu         = 3'b111
   } m_extension_f3_t;
    typedef enum logic [2:0] {
        idle_n = 3'b000,
        allocate   = 3'b101,
        idle_d_a_n = 3'b111
   
   } non_state_types;



   typedef enum logic [2:0] {
      alu_fu         = 3'b000,
      mult_fu        = 3'b001,
      br_fu          = 3'b010, 
      mem_fu         = 3'b011,
      ctrl_fu        = 3'b100
   } func_unit_t; 

   // copy from pipeline
   typedef enum logic [2:0] {
      branch_f3_beq  = 3'b000,
      branch_f3_bne  = 3'b001,
      branch_f3_blt  = 3'b100,
      branch_f3_bge  = 3'b101,
      branch_f3_bltu = 3'b110,
      branch_f3_bgeu = 3'b111
    } branch_f3_t;

   typedef enum logic [6:0] {
      op_b_lui       = 7'b0110111, // load upper immediate (U type)
      op_b_auipc     = 7'b0010111, // add upper immediate PC (U type)
      op_b_jal       = 7'b1101111, // jump and link (J type)
      op_b_jalr      = 7'b1100111, // jump and link register (I type)
      op_b_br        = 7'b1100011, // branch (B type)
      op_b_load      = 7'b0000011, // load (I type)
      op_b_store     = 7'b0100011, // store (S type)
      op_b_imm       = 7'b0010011, // arith ops with register/immediate operands (I type)
      op_b_reg       = 7'b0110011  // arith ops with register operands (R type) !!M-EXTENSION ALSO USES THIS OPCODE!!
   } rv32_opcodes;

   typedef struct packed {
      logic valid;
      func_unit_t func_unit; // what functional unit will this go instruction be issued to?
      logic [4:0] arch_d_reg; // what is the final, correct architectural register we write result to on commit. (needed by RVFI and RRF)
      logic [PHYSICAL_REG_FILE_LENGTH-1:0] phys_d_reg; // this is the physical register index which is written into by functional unit. 
      logic [PHYSICAL_REG_FILE_LENGTH-1:0] phys_r1;
      logic [PHYSICAL_REG_FILE_LENGTH-1:0] phys_r2;
      logic phys_r1_valid; // flags indicating that this physical register DOES NOT have the value needed to issue, MUST WAIT on CDB broadcast
      logic phys_r2_valid; 
      logic [31:0] imm_operand;
      logic use_imm; // 1 represent replace rs2 with imme
      logic [31:0] pc_val; // needed by AUIPC, JALR, JAL, and BR
      logic branch_inst; // used to specify that AUIPC, SLT, SLTU, SLTI, SLTIU will get their results from branch func unit, but will not replace pc_next. 
      logic cmp_or_alu; // 0-> take ALU output, 1-> take cmp output, e.g. 0 for AUIPC, 1 for SLT family
      alu_ops_t alu_op; 
      branch_f3_t cmpop;
      m_extension_f3_t mul_op;
      logic jalr_flag; // flag used to indicate JALR, due to JALR uses REG+IMM for target (unlike branch or JAL) and d_reg = PC+4

      logic load_store; // load = 0, store = 1
      load_f3_t load_type;
      store_f3_t store_type; 
      logic jal_flag;

      logic [3:0]  branch_pattern;
      logic [1:0]  saturating_counter;
      logic [31:0] pc_target_predict;

      // RVFI
      logic [4:0] rvfi_rs1_s, rvfi_rs2_s, rvfi_rd_s;
      logic [31:0] rvfi_inst, rvfi_pc_val;
      logic [3:0] rvfi_mem_rmask, rvfi_mem_wmask;
   } id_dis_stage_reg_t;

   typedef struct packed {

         logic [31:0] bmem_addr;
         logic [255:0]  write_data;
         logic [255:0] dmem_rdata;
         logic [3:0] read_mask;
         logic [31:0] write_mask;
         logic [31:0] dmem_raddr;
         logic [22:0] tag;
         logic [3:0]  set;
         logic [1:0] index_replace; // make sure to change how we decide this instead of having it be straight up where 
         logic dirty;
         logic [2:0] offset;
         logic valid;
         logic [LOAD_RS_INDEX_BITS-1:0] index;
         logic [22:0] dirty_tag;
         logic is_dirty;
         logic [255:0] dirty_data;
         logic read;

    } inst_mem_t;


   typedef struct packed {
      logic finished;
      alu_ops_t alu_op; 
      logic [31:0] imm;
      logic use_imm;
      logic [4:0] arch_d_reg;
      logic [PHYSICAL_REG_FILE_LENGTH-1:0] phys_d_reg;
      logic [PHYSICAL_REG_FILE_LENGTH-1:0] phys_r1;
      logic [PHYSICAL_REG_FILE_LENGTH-1:0] phys_r2;
      logic phys_r1_valid; // flags indicating that this physical register DOES NOT have the value needed to issue, MUST WAIT on CDB broadcast
      logic phys_r2_valid; 
      logic [ROB_PTR_WIDTH : 0] rob_idx;
      logic [CONTROL_Q_DEPTH-1:0] control_bit_map;
   } alu_rs_entry_t;

   typedef struct packed {
      logic [31:0] inst;
      logic [31:0] pc;
      logic [3:0]  branch_pattern;
      logic [1:0]  saturating_counter;
      logic [31:0] pc_target_predict;
   } inst_fifo_t;

   typedef struct packed {
      logic finished;
      branch_f3_t cmpop;
      logic [31:0] pc;
      logic [31:0] imm; // needed for PC + imm instructions. 
      logic use_imm;
      logic [4:0] arch_d_reg;
      logic [PHYSICAL_REG_FILE_LENGTH-1:0] phys_d_reg;
      logic [PHYSICAL_REG_FILE_LENGTH-1:0] phys_r1;
      logic [PHYSICAL_REG_FILE_LENGTH-1:0] phys_r2;
      logic phys_r1_valid; // flags indicating that this physical register DOES NOT have the value needed to issue, MUST WAIT on CDB broadcast
      logic phys_r2_valid;
      logic branch_inst;  
      logic cmp_or_alu;
      logic jalr_flag; 
      logic jal_flag;
      logic [ROB_PTR_WIDTH : 0] rob_idx;
      logic [CONTROL_Q_DEPTH-1:0] control_bit_map;
   } branch_rs_entry_t;

   typedef struct packed {
      branch_f3_t cmpop;
      logic [31:0] pc;
      logic [31:0] imm; // needed for PC + imm instructions. 
      logic use_imm;
      logic [4:0] arch_d_reg;
      logic [PHYSICAL_REG_FILE_LENGTH-1:0] phys_d_reg;
      logic [PHYSICAL_REG_FILE_LENGTH-1:0] phys_r1;
      logic [PHYSICAL_REG_FILE_LENGTH-1:0] phys_r2;
      logic phys_r1_valid; 
      logic phys_r2_valid;
      logic branch_inst;  
      logic cmp_or_alu;
      logic jalr_flag; 
      logic jal_flag;
      logic [ROB_PTR_WIDTH : 0] rob_idx;
      logic [CONTROL_Q_DEPTH-1:0] control_bit_map;
      logic [MEM_QUEUE_PTR_WIDTH : 0] lsq_idx;
      logic [STORE_QUEUE_DEPTH-1:0] store_bitmap;
      logic [3:0]  branch_pattern;
      logic [1:0]  saturating_counter;
      logic [31:0] pc_target_predict;
   } control_rs_entry_t;

   typedef struct packed {
      logic finished;
      m_extension_f3_t mul_op;
      logic [4:0] arch_d_reg;
      logic [PHYSICAL_REG_FILE_LENGTH-1:0] phys_d_reg;
      logic [PHYSICAL_REG_FILE_LENGTH-1:0] phys_r1;
      logic [PHYSICAL_REG_FILE_LENGTH-1:0] phys_r2;
      logic phys_r1_valid; // flags indicating that this physical register DOES NOT have the value needed to issue, MUST WAIT on CDB broadcast
      logic phys_r2_valid; 
      logic [ROB_PTR_WIDTH : 0] rob_idx;
      logic [CONTROL_Q_DEPTH-1:0] control_bit_map;
   } mul_rs_entry_t;

   // -----------SEPARATE LOAD STORE QUEUE ---------------------------------
   typedef struct packed {
      logic finished; // mark this as 1 if the address has been calculated
      logic load_store; // 0 for load, 1 for store
      load_f3_t load_type;
      store_f3_t store_type;
      logic [31:0] imm;
      logic [4:0] arch_d_reg; // only used for loads
      logic [PHYSICAL_REG_FILE_LENGTH-1:0] phys_d_reg;
      logic [PHYSICAL_REG_FILE_LENGTH-1:0] phys_r1;
      logic [PHYSICAL_REG_FILE_LENGTH-1:0] phys_r2; // only used for stores
      logic phys_r1_valid; // flags indicating that this physical register DOES NOT have the value needed to issue, MUST WAIT on CDB broadcast
      logic phys_r2_valid; 
      logic [LOAD_RS_INDEX_BITS-1:0] load_rs_idx;
      logic [STORE_QUEUE_PTR_WIDTH-1:0] store_q_idx;
      logic [ROB_PTR_WIDTH : 0] rob_idx;
      logic [CONTROL_Q_DEPTH-1:0] control_bit_map;
   } addr_rs_entry_t;  

   typedef struct packed {
      logic finished;
      logic [3:0] rmask;
      logic [31:0] addr;
      logic [4:0] arch_d_reg; 
      logic [PHYSICAL_REG_FILE_LENGTH-1:0] phys_d_reg;
      logic [ROB_PTR_WIDTH : 0] rob_idx;
      logic [CONTROL_Q_DEPTH-1:0] control_bit_map;
      logic [STORE_QUEUE_DEPTH-1:0] store_bitmap;
      logic valid_addr;
      load_f3_t load_type;
      logic [31:0] rs1_v; 
      logic req_sent; 
      logic garbage_dmem; // flag so that the resp from cache is bad since it's a speculative mem inst. 
   } load_rs_entry_t;

   typedef struct packed {
      logic [3:0] wmask;
      logic [PHYSICAL_REG_FILE_LENGTH-1:0] phys_r2;
      logic phys_r2_valid; 
      logic [ROB_PTR_WIDTH : 0] rob_idx;
      logic [CONTROL_Q_DEPTH-1:0] control_bit_map;
      logic [31:0] addr;
      logic valid_addr;
      store_f3_t store_type;
      logic [31:0] rs1_v;
   } store_queue_entry_t; 

   typedef struct packed {
      logic [31:0] rvfi_rs1_rdata;
      logic [31:0] rvfi_rs2_rdata;
      logic [ROB_PTR_WIDTH:0] rvfi_issue_execute_rob_ptr;
      logic [3:0] rvfi_mem_wmask;
      logic [3:0] rvfi_mem_rmask;
      logic [31:0] rvfi_mem_addr;
      logic [31:0] rvfi_mem_wdata; 
   } RVFI_mem_entry_t;

   // -----------SEPARATE LOAD STORE QUEUE ---------------------------------

   typedef struct packed {
      logic ready_to_commit;
      logic [PHYSICAL_REG_FILE_LENGTH-1:0] phys_d_reg;
      logic [4:0] arch_d_reg;
      // logic br_en;
      // logic [31:0] pc_target;
   } rob_entry_t;

   typedef struct packed {

      logic valid;
      logic [ROB_PTR_WIDTH:0] rob_idx;

      logic [4:0] arch_d_reg; // these two needed for RAT
      logic [PHYSICAL_REG_FILE_LENGTH-1:0] phys_d_reg;

      logic [31:0] rd_v; // this +  phys_d_reg needed to broadcast into ROB and Reservation station.
      logic [CONTROL_Q_DEPTH-1:0] control_bit_map;

   } cdb_entry_t;
   typedef struct packed {


      logic [31:0] addr;
      logic [22:0] tag;
      logic [3:0]  set_idx;
      logic [4:0]  offset;
      logic chip_select;
      logic write_enable; //active low
      logic [32:0] write_mask ; // active high
      logic [255:0] write_data;
      logic [3:0] read_mask;
      logic [3:0] small_w;

      logic [31:0] wd_small;
      logic [LOAD_RS_INDEX_BITS-1:0] index;

   } dec_exec;




   typedef enum logic [2:0] {
        idle       = 3'b000,
        miss_hold_req = 3'b001,
        miss = 3'b011,
        dirty  = 3'b100,
        done   = 3'b101,
        idle_d_a = 3'b111
 
   
   } state_types;

   typedef enum logic [2:0] {
        idle_arbiter       = 3'b000,
        serving_icache = 3'b001,
        serving_dcache = 3'b010,
        fetching_nextline = 3'b011,
        nextline_hit = 3'b100
   } Arbiter_state;

   typedef struct packed {
      // logic commit; // this will come from ROB
      // logic [63:0] order; // this will just be a running counter of how many commits we perform. 
      logic [31:0] instruction;
      logic [4:0] rs1_addr;
      logic [4:0] rs2_addr;
      logic [31:0] rs1_rdata;
      logic [31:0] rs2_rdata;
      logic [4:0] rd_addr;
      logic [31:0] rd_wdata;
      logic [31:0] pc_rdata;
      logic [31:0] pc_wdata;
      logic [31:0] mem_addr;
      logic [3:0] mem_rmask;
      logic [3:0] mem_wmask;
      logic [31:0] mem_rdata;
      logic [31:0] mem_wdata;
   } RVFI_entry_t;


   // random TB instruction type:
   typedef union packed {
        logic [31:0] word;

        struct packed {
            logic [11:0] i_imm;
            logic [4:0]  rs1;
            logic [2:0]  funct3;
            logic [4:0]  rd;
            rv32_opcodes opcode;
        } i_type;

        struct packed {
            logic [6:0]  funct7;
            logic [4:0]  rs2;
            logic [4:0]  rs1;
            logic [2:0]  funct3;
            logic [4:0]  rd;
            rv32_opcodes opcode;
        } r_type;

        struct packed {
            logic [11:5] imm_s_top;
            logic [4:0]  rs2;
            logic [4:0]  rs1;
            logic [2:0]  funct3;
            logic [4:0]  imm_s_bot;
            rv32_opcodes opcode;
        } s_type;

        struct packed {
            logic imm_12;
            logic [5:0] imm_10_5;
            logic [4:0] rs2;
            logic [4:0] rs1;
            logic [2:0] funct3;
            logic [3:0] imm_4_1;
            logic imm_11;
            rv32_opcodes opcode; 
        } b_type;

        struct packed {
            logic [31:12] imm;
            logic [4:0]   rd;
            rv32_opcodes  opcode;
        } j_type;

    } instr_t;

    typedef enum logic [6:0] {
        base           = 7'b0000000,
        variant        = 7'b0100000,
        mul_div_rem    = 7'b0000001
    } funct7_t;


endpackage
