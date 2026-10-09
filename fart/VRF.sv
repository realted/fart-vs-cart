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

import params::*;

module VRF
(
clock, vreg1, vreg2, vregw,
VRFWrite, VRFLaneWrite, reset,
vdataw_0, vdataw_1, vdataw_2, vdataw_3,
vdata1_0, vdata1_1, vdata1_2, vdata1_3,
vdata2_0, vdata2_1, vdata2_2, vdata2_3,
vr0_0, vr0_1, vr0_2, vr0_3,
vr1_0, vr1_1, vr1_2, vr1_3,
vr2_0, vr2_1, vr2_2, vr2_3,
vr3_0, vr3_1, vr3_2, vr3_3,
vr4_0, vr4_1, vr4_2, vr4_3,
vr5_0, vr5_1, vr5_2, vr5_3,
vr6_0, vr6_1, vr6_2, vr6_3,
vr7_0, vr7_1, vr7_2, vr7_3
);

// ------------------------ PORT declaration ------------------------ //
input clock;
input [2:0] vreg1, vreg2, vregw;
input [DATA_BIT_WIDTH-1:0] vdataw_0, vdataw_1, vdataw_2, vdataw_3;
input VRFWrite;
input [3:0] VRFLaneWrite;
input reset;
output [DATA_BIT_WIDTH-1:0] vdata1_0, vdata1_1, vdata1_2, vdata1_3, vdata2_0, vdata2_1, vdata2_2, vdata2_3;

// Hex Display
output [DATA_BIT_WIDTH-1:0] vr0_0, vr0_1, vr0_2, vr0_3;
output [DATA_BIT_WIDTH-1:0] vr1_0, vr1_1, vr1_2, vr1_3;
output [DATA_BIT_WIDTH-1:0] vr2_0, vr2_1, vr2_2, vr2_3;
output [DATA_BIT_WIDTH-1:0] vr3_0, vr3_1, vr3_2, vr3_3;

output [DATA_BIT_WIDTH-1:0] vr4_0, vr4_1, vr4_2, vr4_3;
output [DATA_BIT_WIDTH-1:0] vr5_0, vr5_1, vr5_2, vr5_3;
output [DATA_BIT_WIDTH-1:0] vr6_0, vr6_1, vr6_2, vr6_3;
output [DATA_BIT_WIDTH-1:0] vr7_0, vr7_1, vr7_2, vr7_3;

// ------------------------- Registers/Wires ------------------------ //
reg [DATA_BIT_WIDTH-1:0] v0_0, v0_1, v0_2, v0_3;
reg [DATA_BIT_WIDTH-1:0] v1_0, v1_1, v1_2, v1_3;
reg [DATA_BIT_WIDTH-1:0] v2_0, v2_1, v2_2, v2_3;
reg [DATA_BIT_WIDTH-1:0] v3_0, v3_1, v3_2, v3_3;

reg [DATA_BIT_WIDTH-1:0] v4_0, v4_1, v4_2, v4_3;
reg [DATA_BIT_WIDTH-1:0] v5_0, v5_1, v5_2, v5_3;
reg [DATA_BIT_WIDTH-1:0] v6_0, v6_1, v6_2, v6_3;
reg [DATA_BIT_WIDTH-1:0] v7_0, v7_1, v7_2, v7_3;

