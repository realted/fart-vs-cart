import params::*;

module work_controller(
	clock,
	reset,
	workload_start,
	num_groups,
	kernel_done,
	restart_kernel,
	group_index,
	current_group_address,
	workload_busy,
	workload_done
);

	input clock;
	input reset;
	input workload_start;
	input [DATA_BIT_WIDTH-1:0] num_groups;
	input kernel_done;
	output restart_kernel;
	output logic [DATA_BIT_WIDTH-1:0] group_index;
	output logic [DATA_BIT_WIDTH-1:0] current_group_address;
	output logic workload_busy;
	output logic workload_done;

	localparam [15:0] INPUT_BASE   = 16'd128;
	localparam [15:0] GROUP_STRIDE = 16'd40;
	localparam [15:0] NUM_GROUPS   = 16'd3;
	localparam [15:0] KERNEL_ENTRY = 16'd0;


 typedef enum logic [2:0] {
    WC_IDLE,
	WC_LAUNCH,
    WC_RUN,
    WC_NEXT,
    WC_DONE
} workload_state_t;

workload_state_t wc_state;

// Combinational output: high only during LAUNCH
assign restart_kernel = (wc_state == WC_LAUNCH);
 
 always_ff @(posedge clock or posedge reset) begin
    if (reset) begin
        wc_state       <= WC_IDLE;
        group_index    <= 16'd0;
        workload_busy  <= 1'b0;
        workload_done  <= 1'b0;
    end
    else begin
        case (wc_state)

            WC_IDLE: begin
                workload_busy <= 1'b0;
                workload_done <= 1'b0;

                if (workload_start) begin
                    group_index <= 16'd0;
                    current_group_address <= INPUT_BASE;
                    if (num_groups == 0) begin
                        // Empty workload completes without launching the CPU.
                        workload_done <= 1'b1;
                        wc_state <= WC_DONE;
                    end else begin
                        workload_busy <= 1'b1;
                        wc_state <= WC_LAUNCH;
                    end
                end
            end

			WC_LAUNCH: begin
				wc_state <= WC_RUN;
            end

            WC_RUN: begin
                if (kernel_done) begin
                    wc_state <= WC_NEXT;
                end
            end

            WC_NEXT: begin
                if (group_index < num_groups - 1'b1) begin
                    group_index <= group_index + 1'b1;
					current_group_address <= current_group_address + GROUP_STRIDE;
                    wc_state    <= WC_LAUNCH;
                end

                else begin
                    workload_busy <= 1'b0;
                    workload_done <= 1'b1;
                    wc_state      <= WC_DONE;
                end
            end

            WC_DONE: begin
                if (!workload_start) begin
                    workload_done <= 1'b0;
                    wc_state      <= WC_IDLE;
                end
            end

        endcase
    end
end
endmodule
