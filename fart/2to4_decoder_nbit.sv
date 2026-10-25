module decoder2to4 (
    input  logic [1:0] in,
    input  logic       en,
    output logic [3:0] result
);

    always_comb begin
        result = 4'b0000;

        if (en) begin
            case (in)
                2'b00: result = 4'b0001;
                2'b01: result = 4'b0010;
                2'b10: result = 4'b0100;
                2'b11: result = 4'b1000;
            endcase
        end
    end

endmodule