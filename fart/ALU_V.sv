import params::*;

module ALU_V (in1, in2, out, mask, v_op);

// ------------------------ PORT declaration ------------------------ //
input [DATA_BIT_WIDTH-1:0] in1, in2;
input [3:0] v_op;
output logic [DATA_BIT_WIDTH-1:0] out;
output logic mask;

// ------------------------- Registers/Wires ------------------------ //
logic signed [DATA_BIT_WIDTH*2-1:0] product;

// -------------------------- ALU Operation ------------------------- //
// ALUOp encoding:													  //
//  0000 = addition, 0001 = subtraction, 0010 = multiplication,       //
//  0011 = Lane Compare Less Than, 0100 = Lane Compare Greater Than,  //
//  0101 = Lane Compare Equals, 0110 = Mask Clear	                  //
// ------------------------------------------------------------------ //
    always_comb begin
        out     = '0;
        mask    = 1'b0;
        product = '0;

        case (v_op)
            4'd0: out = in1 + in2;
            4'd1: out = in1 - in2;

            4'd2: begin
                product = $signed(in1) * $signed(in2);
                out = product >>> 8;
				end

            4'd3: mask = ($signed(in1) < $signed(in2));
            4'd4: mask = ($signed(in1) > $signed(in2));
            4'd5: mask = (in1 == in2);
            4'd6: mask = 1'b1;

            default: begin end
        endcase
    end
endmodule