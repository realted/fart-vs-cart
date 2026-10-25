# FPGA ray/sphere UART test (Windows)

Standalone C++17 test for the current FPGA test6 discriminant kernel. No SDL or
CUDA dependency. Existing CPU/CUDA renderers are not modified. Their sphere
intersection routines in src/CPU/objects.hpp and src/GPU_cuda/objects_cuda.cuh
use half-B and positive roots; this test reproduces that floating-point check
for context and separately models every FPGA Q8.8 operation for verification.
It does not execute CUDA or render an image.

## Build and run

From this folder, with MinGW g++:

```powershell
g++ -std=c++17 -O2 -Wall -Wextra -Wpedantic -static fpga_ray_test.cpp -o fpga_ray_test.exe
.\fpga_ray_test.exe --self-test
.\fpga_ray_test.exe
.\fpga_ray_test.exe --port COM5
```

Or build with MSVC in a Developer Command Prompt:

```text
cl /std:c++17 /EHsc /W4 fpga_ray_test.cpp /Fe:fpga_ray_test.exe
```

Replace COM5 with your adapter's COM port. No port is opened without --port.
The default is ten real rays, three four-lane groups, with two duplicate padding
lanes in the last group. Only ten rays are printed, but all 60 returned words,
including padding, are checked. Inputs are deterministic cases from test6 with
hits, misses and tangency. For ten GROUPS (40 rays), use --rays 40; the twelve-case
dataset repeats rather than generating new random rays.

Options: --rays N, --baud N (default 1000000), --timeout-ms N (default 15000 per
read/write transfer), --self-test, --vectors DIR, --help. --vectors writes inputs.hex
and expected.hex for RTL replay. Exit 0 means success, 1 is setup/I/O failure, and
2 means returned FPGA words mismatched. A CPU-only run is explicitly labeled and
does not claim board verification.

## Board preparation

1. Compile/program the UART-enabled GPU (UART_MODE=1) with the UART, bridge,
   decoder and dual-port memory sources included in Quartus.
2. Assign rx/tx pins and appropriate I/O standards for your board/adapter. Connect
   adapter TX to FPGA RX, adapter RX to FPGA TX, and common ground using compatible
   logic-level UART hardware.
3. Load test6_12ray_controller.s as program.mif before compiling/programming;
   initialize bank memory so words 252..255 each contain 0x0100. The host sends
   only ray inputs, not instructions or those shared constants.
4. UART setting: 1,000,000 baud, 8N1, no RTS/CTS or XON/XOFF. This matches the
   current 50 MHz / UART_CLKS_PER_BIT=50 configuration.
5. Close any terminal using the COM port. Reset the FPGA before the first run,
   particularly after an interrupted/failed transfer. Run with --port COMn.

The current divided GPU clock is approximately 100 Hz, so computation can take
roughly three seconds per group. Do not reduce the timeout below compute latency.
Board return data is displayed as a discriminant/hit flag and compared exactly
against a,b,c,delta,flags. The float_forward_hit column tests positive sphere roots;
the FPGA flag tests only delta >= 0. They need not agree for arbitrary inputs.

## Wire protocol

No header, group count, START byte, newline or checksum is sent. Each transaction:

* Send exactly 80 bytes = 40 Q8.8 words, low byte first.
* Wait for exactly 40 bytes = 20 result words, low byte first.
* Then send the next group. This intentionally does not require READY packets.

Input vector order: Ox[4], Cx[4], Dx[4], Oy[4], Cy[4], Dy[4], Oz[4], Cz[4],
Dz[4], radius[4]. Results: a[4], b[4], c[4], delta[4], flag[4]. Hit flags are
0x0100 or 0x0000. All groups reuse working base 128, with kernel entry 0.

Q8.8 multiplication uses signed products, rounds negative values down when
discarding eight bits, and wraps to 16 bits after every operation, matching the
RTL. Do not use floating-point discriminants as the bit-exact expected values.

The serial implementation disables automatic flow control and loops over partial
reads/writes. It aborts on serial errors, timeout or mismatch. A failed raw stream
cannot be safely resumed mid-group; reset the FPGA before retrying. It does not
automatically reset the board or upload a bitstream.

## Verification performed

* Built with g++ using warnings enabled.
* Self-test compares 60 independently listed test6 golden words, signed multiply
  truncation, wrapping, and byte serialization.
* C++-generated ten-ray input/expected files replayed through ModelSim with the
  current UART RX/TX, bridge, dual-port RAM, work controller, and GPU. Three groups
  produced all 60 expected result words. CPU clock was accelerated in the testbench.
* Physical COM-port/board execution has not been performed. One existing RTL
  instruction-address-width warning remains; no new RTL changes were made.
