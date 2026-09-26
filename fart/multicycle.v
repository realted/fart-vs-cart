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

module multicycle
(
SW, KEY, HEX0, HEX1, HEX2, HEX3,
HEX4, HEX5, LEDR
);

// ------------------------ PORT declaration ------------------------ //
input	[1:0] KEY;
input [8:0] SW;          // Original Multicycle Uses 4 Switches... Just add all 9
output	[6:0] HEX0, HEX1, HEX2, HEX3;
output	[6:0] HEX4, HEX5;
output reg [17:0] LEDR;

// ------------------------- Registers/Wires ------------------------ //
wire	clock, reset;
wire	IRLoad, MDRLoad, MemRead, MemWrite, PCWrite, RegIn, AddrSel;
wire	ALU1, ALUOutWrite, FlagWrite, R1R2Load, R1Sel, RFWrite, stop;
wire	[7:0] R2wire, PCwire, R1wire, RFout1wire, RFout2wire;
wire	[7:0] ALU1wire, ALU2wire, ALUwire, ALUOut, MDRwire, MEMwire;
wire	[7:0] IR, SE4wire, ZE5wire, ZE3wire, AddrWire, RegWire;
wire	[7:0] reg0, reg1, reg2, reg3;
wire	[7:0] constant;
wire	[2:0] ALUOp, ALU2;
wire	[1:0] R1_in;
wire    [15:0] counterOut;
wire	Nwire, Zwire;
reg		N, Z;

// NEW CONNECTIONS 
// VRF
wire	[7:0] vreg0_0, vreg0_1, vreg0_2, vreg0_3;
wire	[7:0] vreg1_0, vreg1_1, vreg1_2, vreg1_3;
wire	[7:0] vreg2_0, vreg2_1, vreg2_2, vreg2_3;
wire	[7:0] vreg3_0, vreg3_1, vreg3_2, vreg3_3;
wire    [7:0] VRFout1_0wire, VRFout1_1wire, VRFout1_2wire, VRFout1_3wire; 
wire    [7:0] VRFout2_0wire, VRFout2_1wire, VRFout2_2wire, VRFout2_3wire; 
wire	[7:0] vdataw_0wire, vdataw_1wire, vdataw_2wire, vdataw_3wire; 
wire    VRFWrite;  // Control

// Register Wires 
wire    X1Load, X2Load;   // Control
wire	[7:0] X1out_0, X1out_1, X1out_2, X1out_3;
wire	[7:0] X2out_0, X2out_1, X2out_2, X2out_3;

// 5 -1 Mux
wire	[2:0] MemInSel;    // Control
wire    [7:0] MemInWire;

// Adder/Mux Wire
wire	[7:0] add0, add1, add2, add3;
wire    VoutSel;            // Control
wire	[7:0] vMux0, vMux1, vMux2, vMux3;

// Temp Reg Wire
wire    t0load, t1load, t2load, t3load;  // Control

// R2 adder, Mux
wire	[7:0] plus1Wire;
wire	[7:0] R2MuxOut;
wire    R2sel;           // Control


// ------------------------ Input Assignment ------------------------ //
assign	clock = KEY[1];
assign	reset =  ~KEY[0]; // KEY is active high


// ------------------- DE2 compatible HEX display ------------------- //
HEXs	HEX_display(
	.in0(reg0),.in1(reg1),.in2(reg2),.in3(reg3),
	// New additions 
	.inv0_0(vreg0_0), .inv0_1(vreg0_1), .inv0_2(vreg0_2), .inv0_3(vreg0_3), 
	.inv1_0(vreg1_0), .inv1_1(vreg1_1), .inv1_2(vreg1_2), .inv1_3(vreg1_3), 
	.inv2_0(vreg2_0), .inv2_1(vreg2_1), .inv2_2(vreg2_2), .inv2_3(vreg2_3), 
	.inv3_0(vreg3_0), .inv3_1(vreg3_1), .inv3_2(vreg3_2), .inv3_3(vreg3_3), 
	.selH(SW[8:5]), .counter(counterOut),
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
	.reset(reset),.clock(clock),.N(N),.Z(Z),.instr(IR[3:0]), .msbInstr(IR[7]),
	.PCwrite(PCWrite),.AddrSel(AddrSel),.MemRead(MemRead),.MemWrite(MemWrite),
	.IRload(IRLoad),.R1Sel(R1Sel),.MDRload(MDRLoad),.R1R2Load(R1R2Load),
	.ALU1(ALU1),.ALUOutWrite(ALUOutWrite),.RFWrite(RFWrite),.RegIn(RegIn),
	.FlagWrite(FlagWrite),.ALU2(ALU2),.ALUop(ALUOp), .stop(stop), 
	// New
	.VRFWrite(VRFWrite), .X1Load(X1Load), .X2Load(X2Load), .MemInSel(MemInSel), .VoutSel(VoutSel), 
	.t0load(t0load), .t1load(t1load), .t2load(t2load), .t3load(t3load), .R2sel(R2sel)
	
	
);

