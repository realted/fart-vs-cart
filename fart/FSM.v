// ---------------------------------------------------------------------
// Copyright (c) 2007 by University of Toronto ECE 243 development team 
// ---------------------------------------------------------------------
//
// Major Functions:	control processor's datapath
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
//
// ---------------------------------------------------------------------

module FSM
(
reset, instr, msbInstr, clock,
N, Z,
PCwrite, AddrSel, MemRead,
MemWrite, IRload, R1Sel, MDRload,
R1R2Load, ALU1, ALU2, ALUop,
ALUOutWrite, RFWrite, RegIn, FlagWrite, stop, //, state
// New control signals
VRFWrite, X1Load, X2Load, MemInSel, VoutSel, 
t0load, t1load, t2load, t3load, R2sel

);
	input   [3:0] instr;
	input   msbInstr;
	input	N, Z;
	input	reset, clock;
	output	PCwrite, AddrSel, MemRead, MemWrite, IRload, R1Sel, MDRload;
	output	R1R2Load, ALU1, ALUOutWrite, RFWrite, RegIn, FlagWrite, stop;
	output	[2:0] ALU2, ALUop;
	//output	[3:0] state;
	
	// New Control Signals
	output  VRFWrite, X1Load, X2Load, VoutSel, t0load, t1load, t2load, t3load, R2sel;
	output [2:0] MemInSel;
	
	reg [4:0]	state;
	reg	PCwrite, AddrSel, MemRead, MemWrite, IRload, R1Sel, MDRload;
	reg	R1R2Load, ALU1, ALUOutWrite, RFWrite, RegIn, FlagWrite, stop;
	reg	[2:0] ALU2, ALUop;
	
	// New wires
	reg  VRFWrite, X1Load, X2Load, VoutSel, t0load, t1load, t2load, t3load, R2sel;
	reg [2:0] MemInSel;
	
	
	// state constants (note: asn = add/sub/nand, asnsh = add/sub/nand/shift)
	parameter [4:0] reset_s = 0, c1 = 1, c2 = 2, c3_asn = 3,
					c4_asnsh = 4, c3_shift = 5, c3_ori = 6,
					c4_ori = 7, c5_ori = 8, c3_load = 9, c4_load = 10,
					c3_store = 11, c3_bpz = 12, c3_bz = 13, c3_bnz = 14, c3_stop_nop = 15, c3_stop = 16, c3_nop = 17,
					// Define New States
					c2_vls = 18, c2_vadd = 19, 
					c3_vload = 20, c4_vload = 21, c5_vload = 22, c6_vload = 23, c7_vload = 24,
					c3_vstore = 25, c4_vstore = 26, c5_vstore = 27, c6_vstore = 28, 
					c3_vadd = 29, c4_vadd = 30;
	
	// determines the next state based upon the current state; supports
	// asynchronous reset
	always @(posedge clock or posedge reset)
	begin
		if (reset) state = reset_s;
		else
		begin
			case(state)
				reset_s:	state = c1; 		// reset state
				c1: 	    state = c2;
						
						
				c2:		begin				// cycle 2
							if(instr == 4'b0100 | instr == 4'b0110 | instr == 4'b1000) state = c3_asn;
							else if( instr[2:0] == 3'b011 ) state = c3_shift;
							else if( instr[2:0] == 3'b111 ) state = c3_ori;
							else if( instr == 4'b0000 ) state = c3_load;
							else if( instr == 4'b0010 ) state = c3_store;
							else if( instr == 4'b1101 ) state = c3_bpz;
							else if( instr == 4'b0101 ) state = c3_bz;
							else if( instr == 4'b1001 ) state = c3_bnz;
							else if( instr == 4'b0001) state = c3_stop_nop;
							else if (instr == 4'b1010 | instr == 4'b1100) state = c2_vls;
							else if (instr == 4'b1110) state = c2_vadd;
							else state = 0;
						end
				c3_asn:		state = c4_asnsh;	// cycle 3: ADD SUB NAND
				c4_asnsh:	state = c1;			// cycle 4: ADD SUB NAND/SHIFT
				c3_shift:	state = c4_asnsh;	// cycle 3: SHIFT
				c3_ori:		state = c4_ori;		// cycle 3: ORI
				c4_ori:		state = c5_ori;		// cycle 4: ORI
				c5_ori:		state = c1;			// cycle 5: ORI
				c3_load:	state = c4_load;	// cycle 3: LOAD
				c4_load:	state = c1; 		// cycle 4: LOAD
				c3_store:	state = c1; 		// cycle 3: STORE
				c3_bpz:		state = c1; 		// cycle 3: BPZ
				c3_bz:		state = c1; 		// cycle 3: BZ
				c3_bnz:		state = c1; 		// cycle 3: BNZ
				c3_stop_nop:  begin	
								if (msbInstr == 1'b1) state = c3_nop;
								else if (msbInstr == 1'b0) state = c3_stop;
							  end
				c3_stop:    state = c3_stop;
				c3_nop:     state = c1;
				
				// More New instructions
				c2_vls: begin 
							if (instr == 4'b1010) state = c3_vload;
							else state = c3_vstore;
						end
				c2_vadd:    state = c3_vadd;
				c3_vload:	state = c4_vload;
				c4_vload:	state = c5_vload;
				c5_vload:	state = c6_vload;
				c6_vload:	state = c7_vload;
				c7_vload:	state = c1;
				c3_vstore:	state = c4_vstore;
				c4_vstore:	state = c5_vstore;
				c5_vstore:	state = c6_vstore;
				c6_vstore:	state = c1;
				c3_vadd:    state = c4_vadd;
				c4_vadd:    state = c1;
				
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
					AddrSel = 0;
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
					MemInSel = 3'b100;
					R2sel = 0;
				end					
			c1: 		//control = 19'b1110100000010000000;
				begin
					PCwrite = 1;
					AddrSel = 1;
					MemRead = 1;
					MemWrite = 0;
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
					MemInSel = 3'b100;
					R2sel = 0;
					
					// New Part
					VRFWrite = 0;
					X1Load = 0;
					X2Load = 0;
					VoutSel = 0;
					t0load = 0;
					t1load = 0;
					t2load = 0;
					t3load = 0;
					R2sel = 0; 
					
				end	
			c2: 		//control = 19'b0000000100000000000;
				begin
					PCwrite = 0;
					AddrSel = 0;
					MemRead = 0;
					MemWrite = 0;
					IRload = 0;
					R1Sel = 0;
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
					MemInSel = 3'b100;
					R2sel = 0;
				end
			c3_asn:		begin
							if ( instr == 4'b0100 ) 		// add
								//control = 19'b0000000010000001001;
							begin
								PCwrite = 0;
								AddrSel = 0;
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
								MemInSel = 3'b100;
								R2sel = 0;
							end	
							else if ( instr == 4'b0110 ) 	// sub
								//control = 19'b0000000010000011001;
							begin
								PCwrite = 0;
								AddrSel = 0;
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
								MemInSel = 3'b100;
								R2sel = 0;
							end
							else 							// nand
								//control = 19'b0000000010000111001;
							begin
								PCwrite = 0;
								AddrSel = 0;
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
								MemInSel = 3'b100;
								R2sel = 0;
							end
				   		end
			c4_asnsh: 	//control = 19'b0000000000000000100;
				begin
					PCwrite = 0;
					AddrSel = 0;
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
					MemInSel = 3'b100;
					R2sel = 0;
				end
			c3_shift: 	//control = 19'b0000000011001001001;
				begin
					PCwrite = 0;
					AddrSel = 0;
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
					MemInSel = 3'b100;
					R2sel = 0;
				end
			c3_ori: 	//control = 19'b0000010100000000000;
				begin
					PCwrite = 0;
					AddrSel = 0;
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
					MemInSel = 3'b100;
					R2sel = 0;
				end
			c4_ori: 	//control = 19'b0000000010110101001;
				begin
					PCwrite = 0;
					AddrSel = 0;
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
					MemInSel = 3'b100;
					R2sel = 0;
				end
			c5_ori: 	//control = 19'b0000010000000000100;
				begin
					PCwrite = 0;
					AddrSel = 0;
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
					MemInSel = 3'b100;
					R2sel = 0;
				end
			c3_load: 	//control = 19'b0010001000000000000;
				begin
					PCwrite = 0;
					AddrSel = 0;
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
					MemInSel = 3'b100;
					R2sel = 0;
				end
			c4_load: 	//control = 19'b0000000000000001110;
				begin
					PCwrite = 0;
					AddrSel = 0;
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
					MemInSel = 3'b100;
					R2sel = 0;
				end
			c3_store: 	//control = 19'b0001000000000000000;
				begin
					PCwrite = 0;
					AddrSel = 0;
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
					MemInSel = 3'b100;
					R2sel = 0;
				end
			c3_bpz: 	//control = {~N,18'b000000000100000000};
				begin
					PCwrite = ~N;
					AddrSel = 0;
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
					MemInSel = 3'b100;
					R2sel = 0;
				end
			c3_bz: 		//control = {Z,18'b000000000100000000};
				begin
					PCwrite = Z;
					AddrSel = 0;
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
					MemInSel = 3'b100;
					R2sel = 0;
				end
			c3_bnz: 	//control = {~Z,18'b000000000100000000};
				begin
					PCwrite = ~Z;
					AddrSel = 0;
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
					MemInSel = 3'b100;
					R2sel = 0;
				end
			c3_stop: 	//control = {~Z,18'b000000000100000000};
				begin
					PCwrite = 0;
					AddrSel = 0;
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
					MemInSel = 3'b100;
					R2sel = 0;
				end
			c3_nop: 	//control = {~Z,18'b000000000100000000};
				begin
					PCwrite = 0;
					AddrSel = 0;
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
					MemInSel = 3'b100;
					R2sel = 0;
				end
				
				// New Control Instructions 
			c2_vls: 
				// VRF[IR[7..6]] = X1
				// VRF[IR[5..4]] = R2			
				begin
					PCwrite = 0;
					AddrSel = 0;
					MemRead = 0;
					MemWrite = 0;
					IRload = 0;
					R1Sel = 0;
					MDRload = 0;
					R1R2Load = 1;    // R1 value should not matter...
					ALU1 = 0;
					ALU2 = 3'b000;
					ALUop = 3'b000;
					ALUOutWrite = 0;
					RFWrite = 0;
					RegIn = 0;
					FlagWrite = 0;
					stop = 0;
					MemInSel = 3'b100;
					
					// New Part
					VRFWrite = 0;
					X1Load = 1;
					X2Load = 0;
					VoutSel = 0;
					t0load = 0;
					t1load = 0;
					t2load = 0;
					t3load = 0;
					R2sel = 0;
				end	
			
			c2_vadd: 
				// VRF[IR[7..6]] = X1
				// VRF[IR[5..4]] = X2			
				begin
					PCwrite = 0;
					AddrSel = 0;
					MemRead = 0;
					MemWrite = 0;
					IRload = 0;
					R1Sel = 0;
					MDRload = 0;
					R1R2Load = 0;    // R1 value should not matter...
					ALU1 = 0;
					ALU2 = 3'b000;
					ALUop = 3'b000;
					ALUOutWrite = 0;
					RFWrite = 0;
					RegIn = 0;
					FlagWrite = 0;
					stop = 0;
					MemInSel = 3'b100;
					
					// New Part
					VRFWrite = 0;
					X1Load = 1;
					X2Load = 1;
					VoutSel = 0;
					t0load = 0;
					t1load = 0;
					t2load = 0;
					t3load = 0;
					R2sel = 0;
				end	
				
			c3_vload: 
				// MEM[R2] = T0
				// MEM[R2] = MEM[R2 + 1]
				begin
					PCwrite = 0;
					AddrSel = 0;
					MemRead = 1;
					MemWrite = 0;
					IRload = 0;
					R1Sel = 0;
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
					MemInSel = 3'b100;
					
					// New Part
					VRFWrite = 0;
					X1Load = 0;
					X2Load = 0;
					VoutSel = 1;
					t0load = 1;
					t1load = 0;
					t2load = 0;
					t3load = 0;
					R2sel = 1;   //Enable new r value
				end	
				
			c4_vload: 
				// MEM[R2 + 1] = T1
				// MEM[R2 + 1] = MEM[R2 + 2]
				begin
					PCwrite = 0;
					AddrSel = 0;
					MemRead = 1;
					MemWrite = 0;
					IRload = 0;
					R1Sel = 0;
					MDRload = 0;
					R1R2Load = 1;    // R1 value should not matter...
					ALU1 = 0;
					ALU2 = 3'b000;
					ALUop = 3'b000;
					ALUOutWrite = 0;
					RFWrite = 0;
					RegIn = 0;
					FlagWrite = 0;
					stop = 0;
					MemInSel = 3'b100;
					
					// New Part
					VRFWrite = 0;
					X1Load = 0;
					X2Load = 0;
					VoutSel = 1;
					t0load = 0;
					t1load = 1;
					t2load = 0;
					t3load = 0;
					R2sel = 1;   //Enable new r value
				end	
			
			c5_vload: 
				// MEM[R2 + 2] = T2
				// MEM[R2 + 2] = MEM[R2 + 3]
				begin
					PCwrite = 0;
					AddrSel = 0;
					MemRead = 1;
					MemWrite = 0;
					IRload = 0;
					R1Sel = 0;
					MDRload = 0;
					R1R2Load = 1;    // R1 value should not matter...
					ALU1 = 0;
					ALU2 = 3'b000;
					ALUop = 3'b000;
					ALUOutWrite = 0;
					RFWrite = 0;
					RegIn = 0;
					FlagWrite = 0;
					stop = 0;
					MemInSel = 3'b100;
					
					// New Part
					VRFWrite = 0;
					X1Load = 0;
					X2Load = 0;
					VoutSel = 1;
					t0load = 0;
					t1load = 0;
					t2load = 1;
					t3load = 0;
					R2sel = 1;   //Enable new r value
				end	
				
			c6_vload: 
				// MEM[R2 + 3] = T3
				begin
					PCwrite = 0;
					AddrSel = 0;
					MemRead = 1;
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
					MemInSel = 3'b100;
					
					// New Part
					VRFWrite = 0;
					X1Load = 0;
					X2Load = 0;
					VoutSel = 1;
					t0load = 0;
					t1load = 0;
					t2load = 0;
					t3load = 1;
					R2sel = 0;   //Dont care
				end	
				
			c7_vload: 
				// VRF[T0[7..0]...T3[7..0]] = X1
				begin
					PCwrite = 0;
					AddrSel = 0;
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
					MemInSel = 3'b100;
					
					// New Part
					VRFWrite = 1;
					X1Load = 0;
					X2Load = 0;
					VoutSel = 0;
					t0load = 0;
					t1load = 0;
					t2load = 0;
					t3load = 1;
					R2sel = 0;   //Dont care
				end	
			
			
			c3_vstore: 	
				// MEM[R2] = X1_0
				begin
					PCwrite = 0;
					AddrSel = 0;
					MemRead = 0;
					MemWrite = 1;
					IRload = 0;
					R1Sel = 0;
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
					MemInSel = 3'b000;
				
				// New Part
					VRFWrite = 0;
					X1Load = 0;
					X2Load = 0;
					VoutSel = 0;
					t0load = 0;
					t1load = 0;
					t2load = 0;
					t3load = 0;
					R2sel = 1;  
				end	
			
			c4_vstore: 	
				// MEM[R2+1] = X1_1
				begin
					PCwrite = 0;
					AddrSel = 0;
					MemRead = 0;
					MemWrite = 1;
					IRload = 0;
					R1Sel = 0;
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
					MemInSel = 3'b001;
				
				// New Part
					VRFWrite = 0;
					X1Load = 0;
					X2Load = 0;
					VoutSel = 0;
					t0load = 0;
					t1load = 0;
					t2load = 0;
					t3load = 0;
					R2sel = 1;   
				end	
			
			c5_vstore: 	
				// MEM[R2+2] = X1_2
				begin
					PCwrite = 0;
					AddrSel = 0;
					MemRead = 0;
					MemWrite = 1;
					IRload = 0;
					R1Sel = 0;
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
					MemInSel = 3'b010;
				
				// New Part
					VRFWrite = 0;
					X1Load = 0;
					X2Load = 0;
					VoutSel = 0;
					t0load = 0;
					t1load = 0;
					t2load = 0;
					t3load = 0;
					R2sel = 1;   
				end	
			
			c6_vstore: 	
				// MEM[R2+3] = X1_3
				begin
					PCwrite = 0;
					AddrSel = 0;
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
					MemInSel = 3'b011;
				
				// New Part
					VRFWrite = 0;
					X1Load = 0;
					X2Load = 0;
					VoutSel = 0;
					t0load = 0;
					t1load = 0;
					t2load = 0;
					t3load = 0;
					R2sel = 0;   //Dont care
				end	
			
			c3_vadd: 	
				// T[0] ... T[3] = X1_0 + X2_0 ... X1_3 + X2_3
				begin
					PCwrite = 0;
					AddrSel = 0;
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
					MemInSel = 3'b100;
				
				// New Part
					VRFWrite = 0;
					X1Load = 0;
					X2Load = 0;
					VoutSel = 0;
					t0load = 1;
					t1load = 1;
					t2load = 1;
					t3load = 1;
					R2sel = 0;   
				end	
				
			c4_vadd: 	
				// X1 = [T[0] ... T[3]]
				begin
					PCwrite = 0;
					AddrSel = 0;
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
					MemInSel = 3'b100;
				
				// New Part
					VRFWrite = 1;
					X1Load = 0;
					X2Load = 0;
					VoutSel = 0;
					t0load = 0;
					t1load = 0;
					t2load = 0;
					t3load = 0;
					R2sel = 0;   
				end	
			
			
			default:	//control = 19'b0000000000000000000;
				begin
					PCwrite = 0;
					AddrSel = 0;
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
					
					// New Part
					VRFWrite = 0;
					X1Load = 0;
					X2Load = 0;
					VoutSel = 0;
					t0load = 0;
					t1load = 0;
					t2load = 0;
					t3load = 0;
					R2sel = 0;   
				end
							
			
			
			
		endcase
	end
	
endmodule
