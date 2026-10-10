`timescale 1 ps / 1 ps

import params::*;


module mux4to1_nbit(
	data0x,
	data1x,
	data2x,
	data3x,
	sel,
	result);

	input	[DATA_BIT_WIDTH-1:0]  data0x;
	input	[DATA_BIT_WIDTH-1:0]  data1x;
	input	[DATA_BIT_WIDTH-1:0]  data2x;
	input	[DATA_BIT_WIDTH-1:0]  data3x;
	input	[1:0]				  sel;
	output	reg [DATA_BIT_WIDTH-1:0]  result;

	always @(*)
	begin
		case (sel)
			2'b00: result <= data0x;
			2'b01: result <= data1x;
			2'b10: result <= data2x;
			2'b11: result <= data3x;
			default: result <= '0;
		endcase
	end

endmodule

