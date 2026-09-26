// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on
module register_8x4bit (
	aclr,
	clock,
	data_0, data_1, data_2, data_3,
	enable,
	q_0, q_1, q_2, q_3);

	input	  aclr;
	input	  clock;
	input	[7:0]  data_0, data_1, data_2, data_3;
	input	  enable;
	output reg	[7:0]  q_0, q_1, q_2, q_3;
	
	always @(posedge clock, posedge aclr)
	begin
		if (aclr) begin
			q_0 <= 8'b0;
			q_1 <= 8'b0;
			q_2 <= 8'b0;
			q_3 <= 8'b0;
		end
		else if (enable) begin
			q_0 <= data_0;
			q_1 <= data_1;
			q_2 <= data_2;
			q_3 <= data_3;
		end
	end

endmodule