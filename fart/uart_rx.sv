import params::*;

module uart_rx (
    input  logic       clk,
    input  logic       reset,
	 input  logic       rx,
    output logic [7:0] data,
    output logic       data_valid
);

    typedef enum logic [1:0] {
        IDLE,
        CHECK_START,
        DATA_BITS,
        CHECK_STOP
    } state_t;

    state_t state;

    logic [7:0] saved_data;
    logic [2:0] bit_index;
    logic [8:0] baud_counter;
	 
	 logic rx_meta;
    logic rx_sync;

    // Synchronize the external RX input.
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            rx_meta <= 1'b1;
            rx_sync <= 1'b1;
        end
        else begin
            rx_meta <= rx;
            rx_sync <= rx_meta;
        end
    end

	 
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state        <= IDLE;
            saved_data   <= 8'b0;
            bit_index    <= 3'b0;
            baud_counter <= 9'b0;
				data_valid   <= 1'b0;
				data         <= 8'b0;
        end
        else begin
            case (state)

                IDLE: begin
                    baud_counter <= 9'b0;
                    bit_index    <= 3'b0;
						  data_valid   <= 1'b0;

                    if (!rx_sync) begin
                        state      <= CHECK_START;
                    end
                end

                CHECK_START: begin
                    // Check if rx is low for half the period
                    if (baud_counter == UART_CLKS_PER_BIT/2 - 1) 
						  begin
								baud_counter <= 0;
                        if (!rx_sync) begin
									bit_index  <= 0;
									state      <= DATA_BITS;
								end
								else begin
									state <= IDLE;
								end
                    end
                    else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end

                DATA_BITS: begin
                    // Hold each data bit for one complete bit period.
                    if (baud_counter == UART_CLKS_PER_BIT - 1) begin
                        baud_counter <= 9'b0;
								saved_data[bit_index] <= rx_sync;
								
                        if (bit_index == 3'd7) begin
									state 		 <= CHECK_STOP;
                        end
                        else begin
                            bit_index <= bit_index + 3'd1;
                        end
                    end
                    else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end

                CHECK_STOP: begin
                    if (baud_counter == UART_CLKS_PER_BIT - 1) begin
                        baud_counter <= 9'b0;
								if (rx_sync) begin
									data <= saved_data;
									data_valid <= 1'b1;
								end
								state <= IDLE;
                    end
                    else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end

                default: begin
                    state        <= IDLE;
                    saved_data   <= 8'b0;
                    bit_index    <= 3'b0;
                    baud_counter <= 9'b0;
                end

            endcase
        end
    end

endmodule