reg [DATA_BIT_WIDTH-1:0] vdata1_0_tmp, vdata1_1_tmp, vdata1_2_tmp, vdata1_3_tmp;
reg [DATA_BIT_WIDTH-1:0] vdata2_0_tmp, vdata2_1_tmp, vdata2_2_tmp, vdata2_3_tmp;


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
		4: begin
			   vdata1_0_tmp = v4_0;
			   vdata1_1_tmp = v4_1;
			   vdata1_2_tmp = v4_2;
			   vdata1_3_tmp = v4_3;
		   end
		5: begin
			   vdata1_0_tmp = v5_0;
			   vdata1_1_tmp = v5_1;
			   vdata1_2_tmp = v5_2;
			   vdata1_3_tmp = v5_3;
		   end
		6: begin
			   vdata1_0_tmp = v6_0;
			   vdata1_1_tmp = v6_1;
			   vdata1_2_tmp = v6_2;
			   vdata1_3_tmp = v6_3;
		   end
		7: begin
			   vdata1_0_tmp = v7_0;
			   vdata1_1_tmp = v7_1;
			   vdata1_2_tmp = v7_2;
			   vdata1_3_tmp = v7_3;
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
		4: begin
			   vdata2_0_tmp = v4_0;
			   vdata2_1_tmp = v4_1;
			   vdata2_2_tmp = v4_2;
			   vdata2_3_tmp = v4_3;
		   end
		5: begin
			   vdata2_0_tmp = v5_0;
			   vdata2_1_tmp = v5_1;
			   vdata2_2_tmp = v5_2;
			   vdata2_3_tmp = v5_3;
		   end
		6: begin
			   vdata2_0_tmp = v6_0;
			   vdata2_1_tmp = v6_1;
			   vdata2_2_tmp = v6_2;
			   vdata2_3_tmp = v6_3;
		   end
		7: begin
			   vdata2_0_tmp = v7_0;
			   vdata2_1_tmp = v7_1;
			   vdata2_2_tmp = v7_2;
			   vdata2_3_tmp = v7_3;
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
		v4_0 = 0;
		v4_1 = 0;
		v4_2 = 0;
		v4_3 = 0;
		v5_0 = 0;
		v5_1 = 0;
		v5_2 = 0;
		v5_3 = 0;
		v6_0 = 0;
		v6_1 = 0;
		v6_2 = 0;
		v6_3 = 0;
		v7_0 = 0;
		v7_1 = 0;
		v7_2 = 0;
		v7_3 = 0;
	end	else begin
		if (VRFWrite) begin
			case (vregw)
				0: begin
					if (VRFLaneWrite[0]) v0_0 <= vdataw_0;
					if (VRFLaneWrite[1]) v0_1 <= vdataw_1;
					if (VRFLaneWrite[2]) v0_2 <= vdataw_2;
					if (VRFLaneWrite[3]) v0_3 <= vdataw_3;
				   end
				1: begin
					if (VRFLaneWrite[0]) v1_0 <= vdataw_0;
					if (VRFLaneWrite[1]) v1_1 <= vdataw_1;
					if (VRFLaneWrite[2]) v1_2 <= vdataw_2;
					if (VRFLaneWrite[3]) v1_3 <= vdataw_3;
				   end
				2: begin
					if (VRFLaneWrite[0]) v2_0 <= vdataw_0;
					if (VRFLaneWrite[1]) v2_1 <= vdataw_1;
					if (VRFLaneWrite[2]) v2_2 <= vdataw_2;
					if (VRFLaneWrite[3]) v2_3 <= vdataw_3;
				   end
				3: begin
					if (VRFLaneWrite[0]) v3_0 <= vdataw_0;
					if (VRFLaneWrite[1]) v3_1 <= vdataw_1;
					if (VRFLaneWrite[2]) v3_2 <= vdataw_2;
					if (VRFLaneWrite[3]) v3_3 <= vdataw_3;
				   end
				4: begin
					if (VRFLaneWrite[0]) v4_0 <= vdataw_0;
					if (VRFLaneWrite[1]) v4_1 <= vdataw_1;
					if (VRFLaneWrite[2]) v4_2 <= vdataw_2;
					if (VRFLaneWrite[3]) v4_3 <= vdataw_3;
				   end
				5: begin
					if (VRFLaneWrite[0]) v5_0 <= vdataw_0;
					if (VRFLaneWrite[1]) v5_1 <= vdataw_1;
					if (VRFLaneWrite[2]) v5_2 <= vdataw_2;
					if (VRFLaneWrite[3]) v5_3 <= vdataw_3;
				   end
				6: begin
					if (VRFLaneWrite[0]) v6_0 <= vdataw_0;
					if (VRFLaneWrite[1]) v6_1 <= vdataw_1;
					if (VRFLaneWrite[2]) v6_2 <= vdataw_2;
					if (VRFLaneWrite[3]) v6_3 <= vdataw_3;
				   end
				7: begin
					if (VRFLaneWrite[0]) v7_0 <= vdataw_0;
					if (VRFLaneWrite[1]) v7_1 <= vdataw_1;
					if (VRFLaneWrite[2]) v7_2 <= vdataw_2;
					if (VRFLaneWrite[3]) v7_3 <= vdataw_3;
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
assign vr4_0 = v4_0;
assign vr4_1 = v4_1;
assign vr4_2 = v4_2;
assign vr4_3 = v4_3;
assign vr5_0 = v5_0;
assign vr5_1 = v5_1;
assign vr5_2 = v5_2;
assign vr5_3 = v5_3;
assign vr6_0 = v6_0;
assign vr6_1 = v6_1;
assign vr6_2 = v6_2;
assign vr6_3 = v6_3;
assign vr7_0 = v7_0;
assign vr7_1 = v7_1;
assign vr7_2 = v7_2;
assign vr7_3 = v7_3;

endmodule