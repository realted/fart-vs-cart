# UART GPU bridge integration

The bridge implements raw fixed-length, little-endian groups: by default 40 input
words (80 bytes), 20 output words (40 bytes). Compile params.sv first. Buffer sizes
default to the package constants and must be positive. INPUT_BASE and RESULT_BASE
default to 128. There is no packet header, checksum, READY byte, or group ID yet.

## Connections

Run the bridge and both UART modules on CLOCK_50 with the same reset.

| Bridge port | Connection / contract |
|---|---|
| rx_data, rx_valid | uart_rx.data and uart_rx.data_valid |
| tx_data, tx_start, tx_busy | uart_tx.data, uart_tx.start, uart_tx.busy |
| rx_ready | Group-buffer capacity indication; NOT automatically transmitted to the PC |
| rx_overflow | Sticky error: a byte arrived while RX was full; reset and resend to recover stream alignment |
| host_addr, host_wdata, host_write, host_read | Memory adapter request interface |
| host_ready | Adapter accepts a request at the rising edge; for writes this must mean the RAM write is committed |
| host_rdata, host_rvalid | Read response; same-cycle response with acceptance or delayed response supported |
| gpu_start_req | Level request; synchronize into the GPU clock domain |
| gpu_done | Completion level synchronized back into CLOCK_50 |
| group_done | One CLOCK_50 pulse after the final result byte finishes transmitting |

Only one memory read is outstanding. The bridge holds requests, addresses and
write data until accepted. The memory adapter must not report completion of a
queued write before it actually reaches RAM. Add a flush acknowledgement instead
if using a queued adapter. Memory reads must return exactly once per accepted
request, in order. Only permit host RAM access while the GPU is idle.

Configure each GPU invocation for ONE group, base 128, entry 0. The bridge repeats
indefinitely as complete groups arrive; it does not count a total host workload.
The four constant words at 252..255 must already be initialized for test6.

GPU handshake: request rises after the last input write; GPU runs and holds done
high; bridge lowers request on observing done; GPU clears done; bridge starts
result reads only after observing done low. Keep the GPU clock running while idle.
Do not directly wire asynchronous request/done signals across clock domains.

## Buffer ownership and overlap

RX writes each completed word directly to its buffer, marks full after the final
word, and blocks further bytes until the whole buffer is copied into working RAM.
It can then receive the next group while computation or TX is active. TX reads
only a completely captured result buffer. The next GPU run waits until the previous
TX buffer has drained. This permits UART RX/TX overlap without overwriting results.

The UART has no incoming-byte backpressure. The C++ side must obey a flow-control
protocol: either expose rx_ready through a suitable physical handshake or add
framed READY/status responses with a single owner of the UART transmitter. Do not
mix unframed control bytes into these raw result bytes. A conservative initial
host sends one group and waits for its entire result, which works without overlap.
Incomplete groups wait indefinitely; framing, timeout recovery, and checksums are
future protocol work. rx_overflow does not reconstruct a damaged stream.

## Implementation

Three concurrent paths share one sequential owner for flags: RX byte packing,
input-copy/GPU-handshake/result-copy states, and TX byte handshake states.
Buffer contents are not reset; indexes and valid/full flags are reset instead.
The arrays have combinational read selection and may synthesize to registers or
distributed memory. Replacing them with synchronous-read RAM requires read-wait
states; do not substitute a one-cycle RAM without adjusting the controller.

No GPU memory ports or top-level wiring are added by this module. Those remain
integration work, and MIF initialization can remain available.

## Regression simulation

From perf_tests in ModelSim:

```tcl
vlib bridge_sim
vlog -work bridge_sim -sv ../params.sv ../uart_gpu_bridge.sv ../uart_tx.sv ../uart_rx.sv uart_gpu_bridge_tb.sv
vsim bridge_sim.bridge_tb
run -all
```

The test models a memory adapter with backpressure/delayed reads and a GPU with
held completion. It uses the actual UART TX/RX modules for result serialization.
It checks two groups, RX/TX overlap, result ordering, final-byte completion and
overflow/reset. It is not a full GPU integration or Quartus timing test.
