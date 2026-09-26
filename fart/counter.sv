module counter (clock, reset, stop, counterOut);

// I/O

input clock, reset, stop;
output reg [15:0] counterOut;

always @(posedge clock)
begin
	if(reset) 
		counterOut <= 15'b000000000000000;
	else if(stop) 
		counterOut <= counterOut;
		
	else 
		counterOut <= counterOut + 1;
end

endmodule