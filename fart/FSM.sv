// 
// Input(s):	1. instr: input is used to determine states
//				2. N: if branches, input is used to determine if
//					  negative condition is true
//				3. Z: if branches, input is used to determine if 
//					  zero condition is true
//
// Output(s):	control signals
//
//				** More detail can be found on the course note under
//				   "Multi-Cycle Implementation: The Control Unit"
module FSM
(
reset, instr, msbInstr, clock,
N, Z,
PCwrite, MemRead,
MemWrite, IRload, R1Sel, MDRload, 
R1R2Load, ALU1, ALU2, ALUop,
ALUOutWrite, RFWrite, RegIn, FlagWrite, stop, //, state
// New control signals
VRFWrite, v_op, ldMask, vmaskreset, X1Load, X2Load, VoutSel,
vecstore
);
	input   [11:0] instr;
	input   msbInstr;
	input	N, Z;
	input	reset, clock;
	output	PCwrite, MemRead, IRload, R1Sel, MDRload, MemWrite;
	output	R1R2Load, ALU1, ALUOutWrite, RFWrite, RegIn, FlagWrite, stop;
	output	[2:0] ALU2, ALUop;

	// New Control Signals
	output  VRFWrite, X1Load, X2Load, VoutSel;
	
	// v0.2
	output logic ldMask, vmaskreset;
	output logic [3:0] v_op;
	
	//v0.4
	output logic vecstore;
	reg [5:0]	state;
	reg	PCwrite, MemRead, IRload, R1Sel, MDRload;
	reg	R1R2Load, ALU1, ALUOutWrite, RFWrite, RegIn, FlagWrite, stop;
	reg	[2:0] ALU2, ALUop;
	
	// New wires
	reg  VRFWrite, X1Load, X2Load, VoutSel, MemWrite;
	
	// state constants (note: asn = add/sub/nand, asnsh = add/sub/nand/shift)
	parameter [5:0] reset_s = 0, c1 = 1, c2 = 2, c3_asn = 3,
					c4_asnsh = 4, c3_shift = 5, c3_ori = 6,
					c4_ori = 7, c5_ori = 8, c3_load = 9, c4_load = 10,
					c3_store = 11, c3_bpz = 12, c3_bz = 13, c3_bnz = 14, c3_stop_nop = 15, c3_stop = 16, c3_nop = 17,
					
					// Define New States
					c3_vload = 18, c3_vstore = 19, c3_vadd = 20,
					
					// New states (v0.2)
					c3_vsub = 21, c3_vmul = 22, c3_vcmplt = 23, 
					c3_vcmpgt = 24, c3_vcmpeq = 25, c2_vcmclr = 26;
					
    // Scalars retain opcode [11:6] and six reserved low bits.
    // Eight-register vectors use opcode [9:4] and four reserved low bits.
	
    localparam [5:0] VLOAD_OP = 6'b100001, VSTORE_OP = 6'b100010,
                     VADD_OP = 6'b100100, VSUB_OP = 6'b100101,
                     VMUL_OP = 6'b100110, VCMPLT_OP = 6'b101000,
                     VCMPGT_OP = 6'b101001, VCMPEQ_OP = 6'b101010,
                     VCMCLR_OP = 6'b101111;
					 
    wire [5:0] vector_opcode = instr[9:4];
	
    wire vector_instruction = (instr[3:0] == 4'b0000) &&
        ((vector_opcode == VLOAD_OP) || (vector_opcode == VSTORE_OP) ||
         (vector_opcode == VADD_OP) || (vector_opcode == VSUB_OP) ||
         (vector_opcode == VMUL_OP) || (vector_opcode == VCMPLT_OP) ||
         (vector_opcode == VCMPGT_OP) || (vector_opcode == VCMPEQ_OP) ||
         (vector_opcode == VCMCLR_OP));
		 
	// determines the next state based upon the current state; supports
	// asynchronous reset
	always @(posedge clock or posedge reset)
	begin
		if (reset) state <= reset_s;
		else
		begin
			case(state)
				reset_s:	state <= c1; 		// reset state
				c1: 	    state <= c2;
                c2: begin
					if (vector_instruction) begin
						case (vector_opcode)
							VLOAD_OP:  state <= c3_vload;
							VSTORE_OP: state <= c3_vstore;
							VADD_OP:   state <= c3_vadd;
							VSUB_OP:   state <= c3_vsub;
							VMUL_OP:   state <= c3_vmul;
							VCMPLT_OP: state <= c3_vcmplt;
							VCMPGT_OP: state <= c3_vcmpgt;
							VCMPEQ_OP: state <= c3_vcmpeq;
							VCMCLR_OP: state <= c2_vcmclr;
							default:  state <= reset_s;
						endcase
					end
					else if (instr[5:0] == 6'b000000) begin
						case (instr[11:6])
							6'b000000: state <= c3_load;
							6'b000010: state <= c3_store;
							6'b000100,
							6'b000110,
							6'b001000: state <= c3_asn;
							default:  state <= reset_s;
						endcase
					end
					else if (instr[2:0] == 3'b011)  state <= c3_shift;
					else if (instr[2:0] == 3'b111)  state <= c3_ori;
					else if (instr[3:0] == 4'b1101) state <= c3_bpz;
					else if (instr[3:0] == 4'b0101) state <= c3_bz;
					else if (instr[3:0] == 4'b1001) state <= c3_bnz;
					else if (instr == 12'h001)     state <= c3_stop_nop;
					else                          state <= reset_s;
				end
				c3_asn:		state <= c4_asnsh;	// cycle 3: ADD SUB NAND
				c4_asnsh:	state <= c1;			// cycle 4: ADD SUB NAND/SHIFT
				c3_shift:	state <= c4_asnsh;	// cycle 3: SHIFT
				c3_ori:		state <= c4_ori;		// cycle 3: ORI
				c4_ori:		state <= c5_ori;		// cycle 4: ORI
				c5_ori:		state <= c1;			// cycle 5: ORI
				c3_load:	state <= c4_load;	// cycle 3: LOAD
				c4_load:	state <= c1; 		// cycle 4: LOAD
				c3_store:	state <= c1; 		// cycle 3: STORE
				c3_bpz:		state <= c1; 		// cycle 3: BPZ
				c3_bz:		state <= c1; 		// cycle 3: BZ
				c3_bnz:		state <= c1; 		// cycle 3: BNZ
				c3_stop_nop:  begin	
								if (msbInstr == 1'b1) state <= c3_nop;
								else if (msbInstr == 1'b0) state <= c3_stop;
							  end
				c3_stop:    state <= c3_stop;
				c3_nop:     state <= c1;
				c3_vload:	state <= c1;
				c3_vstore:	state <= c1;
				c3_vadd:    state <= c1;
				c3_vsub:    state <= c1;
				c3_vmul:    state <= c1;
				c3_vcmplt:    state <= c1;
				c3_vcmpgt:    state <= c1;
				c3_vcmpeq:    state <= c1;
				c2_vcmclr:	  state <= c1;
				default: state <= reset_s;
			endcase
		end
	end
	// sets the control sequences based upon the current state and instruction
	always @(*)
	begin
		case (state)
			reset_s:	//control = 19'b0000000000000000000;
				begin
					PCwrite = 0;					
					MemRead = 0;			
					IRload = 0;
					R1Sel = 0;
					MDRload = 0;
					R1R2Load = 0;
					ALU1 = 0;
					ALU2 = 3'b000;
					ALUop = 3'b000;
					ALUOutWrite = 0;
					RFWrite = 0;
					RegIn = 0;
					FlagWrite = 0;
					stop = 0;
					
					// v0
					VRFWrite = 0;
					X1Load = 0;
					X2Load = 0;
					VoutSel = 0;
					
					// v0.2
					v_op  = 4'b0000;
					ldMask = 0;
					vmaskreset = 0;
					
					// v0.4
					vecstore = 0;
					MemWrite = 0;
				end					
			c1: 		// PC = PC + 1
				begin
					PCwrite = 1;
					MemRead = 0; // Memread not necessary for PC anymore
					IRload = 1;
					R1Sel = 0;
					MDRload = 0;
					R1R2Load = 0;
					ALU1 = 0;
					ALU2 = 3'b001;
					ALUop = 3'b000;
					ALUOutWrite = 0;
					RFWrite = 0;
					RegIn = 0;
					FlagWrite = 0;
					stop = 0;
					
					// v0
					VRFWrite = 0;
					X1Load = 0;
					X2Load = 0;
					VoutSel = 0;
					
					// v0.2
					v_op  = 4'b0000;
					ldMask = 0;
					vmaskreset = 0;
										
					// v0.4
					vecstore = 0;
					MemWrite = 0;
				end	
				
			c2: 		// Load R1 R2 for scalar, Load X1, X2 based on the vector operation
				begin
					PCwrite     = 0;
					MemRead     = 0;
					MemWrite    = 0;
					IRload      = 0;
					R1Sel       = 0;
					MDRload     = 0;
					R1R2Load    = 1;

					ALU1        = 0;
					ALU2        = 3'b000;
					ALUop       = 3'b000;
					ALUOutWrite = 0;
					RFWrite     = 0;
					RegIn       = 0;
					FlagWrite   = 0;
					stop        = 0;

					VRFWrite    = 0;
					X1Load      = 0;
					X2Load      = 0;
					VoutSel     = 0;
					v_op        = 4'b0000;
					ldMask      = 0;
					vmaskreset  = 0;
					vecstore    = 0;

					if (vector_instruction) begin
						case (vector_opcode)
							VSTORE_OP: begin
								X1Load = 1;
							end

							VADD_OP, VSUB_OP, VMUL_OP,
							VCMPLT_OP, VCMPGT_OP, VCMPEQ_OP: begin
								X1Load = 1;
								X2Load = 1;
							end

							default: begin end
						endcase
					end
				end
				
			c3_asn:		
				begin
					if ( instr[11:6] == 6'b000100 ) 		// add
						//control = 19'b0000000010000001001;
					begin
						PCwrite = 0;
						MemRead = 0;
						MemWrite = 0;
						IRload = 0;
						R1Sel = 0;
						MDRload = 0;
						R1R2Load = 0;
						ALU1 = 1;
						ALU2 = 3'b000;
						ALUop = 3'b000;
						ALUOutWrite = 1;
						RFWrite = 0;
						RegIn = 0;
						FlagWrite = 1;
						stop = 0;
											
						// v0
						VRFWrite = 0;
						X1Load = 0;
						X2Load = 0;
						VoutSel = 0;
						
						// v0.2
						v_op  = 4'b0000;
						ldMask = 0;
						vmaskreset = 0;
											
						// v0.4
						vecstore = 0;


					end	
					else if ( instr[11:6] == 6'b000110 ) 	// sub
						//control = 19'b0000000010000011001;
					begin
						PCwrite = 0;
						MemRead = 0;
						MemWrite = 0;
						IRload = 0;
						R1Sel = 0;
						MDRload = 0;
						R1R2Load = 0;
						ALU1 = 1;
						ALU2 = 3'b000;
						ALUop = 3'b001;
						ALUOutWrite = 1;
						RFWrite = 0;
						RegIn = 0;
						FlagWrite = 1;
						stop = 0;						
					
						// v0
						VRFWrite = 0;
						X1Load = 0;
						X2Load = 0;
						VoutSel = 0;
						
						// v0.2
						v_op  = 4'b0000;
						ldMask = 0;
						vmaskreset = 0;
											
						// v0.4
						vecstore = 0;

					end
					else 							// nand
						//control = 19'b0000000010000111001;
					begin
						PCwrite = 0;
						MemRead = 0;
						MemWrite = 0;
						IRload = 0;
						R1Sel = 0;
						MDRload = 0;
						R1R2Load = 0;
						ALU1 = 1;
						ALU2 = 3'b000;
						ALUop = 3'b011;
						ALUOutWrite = 1;
						RFWrite = 0;
						RegIn = 0;
						FlagWrite = 1;
						stop = 0;						
					
						// v0
						VRFWrite = 0;
						X1Load = 0;
						X2Load = 0;
						VoutSel = 0;
						
						// v0.2
						v_op  = 4'b0000;
						ldMask = 0;
						vmaskreset = 0;
											
						// v0.4
						vecstore = 0;

					end
				end
				
			c4_asnsh: 	//control = 19'b0000000000000000100;
				begin
					PCwrite = 0;
					MemRead = 0;
					MemWrite = 0;
					IRload = 0;
					R1Sel = 0;
					MDRload = 0;
					R1R2Load = 0;
					ALU1 = 0;
					ALU2 = 3'b000;
					ALUop = 3'b000;
					ALUOutWrite = 0;
					RFWrite = 1;
					RegIn = 0;
					FlagWrite = 0;
					stop = 0;						
					
					// v0
					VRFWrite = 0;
					X1Load = 0;
					X2Load = 0;
					VoutSel = 0;
						
					// v0.2
					v_op  = 4'b0000;
					ldMask = 0;
					vmaskreset = 0;
											
					// v0.4
					vecstore = 0;

				end
				
			c3_shift: 	//control = 19'b0000000011001001001;
				begin
					PCwrite = 0;
					MemRead = 0;
					MemWrite = 0;
					IRload = 0;
					R1Sel = 0;
					MDRload = 0;
					R1R2Load = 0;
					ALU1 = 1;
					ALU2 = 3'b100;
					ALUop = 3'b100;
					ALUOutWrite = 1;
					RFWrite = 0;
					RegIn = 0;
					FlagWrite = 1;
					stop = 0;						
					
					// v0
					VRFWrite = 0;
					X1Load = 0;
					X2Load = 0;
					VoutSel = 0;
						
					// v0.2
					v_op  = 4'b0000;
					ldMask = 0;
					vmaskreset = 0;
											
					// v0.4
					vecstore = 0;

				end
				
			c3_ori: 	//control = 19'b0000010100000000000;
				begin
					PCwrite = 0;
					MemRead = 0;
					MemWrite = 0;
					IRload = 0;
					R1Sel = 1;
					MDRload = 0;
					R1R2Load = 1;
					ALU1 = 0;
					ALU2 = 3'b000;
					ALUop = 3'b000;
					ALUOutWrite = 0;
					RFWrite = 0;
					RegIn = 0;
					FlagWrite = 0;
					stop = 0;						
					
					// v0
					VRFWrite = 0;
					X1Load = 0;
					X2Load = 0;
					VoutSel = 0;
						
					// v0.2
					v_op  = 4'b0000;
					ldMask = 0;
					vmaskreset = 0;
											
					// v0.4
					vecstore = 0;

				end
				
			c4_ori: 	//control = 19'b0000000010110101001;
				begin
					PCwrite = 0;
					MemRead = 0;
					MemWrite = 0;
					IRload = 0;
					R1Sel = 0;
					MDRload = 0;
					R1R2Load = 0;
					ALU1 = 1;
					ALU2 = 3'b011;
					ALUop = 3'b010;
					ALUOutWrite = 1;
					RFWrite = 0;
					RegIn = 0;
					FlagWrite = 1;
					stop = 0;						
					
					// v0
					VRFWrite = 0;
					X1Load = 0;
					X2Load = 0;
					VoutSel = 0;
						
					// v0.2
					v_op  = 4'b0000;
					ldMask = 0;
					vmaskreset = 0;
											
					// v0.4
					vecstore = 0;

				end
				
			c5_ori: 	//control = 19'b0000010000000000100;
				begin
					PCwrite = 0;
					MemRead = 0;
					MemWrite = 0;
					IRload = 0;
					R1Sel = 1;
					MDRload = 0;
					R1R2Load = 0;
					ALU1 = 0;
					ALU2 = 3'b000;
					ALUop = 3'b000;
					ALUOutWrite = 0;
					RFWrite = 1;
					RegIn = 0;
					FlagWrite = 0;
					stop = 0;						
					
					// v0
					VRFWrite = 0;
					X1Load = 0;
					X2Load = 0;
					VoutSel = 0;
						
					// v0.2
					v_op  = 4'b0000;
					ldMask = 0;
					vmaskreset = 0;
											
					// v0.4
					vecstore = 0;

				end
				
			c3_load: 	//control = 19'b0010001000000000000;
				begin
					PCwrite = 0;
					MemRead = 1;
					MemWrite = 0;
					IRload = 0;
					R1Sel = 0;
					MDRload = 1;
					R1R2Load = 0;
					ALU1 = 0;
					ALU2 = 3'b000;
					ALUop = 3'b000;
					ALUOutWrite = 0;
					RFWrite = 0;
					RegIn = 0;
					FlagWrite = 0;
					stop = 0;						
					
					// v0
					VRFWrite = 0;
					X1Load = 0;
					X2Load = 0;
					VoutSel = 0;
						
					// v0.2
					v_op  = 4'b0000;
					ldMask = 0;
					vmaskreset = 0;
											
					// v0.4
					vecstore = 0;

				end
				
			c4_load: 	//control = 19'b0000000000000001110;
				begin
					PCwrite = 0;
					MemRead = 0;
					MemWrite = 0;
					IRload = 0;
					R1Sel = 0;
					MDRload = 0;
					R1R2Load = 0;
					ALU1 = 0;
					ALU2 = 3'b000;
					ALUop = 3'b000;
					ALUOutWrite = 1;
					RFWrite = 1;
					RegIn = 1;
					FlagWrite = 0;
					stop = 0;						
					
					// v0
					VRFWrite = 0;
					X1Load = 0;
					X2Load = 0;
					VoutSel = 0;
						
					// v0.2
					v_op  = 4'b0000;
					ldMask = 0;
					vmaskreset = 0;
											
					// v0.4
					vecstore = 0;

				end
				
			c3_store: 	//control = 19'b0001000000000000000;
				begin
					PCwrite = 0;
					MemRead = 0;
					MemWrite = 1;
					IRload = 0;
					R1Sel = 0;
					MDRload = 0;
					R1R2Load = 0;
					ALU1 = 0;
					ALU2 = 3'b000;
					ALUop = 3'b000;
					ALUOutWrite = 0;
					RFWrite = 0;
					RegIn = 0;
					FlagWrite = 0;
					stop = 0;						
					
					// v0
					VRFWrite = 0;
					X1Load = 0;
					X2Load = 0;
					VoutSel = 0;
						
					// v0.2
					v_op  = 4'b0000;
					ldMask = 0;
					vmaskreset = 0;
											
					// v0.4
					vecstore = 0;

				end
				
			c3_bpz: 	//control = {~N,18'b000000000100000000};
				begin
					PCwrite = ~N;
					MemRead = 0;
					MemWrite = 0;
					IRload = 0;
					R1Sel = 0;
					MDRload = 0;
					R1R2Load = 0;
					ALU1 = 0;
					ALU2 = 3'b010;
					ALUop = 3'b000;
					ALUOutWrite = 0;
					RFWrite = 0;
					RegIn = 0;
					FlagWrite = 0;
					stop = 0;						
					
					// v0
					VRFWrite = 0;
					X1Load = 0;
					X2Load = 0;
					VoutSel = 0;
						
					// v0.2
					v_op  = 4'b0000;
					ldMask = 0;
					vmaskreset = 0;
											
					// v0.4
					vecstore = 0;
				end
				
			c3_bz: 		//control = {Z,18'b000000000100000000};
				begin
					PCwrite = Z;
					MemRead = 0;
					MemWrite = 0;
					IRload = 0;
					R1Sel = 0;
					MDRload = 0;
					R1R2Load = 0;
					ALU1 = 0;
					ALU2 = 3'b010;
					ALUop = 3'b000;
					ALUOutWrite = 0;
					RFWrite = 0;
					RegIn = 0;
					FlagWrite = 0;
					stop = 0;						
					
					// v0
					VRFWrite = 0;
					X1Load = 0;
					X2Load = 0;
					VoutSel = 0;
						
					// v0.2
					v_op  = 4'b0000;
					ldMask = 0;
					vmaskreset = 0;
											
					// v0.4
					vecstore = 0;
				end
				
			c3_bnz: 	//control = {~Z,18'b000000000100000000};
				begin
					PCwrite = ~Z;
					MemRead = 0;
					MemWrite = 0;
					IRload = 0;
					R1Sel = 0;
					MDRload = 0;
					R1R2Load = 0;
					ALU1 = 0;
					ALU2 = 3'b010;
					ALUop = 3'b000;
					ALUOutWrite = 0;
					RFWrite = 0;
					RegIn = 0;
					FlagWrite = 0;
					stop = 0;						
					
					// v0
					VRFWrite = 0;
					X1Load = 0;
					X2Load = 0;
					VoutSel = 0;
						
					// v0.2
					v_op  = 4'b0000;
					ldMask = 0;
					vmaskreset = 0;
											
					// v0.4
					vecstore = 0;
				end
				
			c3_stop: 	//control = {~Z,18'b000000000100000000};
				begin
					PCwrite = 0;
					MemRead = 0;
					MemWrite = 0;
					IRload = 0;
					R1Sel = 0;
					MDRload = 0;
					R1R2Load = 0;
					ALU1 = 0;
					ALU2 = 3'b000;
					ALUop = 3'b000;
					ALUOutWrite = 0;
					RFWrite = 0;
					RegIn = 0;
					FlagWrite = 0;
					stop = 1;						
					
					// v0
					VRFWrite = 0;
					X1Load = 0;
					X2Load = 0;
					VoutSel = 0;
						
					// v0.2
					v_op  = 4'b0000;
					ldMask = 0;
					vmaskreset = 0;
											
					// v0.4
					vecstore = 0;
				end
				
			c3_nop: 	//control = {~Z,18'b000000000100000000};
				begin
					PCwrite = 0;
					MemRead = 0;
					MemWrite = 0;
					IRload = 0;
					R1Sel = 0;
					MDRload = 0;
					R1R2Load = 0;
					ALU1 = 0;
					ALU2 = 3'b000;
					ALUop = 3'b000;
					ALUOutWrite = 0;
					RFWrite = 0;
					RegIn = 0;
					FlagWrite = 0;
					stop = 0;						
					
					// v0
					VRFWrite = 0;
					X1Load = 0;
					X2Load = 0;
					VoutSel = 0;
						
					// v0.2
					v_op  = 4'b0000;
					ldMask = 0;
					vmaskreset = 0;
											
					// v0.4
					vecstore = 0;
				end

			
			c3_vload: 
				// MEM[R2...R2+3] ->VRF[IR[15:3]]
				begin
					PCwrite = 0;
					MemRead = 1; 
					IRload = 0;
					R1Sel = 0;
					MDRload = 0;
					R1R2Load = 0;
					ALU1 = 0;
					ALU2 = 3'b000;
					ALUop = 3'b000;
					ALUOutWrite = 0;
					RFWrite = 0;
					RegIn = 0;
					FlagWrite = 0;
					stop = 0;
					
					// v0
					VRFWrite = 1;
					X1Load = 0;
					X2Load = 0;
					VoutSel = 1;
					
					// v0.2
					v_op  = 4'b0000;
					ldMask = 0;
					vmaskreset = 0;
										
					// v0.4
					vecstore = 0;
					MemWrite = 0;
				end	
			
			c3_vstore: 	
				// MEM[R2...R2+3] <- X1
				begin
					PCwrite = 0;
					MemRead = 0; 
					IRload = 0;
					R1Sel = 0;
					MDRload = 0;
					R1R2Load = 0;
					ALU1 = 0;
					ALU2 = 3'b000;
					ALUop = 3'b000;
					ALUOutWrite = 0;
					RFWrite = 0;
					RegIn = 0;
					FlagWrite = 0;
					stop = 0;
					
					// v0
					VRFWrite = 0;
					X1Load = 0;
					X2Load = 0;
					VoutSel = 0;
					
					// v0.2
					v_op  = 4'b0000;
					ldMask = 0;
					vmaskreset = 0;
										
					// v0.4
					vecstore = 1;
					MemWrite = 1;
				end	

			c3_vadd: 	
				// X1 = X1 + X2
				begin
					PCwrite = 0;
					MemRead = 0; 
					IRload = 0;
					R1Sel = 0;
					MDRload = 0;
					R1R2Load = 0;
					ALU1 = 0;
					ALU2 = 3'b000;
					ALUop = 3'b000;
					ALUOutWrite = 0;
					RFWrite = 0;
					RegIn = 0;
					FlagWrite = 0;
					stop = 0;
					
					// v0
					VRFWrite = 1;
					X1Load = 0;
					X2Load = 0;
					VoutSel = 0;
					
					// v0.2
					v_op  = 4'b0000;
					ldMask = 0;
					vmaskreset = 0;
										
					// v0.4
					vecstore = 0;
					MemWrite = 0;
				end	
			
			c3_vsub: 	
				// X1 = X1 - X2
				begin
					PCwrite = 0;
					MemRead = 0; 
					IRload = 0;
					R1Sel = 0;
					MDRload = 0;
					R1R2Load = 0;
					ALU1 = 0;
					ALU2 = 3'b000;
					ALUop = 3'b000;
					ALUOutWrite = 0;
					RFWrite = 0;
					RegIn = 0;
					FlagWrite = 0;
					stop = 0;
					
					// v0
					VRFWrite = 1;
					X1Load = 0;
					X2Load = 0;
					VoutSel = 0;
					
					// v0.2
					v_op  = 4'b0001;
					ldMask = 0;
					vmaskreset = 0;
										
					// v0.4
					vecstore = 0;
					MemWrite = 0;
				end	
				
			c3_vmul: 	
				// X1 = X1 * X2
				begin
					PCwrite = 0;
					MemRead = 0; 
					IRload = 0;
					R1Sel = 0;
					MDRload = 0;
					R1R2Load = 0;
					ALU1 = 0;
					ALU2 = 3'b000;
					ALUop = 3'b000;
					ALUOutWrite = 0;
					RFWrite = 0;
					RegIn = 0;
					FlagWrite = 0;
					stop = 0;
					
					// v0
					VRFWrite = 1;
					X1Load = 0;
					X2Load = 0;
					VoutSel = 0;
					
					// v0.2
					v_op  = 4'b0010;
					ldMask = 0;
					vmaskreset = 0;
										
					// v0.4
					vecstore = 0;
					MemWrite = 0;
				end
				
			c3_vcmplt: 	
				begin
					PCwrite = 0;
					MemRead = 0; 
					IRload = 0;
					R1Sel = 0;
					MDRload = 0;
					R1R2Load = 0;
					ALU1 = 0;
					ALU2 = 3'b000;
					ALUop = 3'b000;
					ALUOutWrite = 0;
					RFWrite = 0;
					RegIn = 0;
					FlagWrite = 0;
					stop = 0;
					
					// v0
					VRFWrite = 0;
					X1Load = 0;
					X2Load = 0;
					VoutSel = 0;
					
					// v0.2
					v_op  = 4'b0011;
					ldMask = 1;
					vmaskreset = 0;
										
					// v0.4
					vecstore = 0;
					MemWrite = 0;
				end
				
			c3_vcmpgt: 	
				begin
					PCwrite = 0;
					MemRead = 0; 
					IRload = 0;
					R1Sel = 0;
					MDRload = 0;
					R1R2Load = 0;
					ALU1 = 0;
					ALU2 = 3'b000;
					ALUop = 3'b000;
					ALUOutWrite = 0;
					RFWrite = 0;
					RegIn = 0;
					FlagWrite = 0;
					stop = 0;
					
					// v0
					VRFWrite = 0;
					X1Load = 0;
					X2Load = 0;
					VoutSel = 0;
					
					// v0.2
					v_op  = 4'b0100;
					ldMask = 1;
					vmaskreset = 0;
										
					// v0.4
					vecstore = 0;
					MemWrite = 0;
				end
				
			c3_vcmpeq: 	
				begin
					PCwrite = 0;
					MemRead = 0; 
					IRload = 0;
					R1Sel = 0;
					MDRload = 0;
					R1R2Load = 0;
					ALU1 = 0;
					ALU2 = 3'b000;
					ALUop = 3'b000;
					ALUOutWrite = 0;
					RFWrite = 0;
					RegIn = 0;
					FlagWrite = 0;
					stop = 0;
					
					// v0
					VRFWrite = 0;
					X1Load = 0;
					X2Load = 0;
					VoutSel = 0;
					
					// v0.2
					v_op  = 4'b0101;
					ldMask = 1;
					vmaskreset = 0;
										
					// v0.4
					vecstore = 0;
					MemWrite = 0;
				end
				
			c2_vcmclr: 	
				begin
					PCwrite = 0;
					MemRead = 0; 
					IRload = 0;
					R1Sel = 0;
					MDRload = 0;
					R1R2Load = 0;
					ALU1 = 0;
					ALU2 = 3'b000;
					ALUop = 3'b000;
					ALUOutWrite = 0;
					RFWrite = 0;
					RegIn = 0;
					FlagWrite = 0;
					stop = 0;
					
					// v0
					VRFWrite = 0;
					X1Load = 0;
					X2Load = 0;
					VoutSel = 0;
					
					// v0.2
					v_op  = 4'b0000;
					ldMask = 0;
					vmaskreset = 1;
										
					// v0.4
					vecstore = 0;
					MemWrite = 0;
				end	
				
			default:	
				begin
					PCwrite = 0;
					MemRead = 0; 
					IRload = 0;
					R1Sel = 0;
					MDRload = 0;
					R1R2Load = 0;
					ALU1 = 0;
					ALU2 = 3'b000;
					ALUop = 3'b000;
					ALUOutWrite = 0;
					RFWrite = 0;
					RegIn = 0;
					FlagWrite = 0;
					stop = 0;
					
					// v0
					VRFWrite = 0;
					X1Load = 0;
					X2Load = 0;
					VoutSel = 0;
					
					// v0.2
					v_op  = 4'b0000;
					ldMask = 0;
					vmaskreset = 0;
										
					// v0.4
					vecstore = 0;
					MemWrite = 0;
				end
		endcase
	end
endmodule