// Change R1wire to output of Mux so it is MemInWire
memory	DataMem(
	.MemRead(MemRead),.wren(MemWrite),.clock(clock),
	.address(AddrWire),.data(MemInWire),.q(MEMwire)
);

ALU		ALU(
	.in1(ALU1wire),.in2(ALU2wire),.out(ALUwire),
	.ALUOp(ALUOp),.N(Nwire),.Z(Zwire)
);

RF		RF_block(
	.clock(clock),.reset(reset),.RFWrite(RFWrite),
	.dataw(RegWire),.reg1(R1_in),.reg2(IR[5:4]),
	.regw(R1_in),.data1(RFout1wire),.data2(RFout2wire),
	.r0(reg0),.r1(reg1),.r2(reg2),.r3(reg3)
);

// NEW ADDITIONS
// VRF Block

VRF		VRF_block(
	.clock(clock),.reset(reset),.VRFWrite(VRFWrite),
	.vreg1(IR[7:6]),.vreg2(IR[5:4]),.vregw(IR[7:6]),
	.vdataw_0(vdataw_0wire), .vdataw_1(vdataw_1wire), .vdataw_2(vdataw_2wire), .vdataw_3(vdataw_3wire),
	.vdata1_0(VRFout1_0wire), .vdata1_1(VRFout1_1wire), .vdata1_2(VRFout1_2wire), .vdata1_3(VRFout1_3wire),
	.vdata2_0(VRFout2_0wire), .vdata2_1(VRFout2_1wire), .vdata2_2(VRFout2_2wire), .vdata2_3(VRFout2_3wire),
	.vr0_0(vreg0_0),.vr0_1(vreg0_1),.vr0_2(vreg0_2),.vr0_3(vreg0_3),
	.vr1_0(vreg1_0),.vr1_1(vreg1_1),.vr1_2(vreg1_2),.vr1_3(vreg1_3),
	.vr2_0(vreg2_0),.vr2_1(vreg2_1),.vr2_2(vreg2_2),.vr2_3(vreg2_3),
	.vr3_0(vreg3_0),.vr3_1(vreg3_1),.vr3_2(vreg3_2),.vr3_3(vreg3_3)
);

// X1 & X2 registers

register_8x4bit  X1(
	.clock(clock),.aclr(reset),.enable(X1Load),
	.data_0(VRFout1_0wire), .data_1(VRFout1_1wire), .data_2(VRFout1_2wire), .data_3(VRFout1_3wire),
	.q_0(X1out_0), .q_1(X1out_1), .q_2(X1out_2), .q_3(X1out_3) 
);

register_8x4bit  X2(
	.clock(clock),.aclr(reset),.enable(X2Load),
	.data_0(VRFout2_0wire), .data_1(VRFout2_1wire), .data_2(VRFout2_2wire), .data_3(VRFout2_3wire),
	.q_0(X2out_0), .q_1(X2out_1), .q_2(X2out_2), .q_3(X2out_3) 
);

// Mux 5-1 to Data_in of memory

mux5to1_8bit 		Mem_mux(
	.data0x(X1out_0),.data1x(X1out_1),.data2x(X1out_2),
	.data3x(X1out_3),.data4x(R1wire),.sel(MemInSel),.result(MemInWire)
);

// 4 Adders PLEASE

adder_8 a0(
	.in1(X1out_0), .in2(X2out_0), .out(add0) 
);

adder_8 a1(
	.in1(X1out_1), .in2(X2out_1), .out(add1) 
);

adder_8 a2(
	.in1(X1out_2), .in2(X2out_2), .out(add2) 	
);

adder_8 a3(
	.in1(X1out_3), .in2(X2out_3), .out(add3) 
);

