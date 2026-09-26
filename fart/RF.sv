
import params::*;

module RF
(
clock, reg1, reg2, regw,
dataw, RFWrite, data1, data2,
r0, r1, r2, r3, reset
);

// ------------------------ PORT declaration ------------------------ //
input clock;
input [1:0] reg1, reg2, regw;
input [DATA_BIT_WIDTH-1:0] dataw;
input RFWrite;
input reset;
output [DATA_BIT_WIDTH-1:0] data1, data2;
output [DATA_BIT_WIDTH-1:0] r0, r1, r2, r3;

// ------------------------- Registers/Wires ------------------------ //
reg [DATA_BIT_WIDTH-1:0] k0, k1, k2, k3;
reg [DATA_BIT_WIDTH-1:0] data1_tmp, data2_tmp;

// Asynchronously read data from two registers
always @(*)
begin
	case (reg1)
		0: data1_tmp = k0;
		1: data1_tmp = k1;
		2: data1_tmp = k2;
		3: data1_tmp = k3;
	endcase
	case (reg2)
		0: data2_tmp = k0;
		1: data2_tmp = k1;
		2: data2_tmp = k2;
		3: data2_tmp = k3;
	endcase
end

// Synchronously write data to the register file;
// also supports an asynchronous reset, which clears all registers
always @(posedge clock or posedge reset)
begin
	if (reset) begin
		k0 = 0;
		k1 = 0;
		k2 = 0;
		k3 = 0;
	end	else begin
		if (RFWrite) begin
			case (regw)
				0: k0 = dataw;
				1: k1 = dataw;
				2: k2 = dataw;
				3: k3 = dataw;
			endcase
		end
	end
end

// Assign temporary values to the outputs
assign data1 = data1_tmp;
assign data2 = data2_tmp;

assign r0 = k0;
assign r1 = k1;
assign r2 = k2;
assign r3 = k3;

endmodule
