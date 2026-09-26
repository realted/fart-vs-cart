// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on

import params::*;

module register_nbit (
	aclr,
	clock,
	data,
	enable,
	q);

	input	  aclr;
	input	  clock;
	input	[DATA_BIT_WIDTH-1:0]  data;
	input	  enable;
	output reg	[DATA_BIT_WIDTH-1:0]  q;
	
	always @(posedge clock, posedge aclr)
	begin
		if (aclr)
			q <= '0;
		else if (enable)
			q <= data;
	end

endmodule