import params::*;


module adder_n (in1, in2, out);
input [DATA_BIT_WIDTH-1:0] in1, in2;
output [DATA_BIT_WIDTH-1:0] out;

reg [DATA_BIT_WIDTH-1:0] tmp_out;

always @(*)
begin 
	tmp_out = in1 + in2;
end

assign out = tmp_out;	
endmodule