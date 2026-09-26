`timescale 1 ps / 1 ps

import params::*;

module mux5to1_nbit (
	data0x,
	data1x,
	data2x,
	data3x,
	data4x,
	sel,
	result);

	input	[DATA_BIT_WIDTH-1:0]  data0x;
	input	[DATA_BIT_WIDTH-1:0]  data1x;
	input	[DATA_BIT_WIDTH-1:0]  data2x;
	input	[DATA_BIT_WIDTH-1:0]  data3x;
	input	[DATA_BIT_WIDTH-1:0]  data4x;
	input	[2:0]  sel;
	output reg [DATA_BIT_WIDTH-1:0]  result;

	always @(*)
	begin
		case (sel)
			3'b000: result <= data0x;
			3'b001: result <= data1x;
			3'b010: result <= data2x;
			3'b011: result <= data3x;
			3'b100: result <= data4x;
			default: result <= '0;
		endcase
	end
	
endmodule