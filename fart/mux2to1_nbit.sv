`timescale 1 ps / 1 ps

import params::*;


module mux2to1_nbit(
	data0x,
	data1x,
	sel,
	result);

	input	[DATA_BIT_WIDTH-1:0]  data0x;
	input	[DATA_BIT_WIDTH-1:0]  data1x;
	input	  sel;
	output	[DATA_BIT_WIDTH-1:0]  result;

	assign result = sel ? data1x : data0x;

endmodule

