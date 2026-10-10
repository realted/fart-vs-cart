// ---------------------------------------------------------------------
// Copyright (c) 2007 by University of Toronto ECE 243 development team 
// ---------------------------------------------------------------------
//
// Major Functions:	a simple processor which operates basic mathematical
//					operations as follow:
//					(1)loading, (2)storing, (3)adding, (4)subtracting,
//					(5)shifting, (6)oring, (7)branch if zero,
//					(8)branch if not zero, (9)branch if positive zero
//					 
// Input(s):		1. KEY0(reset): clear all values from registers,
//									reset flags condition, and reset
//									control FSM
//					2. KEY1(clock): manual clock controls FSM and all
//									synchronous components at every
//									positive clock edge
//
//
// Output(s):		1. HEX Display: display registers value K3 to K1
//									in hexadecimal format
//
//					** For more details, please refer to the document
//					   provided with this implementation
//
// ---------------------------------------------------------------------
import params::*;


module gpu
(
CLOCK_50,
SW, KEY, HEX0, HEX1, HEX2, HEX3,
HEX4, HEX5, LEDR
);

// ------------------------ PORT declaration ------------------------ //
input	[1:0] KEY;
input CLOCK_50;
input [8:0] SW;          // Original Multicycle Uses 4 Switches... Just add all 9
output	[6:0] HEX0, HEX1, HEX2, HEX3;
output	[6:0] HEX4, HEX5;
output reg [17:0] LEDR;

// ------------------------- Registers/Wires ------------------------ //
wire	clock, reset;
wire	IRLoad, MDRLoad, MemRead, PCWrite;
wire	ALU1, ALUOutWrite, FlagWrite, R1R2Load, R1Sel, RFWrite, stop;
wire	[DATA_BIT_WIDTH-1:0] R2wire, PCwire, R1wire, RFout1wire, RFout2wire;
wire	[DATA_BIT_WIDTH-1:0] ALU1wire, ALU2wire, ALUwire, ALUOut, MDRwire, Instr_out;
wire	[IR_BIT_WIDTH-1:0] IR;
wire    [DATA_BIT_WIDTH-1:0] SE4wire, ZE5wire, ZE3wire, RegWire;
wire	[DATA_BIT_WIDTH-1:0] reg0, reg1, reg2, reg3;
wire	[DATA_BIT_WIDTH-1:0] constant;
wire	[2:0] ALUOp, ALU2;
wire	[1:0] R1_in, RegIn;
wire    [15:0] counterOut;
wire	Nwire, Zwire;
reg		N, Z;

// NEW CONNECTIONS 
// VRF
wire	[DATA_BIT_WIDTH-1:0] vreg0_0, vreg0_1, vreg0_2, vreg0_3;
wire	[DATA_BIT_WIDTH-1:0] vreg1_0, vreg1_1, vreg1_2, vreg1_3;
wire	[DATA_BIT_WIDTH-1:0] vreg2_0, vreg2_1, vreg2_2, vreg2_3;
wire	[DATA_BIT_WIDTH-1:0] vreg3_0, vreg3_1, vreg3_2, vreg3_3;
wire	[DATA_BIT_WIDTH-1:0] vreg4_0, vreg4_1, vreg4_2, vreg4_3;
wire	[DATA_BIT_WIDTH-1:0] vreg5_0, vreg5_1, vreg5_2, vreg5_3;
wire	[DATA_BIT_WIDTH-1:0] vreg6_0, vreg6_1, vreg6_2, vreg6_3;
wire	[DATA_BIT_WIDTH-1:0] vreg7_0, vreg7_1, vreg7_2, vreg7_3;
wire    [DATA_BIT_WIDTH-1:0] VRFout1_0wire, VRFout1_1wire, VRFout1_2wire, VRFout1_3wire; 
wire    [DATA_BIT_WIDTH-1:0] VRFout2_0wire, VRFout2_1wire, VRFout2_2wire, VRFout2_3wire; 
wire	[DATA_BIT_WIDTH-1:0] vdataw_0wire, vdataw_1wire, vdataw_2wire, vdataw_3wire; 
wire    VRFWrite;  // Control

// Register Wires 
wire    X1Load, X2Load;   // Control
wire	[DATA_BIT_WIDTH-1:0] X1out_0, X1out_1, X1out_2, X1out_3;
wire	[DATA_BIT_WIDTH-1:0] X2out_0, X2out_1, X2out_2, X2out_3;

