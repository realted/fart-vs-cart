// Fixed-length, little-endian groups. No packet headers/CRC are consumed here.
// All ports are synchronous to clk. GPU handshake ports require external CDC.

import params::*;

module uart_gpu_bridge #(
    parameter logic [15:0] INPUT_BASE = 16'd128,
    parameter logic [15:0] RESULT_BASE = 16'd128
)(
    input  logic clk,
    input  logic reset,
    input  logic [7:0] rx_data,
    input  logic rx_valid,
    output logic rx_ready,
    output logic rx_overflow, // Sticky until reset; rejected bytes require host recovery.
    output logic [7:0] tx_data,
    output logic tx_start,
    input  logic tx_busy,

    output logic [15:0] host_addr,
    output logic [15:0] host_wdata,
    output logic host_write,
    output logic host_read,
    input  logic host_ready,
    input  logic [15:0] host_rdata,
    input  logic host_rvalid,

    output logic gpu_start_req,
    input  logic gpu_done,
    output logic group_done // One clk pulse AFTER final result byte finishes.
);
    localparam int RX_AW = (RX_BUFFER_SZ > 1) ? $clog2(RX_BUFFER_SZ) : 1;
    localparam int TX_AW = (TX_BUFFER_SZ > 1) ? $clog2(TX_BUFFER_SZ) : 1;
    logic [15:0] rx_buffer [0:RX_BUFFER_SZ-1];
    logic [15:0] tx_buffer [0:TX_BUFFER_SZ-1];
    logic rx_full, tx_full;
    logic [7:0] low_byte;
    logic waiting_for_high;
    logic [RX_AW-1:0] rx_index, copy_index;
    logic [TX_AW-1:0] result_index, tx_index;
    logic tx_high_byte;

    typedef enum logic [2:0] {
        WAIT_INPUT, COPY_INPUT, WAIT_GPU_DONE, WAIT_GPU_CLEAR,
        READ_REQUEST, READ_RESPONSE
    } copy_state_t;
	
    typedef enum logic [1:0] {
        TX_IDLE, TX_SEND, TX_WAIT_BUSY, TX_WAIT_DONE
    } tx_state_t;
    copy_state_t copy_state;
    tx_state_t tx_state;

    // Request/data stay stable until accepted. host_ready on a WRITE must
    // mean that the word is committed to RAM (not merely queued elsewhere).
    // Reads permit either same-cycle or delayed host_rvalid; one outstanding.
    always_comb begin
        rx_ready = !reset && !rx_full;
        host_addr = INPUT_BASE + copy_index;
        host_wdata = rx_buffer[copy_index];
        host_write = !reset && (copy_state == COPY_INPUT);
        host_read = !reset && (copy_state == READ_REQUEST);
        if (copy_state == READ_REQUEST || copy_state == READ_RESPONSE)
            host_addr = RESULT_BASE + result_index;
        gpu_start_req = !reset && (copy_state == WAIT_GPU_DONE);
        tx_data = 8'd0;
        if (tx_full)
            tx_data = tx_high_byte ? tx_buffer[tx_index][15:8]
                                   : tx_buffer[tx_index][7:0];
        tx_start = !reset && (tx_state == TX_SEND) && !tx_busy;
    end

    // One owner for buffer flags. RX, transfer, and TX state machines run
    // independently; RX can fill the next group during GPU execution or TX.
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            copy_state <= WAIT_INPUT;
            tx_state <= TX_IDLE;
            rx_full <= 0;
            tx_full <= 0;
            low_byte <= 0;
            waiting_for_high <= 0;
            rx_index <= 0;
            copy_index <= 0;
            result_index <= 0;
            tx_index <= 0;
            tx_high_byte <= 0;
            rx_overflow <= 0;
            group_done <= 0;
        end else begin
            group_done <= 0;
            if (rx_valid) begin
                if (!rx_ready) begin
                    rx_overflow <= 1;
                end else if (!waiting_for_high) begin
                    low_byte <= rx_data;
                    waiting_for_high <= 1;
                end else begin
                    rx_buffer[rx_index] <= {rx_data, low_byte};
                    waiting_for_high <= 0;
                    if (rx_index == RX_BUFFER_SZ-1) begin
                        rx_index <= 0;
                        rx_full <= 1;
                    end else rx_index <= rx_index + 1'b1;
                end
            end

            case (copy_state)
                WAIT_INPUT: begin
                    // Do not overwrite working RAM until previous TX completes.
                    if (rx_full && !tx_full && !gpu_done) begin
                        copy_index <= 0;
                        copy_state <= COPY_INPUT;
                    end
                end
                COPY_INPUT: if (host_ready) begin
                    if (copy_index == RX_BUFFER_SZ-1) begin
                        copy_index <= 0;
                        rx_full <= 0;
                        copy_state <= WAIT_GPU_DONE;
                    end else copy_index <= copy_index + 1'b1;
                end
                WAIT_GPU_DONE: if (gpu_done) copy_state <= WAIT_GPU_CLEAR;
                WAIT_GPU_CLEAR: if (!gpu_done) begin
                    result_index <= 0;
                    copy_state <= READ_REQUEST;
                end
                READ_REQUEST: if (host_ready) begin
                    if (host_rvalid) begin
                        tx_buffer[result_index] <= host_rdata;
                        if (result_index == TX_BUFFER_SZ-1) begin
                            tx_full <= 1;
                            copy_state <= WAIT_INPUT;
                        end else result_index <= result_index + 1'b1;
                    end else copy_state <= READ_RESPONSE;
                end
                READ_RESPONSE: if (host_rvalid) begin
                    tx_buffer[result_index] <= host_rdata;
                    if (result_index == TX_BUFFER_SZ-1) begin
                        tx_full <= 1;
                        copy_state <= WAIT_INPUT;
                    end else begin
                        result_index <= result_index + 1'b1;
                        copy_state <= READ_REQUEST;
                    end
                end
                default: copy_state <= WAIT_INPUT;
            endcase

            case (tx_state)
                TX_IDLE: if (tx_full) begin
                    tx_index <= 0;
                    tx_high_byte <= 0;
                    tx_state <= TX_SEND;
                end
                TX_SEND: if (!tx_busy) tx_state <= TX_WAIT_BUSY;
                TX_WAIT_BUSY: if (tx_busy) tx_state <= TX_WAIT_DONE;
                TX_WAIT_DONE: if (!tx_busy) begin
                    if (!tx_high_byte) begin
                        tx_high_byte <= 1;
                        tx_state <= TX_SEND;
                    end else if (tx_index == TX_BUFFER_SZ-1) begin
                        tx_full <= 0;
                        group_done <= 1;
                        tx_state <= TX_IDLE;
                    end else begin
                        tx_index <= tx_index + 1'b1;
                        tx_high_byte <= 0;
                        tx_state <= TX_SEND;
                    end
                end
                default: tx_state <= TX_IDLE;
            endcase
        end
    end
endmodule
