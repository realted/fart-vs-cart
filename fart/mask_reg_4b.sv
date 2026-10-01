import params::*;

module mask_reg_4b (clock, aclr, d, ldMask, vmaskreset, q);

input clock, aclr, vmaskreset;
input [3:0] d;
input ldMask;

output logic [3:0] q;

always_ff @(posedge clock, posedge aclr) 
	begin
		if (aclr) 
			q <= 4'b1111;
		else if (vmaskreset)
			q <= 4'b1111;
		else if (ldMask) 
			q <= d;
	end
	
endmodule
	