// Mask Register
wire	ldMask; // Control
wire    vmaskreset; // Control
wire	[3:0] VRFLaneWrite;

// ALU/Mux Wire
wire	[DATA_BIT_WIDTH-1:0] vq0, vq1, vq2, vq3;
wire	mask0, mask1, mask2, mask3;
wire    [3:0] v_op;     	// Control
wire    VoutSel;            // Control
wire	[DATA_BIT_WIDTH-1:0] vMux0, vMux1, vMux2, vMux3;

// CLOCK Auto advance
localparam integer HALF_PERIOD = 250_000;
reg [17:0] divider;
reg cpu_clock;

// GPU v0.4 additions
wire	[3:0] scalar_wren_mux_out, mem_wren_out;
wire	vecstore, MemWrite;
wire	[DATA_BIT_WIDTH-1:0] M0_in, M1_in, M2_in, M3_in; 
wire	[DATA_BIT_WIDTH-1:0] M0_out, M1_out, M2_out, M3_out; 
wire	[DATA_BIT_WIDTH-1:0] MDR_IN;

// GPU v0.5 additions
wire	[DATA_BIT_WIDTH-1:0] ZE3_LIwire;

always @(posedge CLOCK_50 or posedge reset) begin
    if (reset) begin
        divider   <= 0;
        cpu_clock <= 0;
    end else if (divider == HALF_PERIOD - 1) begin
        divider   <= 0;
        cpu_clock <= ~cpu_clock;
    end else begin
        divider <= divider + 1'b1;
    end
end


// ------------------------ Input Assignment ------------------------ //
assign	clock = cpu_clock;
assign	reset =  ~KEY[0]; // KEY is active high


// ------------------- DE2 compatible HEX display ------------------- //
HEXs	HEX_display(
	.in0(reg0),.in1(reg1),.in2(reg2),.in3(reg3),
	// New additions 
	.inv0_0(vreg0_0), .inv0_1(vreg0_1), .inv0_2(vreg0_2), .inv0_3(vreg0_3), 
	.inv1_0(vreg1_0), .inv1_1(vreg1_1), .inv1_2(vreg1_2), .inv1_3(vreg1_3), 
	.inv2_0(vreg2_0), .inv2_1(vreg2_1), .inv2_2(vreg2_2), .inv2_3(vreg2_3), 
	.inv3_0(vreg3_0), .inv3_1(vreg3_1), .inv3_2(vreg3_2), .inv3_3(vreg3_3), 
	.inv4_0(vreg4_0), .inv4_1(vreg4_1), .inv4_2(vreg4_2), .inv4_3(vreg4_3), 
	.inv5_0(vreg5_0), .inv5_1(vreg5_1), .inv5_2(vreg5_2), .inv5_3(vreg5_3), 
	.inv6_0(vreg6_0), .inv6_1(vreg6_1), .inv6_2(vreg6_2), .inv6_3(vreg6_3), 
	.inv7_0(vreg7_0), .inv7_1(vreg7_1), .inv7_2(vreg7_2), .inv7_3(vreg7_3), 
	// SW2 is the high selector bit; SW8..SW5 are the low four bits.
    // 0..3: scalar registers; 4..19: vector lanes; 31: counter.
    .selH({SW[2], SW[8:4]}), .counter(counterOut),
	// Til here
	.out0(HEX0),.out1(HEX1),.out2(HEX2),.out3(HEX3),
	.out4(HEX4),.out5(HEX5)
);
// ----------------- END DE2 compatible HEX display ----------------- //

/*
// ------------------- DE1 compatible HEX display ------------------- //
chooseHEXs	HEX_display(
	.in0(reg0),.in1(reg1),.in2(reg2),.in3(reg3),
	.out0(HEX0),.out1(HEX1),.select(SW[1:0])
);
// turn other HEX display off
assign HEX2 = 7'b1111111;
assign HEX3 = 7'b1111111;
assign HEX4 = 7'b1111111;
assign HEX5 = 7'b1111111;
assign HEX6 = 7'b1111111;
assign HEX7 = 7'b1111111;
// ----------------- END DE1 compatible HEX display ----------------- //
*/

