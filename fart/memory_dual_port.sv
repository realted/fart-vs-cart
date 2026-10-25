// One 256 x 16 bank. Port A preserves the original memory.sv timing:
// memory access on the clock_1 falling edge; q_1 is zero when rden_1 is low.
// Port B samples requests on clock_2 rising edges. Its unregistered output
// settles AFTER that edge; a synchronous adapter may capture it at the next edge.
// No reset/reload: INIT_FILE initializes RAM at configuration time only.
// The system must prevent conflicting port-1/port-2 accesses to the same location.
module memory_dual_port #(
    parameter INIT_FILE = "data_1.mif"
)(
    input  wire clock_1,
    input  wire rden_1,
    input  wire wren_1,
    input  wire [7:0] address_1,
    input  wire [15:0] data_1,
    output wire [15:0] q_1,

    input  wire clock_2,
    input  wire rden_2,
    input  wire wren_2,
    input  wire [7:0] address_2,
    input  wire [15:0] data_2,
    output wire [15:0] q_2
);
    wire [15:0] raw_q_1;
    assign q_1 = rden_1 ? raw_q_1 : 16'd0;

    altsyncram #(
        .operation_mode("BIDIR_DUAL_PORT"),
        .intended_device_family("Cyclone V"),
        .lpm_type("altsyncram"),
        .lpm_hint("ENABLE_RUNTIME_MOD=NO"),
        .init_file(INIT_FILE),
        .power_up_uninitialized("FALSE"),
        .numwords_a(256), .numwords_b(256),
        .width_a(16), .width_b(16),
        .widthad_a(8), .widthad_b(8),
        .width_byteena_a(1), .width_byteena_b(1),
        .address_reg_b("CLOCK1"),
        .indata_reg_b("CLOCK1"),
        .wrcontrol_wraddress_reg_b("CLOCK1"),
        .outdata_reg_a("UNREGISTERED"),
        .outdata_reg_b("UNREGISTERED"),
        .outdata_aclr_a("NONE"), .outdata_aclr_b("NONE"),
        .clock_enable_input_a("BYPASS"),
        .clock_enable_input_b("BYPASS"),
        .clock_enable_output_a("BYPASS"),
        .clock_enable_output_b("BYPASS"),
        .read_during_write_mode_mixed_ports("DONT_CARE")
    ) ram (
        .clock0(~clock_1), .clock1(clock_2),
        .address_a(address_1), .data_a(data_1), .wren_a(wren_1),
        .rden_a(1'b1), .q_a(raw_q_1),
        .address_b(address_2), .data_b(data_2), .wren_b(wren_2),
        .rden_b(rden_2), .q_b(q_2),
        .aclr0(1'b0), .aclr1(1'b0),
        .addressstall_a(1'b0), .addressstall_b(1'b0),
        .byteena_a(1'b1), .byteena_b(1'b1),
        .clocken0(1'b1), .clocken1(1'b1),
        .clocken2(1'b1), .clocken3(1'b1), .eccstatus()
    );
endmodule
