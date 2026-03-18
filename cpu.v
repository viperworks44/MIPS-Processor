/***********************************************************************************************/
/*********************************  MIPS 5-stage pipeline implementation ***********************/
/***********************************************************************************************/
`timescale 1ns/1ps

module cpu(input clock, input reset);
 reg [31:0] PC; 
 reg [31:0] IFID_PCplus4;
 reg [31:0] IFID_instr;
 reg [31:0] IDEX_rdA, IDEX_rdB, IDEX_signExtend;
 reg [4:0]  IDEX_instr_rt, IDEX_instr_rs, IDEX_instr_rd, IDEX_shamt;                            
 reg        IDEX_RegDst, IDEX_ALUSrc;
 reg [1:0]  IDEX_ALUcntrl;
 reg        IDEX_Branch, IDEX_MemRead, IDEX_MemWrite; 
 reg        IDEX_MemToReg, IDEX_RegWrite;                
 reg [4:0]  EXMEM_RegWriteAddr, EXMEM_instr_rd; 
 reg [31:0] EXMEM_ALUOut;
 reg        EXMEM_Zero;
 reg [31:0] EXMEM_MemWriteData;
 reg        EXMEM_Branch, EXMEM_MemRead, EXMEM_MemWrite, EXMEM_RegWrite, EXMEM_MemToReg;
 reg [31:0] MEMWB_DMemOut;
 reg [4:0]  MEMWB_RegWriteAddr, MEMWB_instr_rd; 
 reg [31:0] MEMWB_ALUOut;
 reg        MEMWB_MemToReg, MEMWB_RegWrite; 
 wire       IFID_flush, IDEX_flush; 
 wire [31:0] instr, ALUInA, ALUInB, ALUOut, rdA, rdB, signExtend, DMemOut, wRegData, PCIncr;
 wire Zero, RegDst, MemRead, MemWrite, MemToReg, ALUSrc, RegWrite, Branch;
 wire [5:0] opcode, func;
 wire [4:0] instr_rs, instr_rt, instr_rd, RegWriteAddr;
 wire [3:0] ALUOp;
 wire [1:0] ALUcntrl;
 wire [15:0] imm;
 wire [1:0] ForwardA, ForwardB;
 wire [31:0] ALUInB_zero;
 wire [4:0] shamt;
 wire PC_write, IFID_write, bubble_idex;
 wire [31:0] new_address, final_address, mid_address, jumped_address;
 wire [27:0] IFID_instr_extend;
 wire zero_signal, PCSrc, Jump_signal;

 
 

/***************** Instruction Fetch Unit (IF)  ****************/
 always @(posedge clock or negedge reset)
  begin 
    if (reset == 1'b0)     
       PC <= -1;     
    else if (PC == -1)
       PC <= 0;
    else
       if (PC_write != 1'b0) 	
          PC <= jumped_address;
  end
  
 // IFID pipeline register
 always @(posedge clock or negedge reset)
  begin
    if (reset == 1'b0 || IFID_flush == 1'b1 || IDEX_flush == 1'b1)    
      begin
       IFID_PCplus4 <= 32'b0;    
       IFID_instr <= 32'b0;
      end
    else
      begin
        if (IFID_write != 1'b0)
          begin
            IFID_PCplus4 <= PC + 32'd4;
            IFID_instr <= instr;
          end
      end
  end
  
// Instruction memory 1KB
Memory cpu_IMem(clock, reset, 1'b1, 1'b0, PC>>2, 32'b0, instr);
  
  
  
  
  
/***************** Instruction Decode Unit (ID)  ****************/
assign opcode = IFID_instr[31:26];
assign func = IFID_instr[5:0];
assign instr_rs = IFID_instr[25:21];
assign instr_rt = IFID_instr[20:16];
assign instr_rd = IFID_instr[15:11];
assign imm = IFID_instr[15:0];
assign shamt = IFID_instr[10:6];
assign signExtend = {{16{imm[15]}}, imm};

assign new_address = IFID_PCplus4 + (signExtend << 2);
assign zero_signal = (rdA - rdB == 1'b0) ? 1 : 0;
assign final_address = (PCSrc) ? new_address : (PC + 4);

//assign PCSrc = Branch & zero_signal;

assign IFID_instr_extend = (IFID_instr[25:0] << 2);
assign mid_address = {IFID_PCplus4[31:28], IFID_instr_extend};
assign jumped_address = (Jump_signal) ? mid_address : final_address;

// Register file
RegFile cpu_regs(clock, reset, instr_rs, instr_rt, MEMWB_RegWriteAddr, MEMWB_RegWrite, wRegData, rdA, rdB);

  // IDEX pipeline register
 always @(posedge clock or negedge reset)
  begin 
    if (reset == 1'b0 || bubble_idex == 1'b0)
      begin
       IDEX_rdA <= 32'b0;    
       IDEX_rdB <= 32'b0;
       IDEX_signExtend <= 32'b0;
       IDEX_instr_rd <= 5'b0;
       IDEX_instr_rs <= 5'b0;
       IDEX_instr_rt <= 5'b0;
       IDEX_RegDst <= 1'b0;
       IDEX_ALUcntrl <= 2'b0;
       IDEX_ALUSrc <= 1'b0;
       IDEX_Branch <= 1'b0;
       IDEX_MemRead <= 1'b0;
       IDEX_MemWrite <= 1'b0;
       IDEX_MemToReg <= 1'b0;                  
       IDEX_RegWrite <= 1'b0;
	   IDEX_shamt <= 5'b0;
      end 
    else 
	  begin
		IDEX_rdA <= rdA;
		IDEX_rdB <= rdB;
		IDEX_signExtend <= signExtend;
		IDEX_instr_rd <= instr_rd;
		IDEX_instr_rs <= instr_rs;
		IDEX_instr_rt <= instr_rt;
		IDEX_shamt <= shamt;
	    IDEX_RegDst <= RegDst;
        IDEX_ALUcntrl <= ALUcntrl;
        IDEX_ALUSrc <= ALUSrc;
        IDEX_Branch <= Branch;
        IDEX_MemRead <= MemRead;
        IDEX_MemWrite <= MemWrite;
        IDEX_MemToReg <= MemToReg;                  
		IDEX_RegWrite <= RegWrite;
      end
  end

// Main Control Unit 
control_main control_main (RegDst,
                  Branch,
                  MemRead,
                  MemWrite,
                  MemToReg,
                  ALUSrc,
                  RegWrite,
                  ALUcntrl,
				  PCSrc,
				  Jump_signal,
                  opcode,
				  zero_signal);
                  
// Instantiation of Control Unit that generates stalls goes here
stall_detection hazard_unit(PC_write, IFID_write, bubble_idex, instr_rs, instr_rt, IDEX_instr_rt, IDEX_MemRead);

// Instantiation of flush modules
first_flush first_flush(IFID_flush, Jump_signal);
second_flush second_flush(IDEX_flush, PCSrc);
                           
/***************** Execution Unit (EX)  ****************/
                 
assign ALUInA = 
              (ForwardA == 2'b00) ? IDEX_rdA :
              (ForwardA == 2'b01) ? wRegData :
              (ForwardA == 2'b10) ? EXMEM_ALUOut :
              'bx;
                 
assign ALUInB_zero = 
              (ForwardB == 2'b00) ? IDEX_rdB :
              (ForwardB == 2'b01) ? wRegData :
              (ForwardB == 2'b10) ? EXMEM_ALUOut :
              'bx;

assign ALUInB = (IDEX_ALUSrc) ? IDEX_signExtend : ALUInB_zero; 

//  ALU
ALU  #(32) cpu_alu(ALUOut, Zero, ALUInA, ALUInB, ALUOp, IDEX_shamt);

assign RegWriteAddr = (IDEX_RegDst==1'b0) ? IDEX_instr_rt : IDEX_instr_rd;



 // EXMEM pipeline register
 always @(posedge clock or negedge reset)
  begin 
    if (reset == 1'b0)     
      begin
        EXMEM_ALUOut <= 32'b0;    
        EXMEM_RegWriteAddr <= 5'b0;
        EXMEM_MemWriteData <= 32'b0;
        EXMEM_Zero <= 1'b0;
        EXMEM_Branch <= 1'b0;
        EXMEM_MemRead <= 1'b0;
        EXMEM_MemWrite <= 1'b0;
        EXMEM_MemToReg <= 1'b0;                  
        EXMEM_RegWrite <= 1'b0;
	    EXMEM_instr_rd <= 5'b0;
      end 
    else 
      begin
	    EXMEM_ALUOut <= ALUOut;    
        EXMEM_RegWriteAddr <= RegWriteAddr;
        EXMEM_MemWriteData <= ALUInB_zero;
	    EXMEM_Zero <= Zero;
        EXMEM_Branch <= IDEX_Branch;
        EXMEM_MemRead <= IDEX_MemRead;
        EXMEM_MemWrite <= IDEX_MemWrite;
        EXMEM_MemToReg <= IDEX_MemToReg;                  
        EXMEM_RegWrite <= IDEX_RegWrite;
	    EXMEM_instr_rd <= IDEX_instr_rd;
      end
  end
  
  // ALU control
  control_alu control_alu(ALUOp, IDEX_ALUcntrl, IDEX_signExtend[5:0]);
  
   // Instantiation of control logic for Forwarding goes here
  control_bypass_ex bypass_ex(ForwardA, ForwardB, IDEX_instr_rs, IDEX_instr_rt, EXMEM_RegWriteAddr, MEMWB_RegWriteAddr, EXMEM_RegWrite, MEMWB_RegWrite);

  
  
  
/***************** Memory Unit (MEM)  ****************/  

// Data memory 1KB
Memory cpu_DMem(clock, reset, EXMEM_MemRead, EXMEM_MemWrite, EXMEM_ALUOut, EXMEM_MemWriteData, DMemOut);

// MEMWB pipeline register
 always @(posedge clock or negedge reset)
  begin 
    if (reset == 1'b0)     
      begin
        MEMWB_DMemOut <= 32'b0;    
        MEMWB_ALUOut <= 32'b0;
        MEMWB_RegWriteAddr <= 5'b0;
        MEMWB_MemToReg <= 1'b0;                  
        MEMWB_RegWrite <= 1'b0;
	    MEMWB_instr_rd <= 5'b0;
      end 
    else 
	  begin
        MEMWB_DMemOut <= DMemOut;
        MEMWB_ALUOut <= EXMEM_ALUOut;
        MEMWB_RegWriteAddr <= EXMEM_RegWriteAddr;
	    MEMWB_instr_rd <= EXMEM_instr_rd;
	    MEMWB_MemToReg <= EXMEM_MemToReg;                  
        MEMWB_RegWrite <= EXMEM_RegWrite;
	  end
  end
  
  
  

/***************** WriteBack Unit (WB)  ****************/  
assign wRegData = (MEMWB_MemToReg == 1'b0) ? MEMWB_ALUOut : MEMWB_DMemOut;


endmodule
