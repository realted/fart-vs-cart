// ---------------------------------------------------------------------
// Copyright (c) 2007 by University of Toronto ECE 243 development team 
// ---------------------------------------------------------------------
//
// HEX: one nibble to an active-low seven-segment digit.
// HEXs: one selected register across HEX5..HEX0 (most to least significant).
// At DATA_BIT_WIDTH=16: HEX3..HEX2 = high byte, HEX1..HEX0 = low byte;
// HEX5 and HEX4 are blank. Partial nibbles are zero-padded.
// selH: 0..3 = scalar registers; 4..19 = vector lanes in row-major order;
// 31 = 16-bit counter; other selections blank all digits.
// Six digits hold 24 bits. For wider registers, DISPLAY_PAGE selects a
// 24-bit chunk (0 = least significant). It is a compile-time parameter.
// Compile params.sv before this file. WIDTH must be positive.

module chooseHEXs #(
    parameter integer WIDTH = params::DATA_BIT_WIDTH,
    parameter integer BYTE_PAGE = 0
)(
    input [WIDTH-1:0] in0, in1, in2, in3,
    input [1:0] select,
    output [6:0] out1, out0
);
    // Legacy two-digit interface: select one byte of a wider register.
    reg [WIDTH-1:0] selected;
    wire [7:0] selected_byte;
    always @(*) begin
        case (select)
            2'd0: selected = in0;
            2'd1: selected = in1;
            2'd2: selected = in2;
            2'd3: selected = in3;
            default: selected = '0;
        endcase
    end
    assign selected_byte = selected >> (8 * BYTE_PAGE);
    HEX hex0(selected_byte[7:4], out1);
    HEX hex1(selected_byte[3:0], out0);
endmodule

module HEXs #(
    parameter integer WIDTH = params::DATA_BIT_WIDTH,
    parameter integer DISPLAY_PAGE = 0
)(
    input [WIDTH-1:0] in0, in1, in2, in3,
    input [WIDTH-1:0] inv0_0, inv0_1, inv0_2, inv0_3,
    input [WIDTH-1:0] inv1_0, inv1_1, inv1_2, inv1_3,
    input [WIDTH-1:0] inv2_0, inv2_1, inv2_2, inv2_3,
    input [WIDTH-1:0] inv3_0, inv3_1, inv3_2, inv3_3,
    input [4:0] selH,
    input [15:0] counter,
    output [6:0] out0, out1, out2, out3, out4, out5
);
    reg [WIDTH-1:0] selected;
    reg valid;
    reg [23:0] display_value;
    reg [5:0] digit_enable;
    wire [6:0] segments [0:5];
    integer digit;

    always @(*) begin
        selected = '0;
        valid = 1'b1;
        case (selH)
            5'd0: selected = in0;
            5'd1: selected = in1;
            5'd2: selected = in2;
            5'd3: selected = in3;
            5'd4: selected = inv0_0;
            5'd5: selected = inv0_1;
            5'd6: selected = inv0_2;
            5'd7: selected = inv0_3;
            5'd8: selected = inv1_0;
            5'd9: selected = inv1_1;
            5'd10: selected = inv1_2;
            5'd11: selected = inv1_3;
            5'd12: selected = inv2_0;
            5'd13: selected = inv2_1;
            5'd14: selected = inv2_2;
            5'd15: selected = inv2_3;
            5'd16: selected = inv3_0;
            5'd17: selected = inv3_1;
            5'd18: selected = inv3_2;
            5'd19: selected = inv3_3;
            default: valid = 1'b0;
        endcase

        display_value = selected >> (24 * DISPLAY_PAGE);
        digit_enable = 6'b000000;
        for (digit = 0; digit < 6; digit = digit + 1) begin
            if (valid && ((24 * DISPLAY_PAGE + 4 * digit) < WIDTH))
                digit_enable[digit] = 1'b1;
        end
        if (selH == 5'd31) begin
            display_value = {8'b0, counter};
            digit_enable = 6'b001111;
        end
    end

    genvar d;
    generate
        for (d = 0; d < 6; d = d + 1) begin : decode_digits
            HEX decoder(display_value[4*d +: 4], segments[d]);
        end
    endgenerate
    assign out0 = digit_enable[0] ? segments[0] : 7'b1111111;
    assign out1 = digit_enable[1] ? segments[1] : 7'b1111111;
    assign out2 = digit_enable[2] ? segments[2] : 7'b1111111;
    assign out3 = digit_enable[3] ? segments[3] : 7'b1111111;
    assign out4 = digit_enable[4] ? segments[4] : 7'b1111111;
    assign out5 = digit_enable[5] ? segments[5] : 7'b1111111;
endmodule

module HEX (in, out);
input 	[3:0] in;
output 	[6:0] out;

reg [6:0] out;


always @(*)
begin
	case (in)
		0: out = 7'b1000000;
		1: out = 7'b1111001;
		2: out = 7'b0100100;
		3: out = 7'b0110000;
		4: out = 7'b0011001;
		5: out = 7'b0010010;
		6: out = 7'b0000010;
		7: out = 7'b1111000;
		8: out = 7'b0000000;
		9: out = 7'b0010000;
		10: out = 7'b0001000;
		11: out = 7'b0000011;
		12: out = 7'b1000110;
		13: out = 7'b0100001;
		14: out = 7'b0000110;
		15: out = 7'b0001110;
		default: out = 7'b1111111;
	endcase
end

endmodule
