// Major Functions:	Registers memory stores four 8-bits data
//					 
// Input(s):		1. reset: 	clear registers value to zero
//					2. clock: 	data written at positive clock edge
//					3. vreg1:	indicate which register will be 
//					   			output through (output)data1
//					4. vreg2:	indicate which register will be 
//								output through (output)data2
//					5. vregw:	indicate which register will be 
//								overwritten with the data from
//								(input)dataw
//					6. vdataw_0...vdataw_3:	input data to be written into register
//					7. VRFWrite:	write enable single, allow the data to
//								be written at the positive edge
//
// Output(s):		1. vdata1_0 - 1_3:	data output of the register (input)reg1
//					2. vdata2_0 - 2_3:	data output of the register (input)reg2
//					3. vr0_0...vr0_3,...vr3_3:	data stored by register0 to register3
//
// ---------------------------------------------------------------------

module VRF
(
clock, vreg1, vreg2, vregw,
VRFWrite, reset,
vdataw_0, vdataw_1, vdataw_2, vdataw_3,
vdata1_0, vdata1_1, vdata1_2, vdata1_3,
vdata2_0, vdata2_1, vdata2_2, vdata2_3,
vr0_0, vr0_1, vr0_2, vr0_3,
vr1_0, vr1_1, vr1_2, vr1_3,
vr2_0, vr2_1, vr2_2, vr2_3,
vr3_0, vr3_1, vr3_2, vr3_3
);

// ------------------------ PORT declaration ------------------------ //
input clock;
input [1:0] vreg1, vreg2, vregw;
input [7:0] vdataw_0, vdataw_1, vdataw_2, vdataw_3;
input VRFWrite;
input reset;
output [7:0] vdata1_0, vdata1_1, vdata1_2, vdata1_3, vdata2_0, vdata2_1, vdata2_2, vdata2_3;
output [7:0] vr0_0, vr0_1, vr0_2, vr0_3;
output [7:0] vr1_0, vr1_1, vr1_2, vr1_3;
output [7:0] vr2_0, vr2_1, vr2_2, vr2_3;
output [7:0] vr3_0, vr3_1, vr3_2, vr3_3;

// ------------------------- Registers/Wires ------------------------ //
reg [7:0] v0_0, v0_1, v0_2, v0_3;
reg [7:0] v1_0, v1_1, v1_2, v1_3;
reg [7:0] v2_0, v2_1, v2_2, v2_3;
reg [7:0] v3_0, v3_1, v3_2, v3_3;
reg [7:0] vdata1_0_tmp, vdata1_1_tmp, vdata1_2_tmp, vdata1_3_tmp;
reg [7:0] vdata2_0_tmp, vdata2_1_tmp, vdata2_2_tmp, vdata2_3_tmp;

// Asynchronously read data from two registers
always @(*)
begin
	case (vreg1)
		0: begin
			   vdata1_0_tmp = v0_0;
			   vdata1_1_tmp = v0_1;
			   vdata1_2_tmp = v0_2;
			   vdata1_3_tmp = v0_3;
		   end
		1: begin
			   vdata1_0_tmp = v1_0;
			   vdata1_1_tmp = v1_1;
			   vdata1_2_tmp = v1_2;
			   vdata1_3_tmp = v1_3;
		   end
		2: begin
			   vdata1_0_tmp = v2_0;
			   vdata1_1_tmp = v2_1;
			   vdata1_2_tmp = v2_2;
			   vdata1_3_tmp = v2_3;
		   end
		3: begin
			   vdata1_0_tmp = v3_0;
			   vdata1_1_tmp = v3_1;
			   vdata1_2_tmp = v3_2;
			   vdata1_3_tmp = v3_3;
		   end

	endcase
	case (vreg2)
		0: begin
			   vdata2_0_tmp = v0_0;
			   vdata2_1_tmp = v0_1;
			   vdata2_2_tmp = v0_2;
			   vdata2_3_tmp = v0_3;
		   end
		1: begin
			   vdata2_0_tmp = v1_0;
			   vdata2_1_tmp = v1_1;
			   vdata2_2_tmp = v1_2;
			   vdata2_3_tmp = v1_3;
		   end
		2: begin
			   vdata2_0_tmp = v2_0;
			   vdata2_1_tmp = v2_1;
			   vdata2_2_tmp = v2_2;
			   vdata2_3_tmp = v2_3;
		   end
		3: begin
			   vdata2_0_tmp = v3_0;
			   vdata2_1_tmp = v3_1;
			   vdata2_2_tmp = v3_2;
			   vdata2_3_tmp = v3_3;
		   end
	endcase
end

// Synchronously write data to the register file;
// also supports an asynchronous reset, which clears all registers
always @(posedge clock or posedge reset)
begin
	if (reset) begin
		v0_0 = 0;
		v0_1 = 0;
		v0_2 = 0;
		v0_3 = 0;
		v1_0 = 0;
		v1_1 = 0;
		v1_2 = 0;
		v1_3 = 0;
		v2_0 = 0;
		v2_1 = 0;
		v2_2 = 0;
		v2_3 = 0;
		v3_0 = 0;
		v3_1 = 0;
		v3_2 = 0;
		v3_3 = 0;
	end	else begin
		if (VRFWrite) begin
			case (vregw)
				0: begin
					   v0_0 = vdataw_0;
					   v0_1 = vdataw_1;
					   v0_2 = vdataw_2;
					   v0_3 = vdataw_3;
				   end
				1: begin
					   v1_0 = vdataw_0;
					   v1_1 = vdataw_1;
					   v1_2 = vdataw_2;
					   v1_3 = vdataw_3;
				   end
				2: begin
					   v2_0 = vdataw_0;
					   v2_1 = vdataw_1;
					   v2_2 = vdataw_2;
					   v2_3 = vdataw_3;
				   end
				3: begin
					   v3_0 = vdataw_0;
					   v3_1 = vdataw_1;
					   v3_2 = vdataw_2;
					   v3_3 = vdataw_3;
				   end
			endcase
		end
	end
end

// Assign temporary values to the outputs
assign vdata1_0 = vdata1_0_tmp;
assign vdata1_1 = vdata1_1_tmp;
assign vdata1_2 = vdata1_2_tmp;
assign vdata1_3 = vdata1_3_tmp;
assign vdata2_0 = vdata2_0_tmp;
assign vdata2_1 = vdata2_1_tmp;
assign vdata2_2 = vdata2_2_tmp;
assign vdata2_3 = vdata2_3_tmp;

assign vr0_0 = v0_0;
assign vr0_1 = v0_1;
assign vr0_2 = v0_2;
assign vr0_3 = v0_3;
assign vr1_0 = v1_0;
assign vr1_1 = v1_1;
assign vr1_2 = v1_2;
assign vr1_3 = v1_3;
assign vr2_0 = v2_0;
assign vr2_1 = v2_1;
assign vr2_2 = v2_2;
assign vr2_3 = v2_3;
assign vr3_0 = v3_0;
assign vr3_1 = v3_1;
assign vr3_2 = v3_2;
assign vr3_3 = v3_3;


endmodule