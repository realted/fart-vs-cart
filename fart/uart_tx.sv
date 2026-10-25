import params::*;

module uart_tx (
    input  logic       clk,
    input  logic       start,
    input  logic       reset,
    input  logic [7:0] data,
    output logic       tx,
    output logic       busy
);

    typedef enum logic [1:0] {
        IDLE,
        START_BIT,
        DATA_BITS,
        STOP_BIT
    } state_t;

    state_t state;

    logic [7:0] saved_data;
    logic [2:0] bit_index;
    logic [8:0] baud_counter;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state        <= IDLE;
            tx           <= 1'b1;
            busy         <= 1'b0;
            saved_data   <= 8'b0;
            bit_index    <= 3'b0;
            baud_counter <= 9'b0;
        end
        else begin
            case (state)

                IDLE: begin
                    tx           <= 1'b1;
                    busy         <= 1'b0;
                    baud_counter <= 9'b0;
                    bit_index    <= 3'b0;

                    if (start) begin
                        saved_data <= data;
                        tx         <= 1'b0;
                        busy       <= 1'b1;
                        state      <= START_BIT;
                    end
                end

                START_BIT: begin
                    // tx stays low for one complete bit period.
                    if (baud_counter == UART_CLKS_PER_BIT - 1) begin
                        baud_counter <= 9'b0;
                        tx           <= saved_data[0];
                        state        <= DATA_BITS;
                    end
                    else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end

                DATA_BITS: begin
                    // Hold each data bit for one complete bit period.
                    if (baud_counter == UART_CLKS_PER_BIT - 1) begin
                        baud_counter <= 9'b0;

                        if (bit_index == 3'd7) begin
                            tx    <= 1'b1;
                            state <= STOP_BIT;
                        end
                        else begin
                            bit_index <= bit_index + 3'd1;
                            tx        <= saved_data[bit_index + 3'd1];
                        end
                    end
                    else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end

                STOP_BIT: begin
                    // tx stays high; busy stays high until stop finishes.
                    if (baud_counter == UART_CLKS_PER_BIT - 1) begin
                        baud_counter <= 9'b0;
                        busy         <= 1'b0;
                        state        <= IDLE;
                    end
                    else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end

                default: begin
                    state        <= IDLE;
                    tx           <= 1'b1;
                    busy         <= 1'b0;
                    saved_data   <= 8'b0;
                    bit_index    <= 3'b0;
                    baud_counter <= 9'b0;
                end

            endcase
        end
    end

endmodule