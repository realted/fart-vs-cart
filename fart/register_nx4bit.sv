import params::*;


// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on
module register_nx4bit (
	aclr,
	clock,
	data_0, data_1, data_2, data_3,
	enable,
	q_0, q_1, q_2, q_3);

	input	  aclr;
	input	  clock;
	input	[DATA_BIT_WIDTH-1:0]  data_0, data_1, data_2, data_3;
	input	  enable;
	output reg	[DATA_BIT_WIDTH-1:0]  q_0, q_1, q_2, q_3;
	
	always @(posedge clock, posedge aclr)
	begin
		if (aclr) begin
			q_0 <= '0;
			q_1 <= '0;
			q_2 <= '0;
			q_3 <= '0;
		end
		else if (enable) begin
			q_0 <= data_0;
			q_1 <= data_1;
			q_2 <= data_2;
			q_3 <= data_3;
		end
	end

endmodule