// 4 2-1 Muxes PLEASE

mux2to1_8bit 		voutSel_mux0(
	.data0x(add0),.data1x(MEMwire),
	.sel(VoutSel),.result(vMux0)
);

mux2to1_8bit 		voutSel_mux1(
	.data0x(add1),.data1x(MEMwire),
	.sel(VoutSel),.result(vMux1)
);

mux2to1_8bit 		voutSel_mux2(
	.data0x(add2),.data1x(MEMwire),
	.sel(VoutSel),.result(vMux2)
);

mux2to1_8bit 		voutSel_mux3(
	.data0x(add3),.data1x(MEMwire),
	.sel(VoutSel),.result(vMux3)
);

// 4 Temp Registers PLEASE

register_8bit	temp0(
	.clock(clock),.aclr(reset),.enable(t0load),
	.data(vMux0),.q(vdataw_0wire)
);

register_8bit	temp1(
	.clock(clock),.aclr(reset),.enable(t1load),
	.data(vMux1),.q(vdataw_1wire)
);

register_8bit	temp2(
	.clock(clock),.aclr(reset),.enable(t2load),
	.data(vMux2),.q(vdataw_2wire)
);

register_8bit	temp3(
	.clock(clock),.aclr(reset),.enable(t3load),
	.data(vMux3),.q(vdataw_3wire)
);

// Now for editing R2... 

// Start with Adder
adder_8 plusOne(
	.in1(R2wire), .in2(constant), .out(plus1Wire) 
);

// Selection Mux for R2
mux2to1_8bit 		r2Sel_mux(
	.data0x(RFout2wire),.data1x(plus1Wire),
	.sel(R2sel),.result(R2MuxOut)
);

// DONE NEW ADDITIONS



register_8bit	IR_reg(
	.clock(clock),.aclr(reset),.enable(IRLoad),
	.data(MEMwire),.q(IR)
);

register_8bit	MDR_reg(
	.clock(clock),.aclr(reset),.enable(MDRLoad),
	.data(MEMwire),.q(MDRwire)
);

register_8bit	PC(
	.clock(clock),.aclr(reset),.enable(PCWrite),
	.data(ALUwire),.q(PCwire)
);

register_8bit	R1(
	.clock(clock),.aclr(reset),.enable(R1R2Load),
	.data(RFout1wire),.q(R1wire)
);

// Edit this to be inputted from MuxOut not RF2 directly may have to edit enable...
register_8bit	R2(
	.clock(clock),.aclr(reset),.enable(R1R2Load),
	.data(R2MuxOut),.q(R2wire)
);

register_8bit	ALUOut_reg(
	.clock(clock),.aclr(reset),.enable(ALUOutWrite),
	.data(ALUwire),.q(ALUOut)
);

mux2to1_2bit		R1Sel_mux(
	.data0x(IR[7:6]),.data1x(constant[1:0]),
	.sel(R1Sel),.result(R1_in)
);

mux2to1_8bit 		AddrSel_mux(
	.data0x(R2wire),.data1x(PCwire),
	.sel(AddrSel),.result(AddrWire)
);

mux2to1_8bit 		RegMux(
	.data0x(ALUOut),.data1x(MDRwire),
	.sel(RegIn),.result(RegWire)
);

mux2to1_8bit 		ALU1_mux(
	.data0x(PCwire),.data1x(R1wire),
	.sel(ALU1),.result(ALU1wire)
);

mux5to1_8bit 		ALU2_mux(
	.data0x(R2wire),.data1x(constant),.data2x(SE4wire),
	.data3x(ZE5wire),.data4x(ZE3wire),.sel(ALU2),.result(ALU2wire)
);

// Add Counter here 
counter             counter(
	.clock(clock), .reset(reset), .stop(stop), .counterOut(counterOut)
);



sExtend		SE4(.in(IR[7:4]),.out(SE4wire));
zExtend		ZE3(.in(IR[5:3]),.out(ZE3wire));
zExtend		ZE5(.in(IR[7:3]),.out(ZE5wire));
// define parameter for the data size to be extended
defparam	SE4.n = 4;
defparam	ZE3.n = 3;
defparam	ZE5.n = 5;

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
      LEDR[6] = AddrSel;
      LEDR[5] = MemRead;
      LEDR[4] = MemWrite;
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
      LEDR[0] = RegIn;
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