FSM		Control(
	.reset(reset),.clock(clock),.N(N),.Z(Z),.instr(IR[11:0]), .msbInstr(IR[15]),
	.PCwrite(PCWrite),.MemRead(MemRead),
	.IRload(IRLoad),.R1Sel(R1Sel),.MDRload(MDRLoad),.R1R2Load(R1R2Load),
	.ALU1(ALU1),.ALUOutWrite(ALUOutWrite),.RFWrite(RFWrite),.RegIn(RegIn),
	.FlagWrite(FlagWrite),.ALU2(ALU2),.ALUop(ALUOp), .stop(stop), 
	// New
	.VRFWrite(VRFWrite), .v_op(v_op), .ldMask(ldMask), .vmaskreset(vmaskreset), .X1Load(X1Load), .X2Load(X2Load), .VoutSel(VoutSel),
	.vecstore(vecstore), .MemWrite(MemWrite)
	
	
);

// Change R1wire to output of Mux so it is MemInWire
//memory	DataMem(
//	.MemRead(MemRead),.wren(MemWrite),.clock(clock),
//	.address(AddrWire),.data(MemInWire),.q(MEMwire)
//);

InstructionMemory	InstructionMemory(
	.address(PCwire),.clock(~clock),.q(Instr_out)
);

ALU		ALU(
	.in1(ALU1wire),.in2(ALU2wire),.out(ALUwire),
	.ALUOp(ALUOp),.N(Nwire),.Z(Zwire)
);

