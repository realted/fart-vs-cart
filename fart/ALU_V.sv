import params::*;

module ALU_V (in1, in2, out, ALUOp);

// ------------------------ PORT declaration ------------------------ //
input [DATA_BIT_WIDTH-1:0] in1, in2;
input [2:0] ALUOp;
output [DATA_BIT_WIDTH-1:0] out;

// ------------------------- Registers/Wires ------------------------ //
reg [DATA_BIT_WIDTH-1:0] tmp_out;
logic [DATA_BIT_WIDTH*2-1:0] product;

// -------------------------- ALU Operation ------------------------- //
// ALUOp encoding:													  //
//  000 = addition, 001 = subtraction, 010 = MULT,					  //
//  011 = NAND, and 100 = Shift										  //
// ------------------------------------------------------------------ //
always @(*)
begin
	if (ALUOp == 0) begin
		tmp_out = in1 + in2;
	end	else if (ALUOp == 1) begin
		tmp_out = in1 - in2;
	end	else if (ALUOp == 2) begin
		product = in1 * in2;
		tmp_out = product >>> 8;
	end	else if (ALUOp == 3) begin
		tmp_out = ~(in1 & in2);
	end	else if (ALUOp == 4) begin
		if (in2[2] == 1)
			tmp_out = in1 << in2[1:0];
		else
			tmp_out = in1 >> in2[1:0];
	end	else begin
		tmp_out = 0;
	end
end

// Assign output and condition flags
assign out = tmp_out;
assign N = out[DATA_BIT_WIDTH-1];
assign Z = (out == '0);

endmodule