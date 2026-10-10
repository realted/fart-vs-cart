// InstructionMemory.sv

import params::*;

// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on

module InstructionMemory (
    input  [7:0]  address,
    input         clock,
    output [15:0] q
);

    wire [15:0] sub_wire0;

    assign q = sub_wire0;

    altsyncram altsyncram_component (
        .clock0           (clock),
        .address_a        (address),
        .q_a              (sub_wire0),

        .wren_a           (1'b0),
        .data_a           (16'b0),

        .aclr0            (1'b0),
        .aclr1            (1'b0),
        .address_b        (1'b1),
        .addressstall_a   (1'b0),
        .addressstall_b   (1'b0),
        .byteena_a        (1'b1),
        .byteena_b        (1'b1),
        .clock1           (1'b1),
        .clocken0         (1'b1),
        .clocken1         (1'b1),
        .clocken2         (1'b1),
        .clocken3         (1'b1),
        .data_b           (1'b1),
        .eccstatus        (),
        .q_b              (),
        .rden_a           (1'b1),
        .rden_b           (1'b1),
        .wren_b           (1'b0)
    );

    defparam
        altsyncram_component.clock_enable_input_a = "BYPASS",
        altsyncram_component.clock_enable_output_a = "BYPASS",

        // Separate program image
        altsyncram_component.init_file = "program.mif",

        // Change this to match your actual FPGA family
        altsyncram_component.intended_device_family = "Cyclone II",

        altsyncram_component.lpm_hint = "ENABLE_RUNTIME_MOD=NO",
        altsyncram_component.lpm_type = "altsyncram",

        // 256 instructions
        altsyncram_component.numwords_a = 256,

        altsyncram_component.operation_mode = "SINGLE_PORT",
        altsyncram_component.outdata_aclr_a = "NONE",
        altsyncram_component.outdata_reg_a = "UNREGISTERED",
        altsyncram_component.power_up_uninitialized = "FALSE",

        // 8-bit instruction address
        altsyncram_component.widthad_a = 8,

        // 16-bit instruction
        altsyncram_component.width_a = 16,

        altsyncram_component.width_byteena_a = 1;

endmodule