wire vector_mem = (IR[3:0] == 4'b0000) &&
                  ((IR[9:4] == 6'b100001) ||
                   (IR[9:4] == 6'b100010));

wire [1:0] rf_read2 = vector_mem ? IR[11:10] : IR[13:12];

RF		RF_block(
	.clock(clock),.reset(reset),.RFWrite(RFWrite),
	.dataw(RegWire),.reg1(R1_in),.reg2(rf_read2),
	.regw(R1_in),.data1(RFout1wire),.data2(RFout2wire),
	.r0(reg0),.r1(reg1),.r2(reg2),.r3(reg3)
);

// VRF Block

VRF		VRF_block(
	.clock(clock),.reset(reset),.VRFWrite(VRFWrite),.VRFLaneWrite(VRFLaneWrite),
	.vreg1(IR[15:13]),.vreg2(IR[12:10]),.vregw(IR[15:13]),
	.vdataw_0(vMux0), .vdataw_1(vMux1), .vdataw_2(vMux2), .vdataw_3(vMux3),
	.vdata1_0(VRFout1_0wire), .vdata1_1(VRFout1_1wire), .vdata1_2(VRFout1_2wire), .vdata1_3(VRFout1_3wire),
	.vdata2_0(VRFout2_0wire), .vdata2_1(VRFout2_1wire), .vdata2_2(VRFout2_2wire), .vdata2_3(VRFout2_3wire),
	.vr0_0(vreg0_0),.vr0_1(vreg0_1),.vr0_2(vreg0_2),.vr0_3(vreg0_3),
	.vr1_0(vreg1_0),.vr1_1(vreg1_1),.vr1_2(vreg1_2),.vr1_3(vreg1_3),
	.vr2_0(vreg2_0),.vr2_1(vreg2_1),.vr2_2(vreg2_2),.vr2_3(vreg2_3),
	.vr3_0(vreg3_0),.vr3_1(vreg3_1),.vr3_2(vreg3_2),.vr3_3(vreg3_3),
	.vr4_0(vreg4_0),.vr4_1(vreg4_1),.vr4_2(vreg4_2),.vr4_3(vreg4_3),
	.vr5_0(vreg5_0),.vr5_1(vreg5_1),.vr5_2(vreg5_2),.vr5_3(vreg5_3),
	.vr6_0(vreg6_0),.vr6_1(vreg6_1),.vr6_2(vreg6_2),.vr6_3(vreg6_3),
	.vr7_0(vreg7_0),.vr7_1(vreg7_1),.vr7_2(vreg7_2),.vr7_3(vreg7_3)
);

// X1 & X2 registers

register_nx4bit  X1(
	.clock(clock),.aclr(reset),.enable(X1Load),
	.data_0(VRFout1_0wire), .data_1(VRFout1_1wire), .data_2(VRFout1_2wire), .data_3(VRFout1_3wire),
	.q_0(X1out_0), .q_1(X1out_1), .q_2(X1out_2), .q_3(X1out_3) 
);

register_nx4bit  X2(
	.clock(clock),.aclr(reset),.enable(X2Load),
	.data_0(VRFout2_0wire), .data_1(VRFout2_1wire), .data_2(VRFout2_2wire), .data_3(VRFout2_3wire),
	.q_0(X2out_0), .q_1(X2out_1), .q_2(X2out_2), .q_3(X2out_3) 
);

// Mux 5-1 to Data_in of memory

//mux5to1_nbit 		Mem_mux(
//	.data0x(X1out_0),.data1x(X1out_1),.data2x(X1out_2),
//	.data3x(X1out_3),.data4x(R1wire),.sel(MemInSel),.result(MemInWire)
//);

// Mask Register
mask_reg_4b reg_4b(.clock(clock), .aclr(reset), .d({mask3, mask2, mask1, mask0}), .ldMask(ldMask), .vmaskreset(vmaskreset), .q(VRFLaneWrite));

// Replaced Adders with ALU's

ALU_V a0(
	.in1(X1out_0), .in2(X2out_0), .out(vq0), .mask(mask0), .v_op(v_op)
);

ALU_V a1(
	.in1(X1out_1), .in2(X2out_1), .out(vq1), .mask(mask1), .v_op(v_op) 
);

ALU_V a2(
	.in1(X1out_2), .in2(X2out_2), .out(vq2), .mask(mask2), .v_op(v_op) 	
);

ALU_V a3(
	.in1(X1out_3), .in2(X2out_3), .out(vq3), .mask(mask3), .v_op(v_op) 
);

// 4 2-1 Muxes PLEASE

mux2to1_nbit 		voutSel_mux0(
	.data0x(vq0),.data1x(M0_out),
	.sel(VoutSel),.result(vMux0)
);

mux2to1_nbit 		voutSel_mux1(
	.data0x(vq1),.data1x(M1_out),
	.sel(VoutSel),.result(vMux1)
);

mux2to1_nbit 		voutSel_mux2(
	.data0x(vq2),.data1x(M2_out),
	.sel(VoutSel),.result(vMux2)
);

mux2to1_nbit 		voutSel_mux3(
	.data0x(vq3),.data1x(M3_out),
	.sel(VoutSel),.result(vMux3)
);


// Now for editing R2... 

// Start with Adder
//adder_n plusOne(
//	.in1(R2wire), .in2(constant), .out(plus1Wire) 
//);

// Selection Mux for R2
//mux2to1_nbit 		r2Sel_mux(
//	.data0x(RFout2wire),.data1x(plus1Wire),
//	.sel(R2sel),.result(R2MuxOut)
//);

// DONE NEW ADDITIONS


register_nbit	IR_reg(
	.clock(clock),.aclr(reset),.enable(IRLoad),
	.data(Instr_out),.q(IR)
);

register_nbit	MDR_reg(
	.clock(clock),.aclr(reset),.enable(MDRLoad),
	.data(MDR_IN),.q(MDRwire)
);

register_nbit	PC(
	.clock(clock),.aclr(reset),.enable(PCWrite),
	.data(ALUwire),.q(PCwire)
);

register_nbit	R1(
	.clock(clock),.aclr(reset),.enable(R1R2Load),
	.data(RFout1wire),.q(R1wire)
);

// Edit this to be inputted from MuxOut not RF2 directly may have to edit enable...
register_nbit	R2(
	.clock(clock),.aclr(reset),.enable(R1R2Load),
	.data(RFout2wire),.q(R2wire)
);

register_nbit	ALUOut_reg(
	.clock(clock),.aclr(reset),.enable(ALUOutWrite),
	.data(ALUwire),.q(ALUOut)
);

mux2to1_2bit		R1Sel_mux(
	.data0x(IR[15:14]),.data1x(constant[1:0]),
	.sel(R1Sel),.result(R1_in)
);

//mux2to1_nbit 		AddrSel_mux(
//	.data0x(R2wire),.data1x(PCwire),
//	.sel(AddrSel),.result(AddrWire)
//);

mux4to1_nbit 		RegMux(
	.data0x(ALUOut),.data1x(MDRwire),
	.data2x(ZE3_LIwire),.data3x(constant),
	.sel(RegIn),.result(RegWire)
);

mux2to1_nbit 		ALU1_mux(
	.data0x(PCwire),.data1x(R1wire),
	.sel(ALU1),.result(ALU1wire)
);

mux5to1_nbit 		ALU2_mux(
	.data0x(R2wire),.data1x(constant),.data2x(SE4wire),
	.data3x(ZE5wire),.data4x(ZE3wire),.sel(ALU2),.result(ALU2wire)
);

// Add Counter here 
counter             counter(
	.clock(clock), .reset(reset), .stop(stop), .counterOut(counterOut)
);

sExtend		SE4(.in(IR[15:4]),.out(SE4wire));
zExtend		ZE3(.in(IR[13:3]),.out(ZE3wire));
zExtend		ZE5(.in(IR[15:3]),.out(ZE5wire));
// define parameter for the data size to be extended
defparam	SE4.n = 12;
defparam	ZE3.n = 11;
defparam	ZE5.n = 13;

always@(posedge clock or posedge reset)
begin
if (reset)
	begin
	N <= 0;
	Z <= 0;
	end
else
if (FlagWrite)
	begin
	N <= Nwire;
	Z <= Zwire;
	end
end



// New additions GPU v0.4
mux4to1_4bit 		scalar_wren_mux(
	.data0x(4'b0001),.data1x(4'b0010),
	.data2x(4'b0100),.data3x(4'b1000),
	.sel(R2wire[1:0]),.result(scalar_wren_mux_out)
);

mux2to1_4bit 		scalar_vector_wren_mux(
	.data0x(scalar_wren_mux_out),.data1x(4'b1111),
	.sel(vecstore),.result(mem_wren_out)
);

memory #(.INIT_FILE("data_bank0.mif")) M0(
	.MemRead(MemRead),.wren(MemWrite & mem_wren_out[0]),.clock(clock),
	.address(R2wire[DATA_BIT_WIDTH-1:2]),.data(M0_in),.q(M0_out)
);

memory #(.INIT_FILE("data_bank1.mif")) M1(
	.MemRead(MemRead),.wren(MemWrite & mem_wren_out[1]),.clock(clock),
	.address(R2wire[DATA_BIT_WIDTH-1:2]),.data(M1_in),.q(M1_out)
);

memory #(.INIT_FILE("data_bank2.mif")) M2(
	.MemRead(MemRead),.wren(MemWrite & mem_wren_out[2]),.clock(clock),
	.address(R2wire[DATA_BIT_WIDTH-1:2]),.data(M2_in),.q(M2_out)
);

memory #(.INIT_FILE("data_bank3.mif")) M3(
	.MemRead(MemRead),.wren(MemWrite & mem_wren_out[3]),.clock(clock),
	.address(R2wire[DATA_BIT_WIDTH-1:2]),.data(M3_in),.q(M3_out)
);

// Muxes to D_in of mem0 - 3
mux2to1_nbit 		M0_in_mux(
	.data0x(R1wire),.data1x(X1out_0),
	.sel(vecstore),.result(M0_in)
);

mux2to1_nbit 		M1_in_mux(
	.data0x(R1wire),.data1x(X1out_1),
	.sel(vecstore),.result(M1_in)
);

mux2to1_nbit 		M2_in_mux(
	.data0x(R1wire),.data1x(X1out_2),
	.sel(vecstore),.result(M2_in)
);

mux2to1_nbit 		M3_in_mux(
	.data0x(R1wire),.data1x(X1out_3),
	.sel(vecstore),.result(M3_in)
);

// Mux to MDR

mux4to1_nbit 		mdr_in_mux(
	.data0x(M0_out),.data1x(M1_out),
	.data2x(M2_out),.data3x(M3_out),
	.sel(R2wire[1:0]),.result(MDR_IN)
);

// New additions GPU v0.5 (LI)
zExtend		ZE3_LI(.in(IR[13:3]),.out(ZE3_LIwire));
defparam	ZE3_LI.n = 11;


// ------------------------ Assign Constant 1 ----------------------- //
assign	constant = 1;

// ------------------------- LEDs Indicator ------------------------- //
always @ (*)
begin

    case({SW[4],SW[3]})
    2'b00:
    begin
      LEDR[9] = 0;
      LEDR[8] = 0;
      LEDR[7] = PCWrite;
      LEDR[5] = MemRead;
      //LEDR[4] = MemWrite;
      LEDR[3] = IRLoad;
      LEDR[2] = R1Sel;
      LEDR[1] = MDRLoad;
      LEDR[0] = R1R2Load;
    end

    2'b01:
    begin
      LEDR[9] = ALU1;
      LEDR[8:6] = ALU2[2:0];
      LEDR[5:3] = ALUOp[2:0];
      LEDR[2] = ALUOutWrite;
      LEDR[1] = RFWrite;
      //LEDR[0] = RegIn;
    end

    2'b10:
    begin
      LEDR[9] = 0;
      LEDR[8] = 0;
      LEDR[7] = FlagWrite;
      LEDR[6:2] = constant[7:3];
      LEDR[1] = N;
      LEDR[0] = Z;
    end

    2'b11:
    begin
      LEDR[9:0] = 10'b0;
    end
  endcase
end
endmodule
