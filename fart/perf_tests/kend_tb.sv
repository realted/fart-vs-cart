`timescale 1ns/1ps
module kend_tb;
  reg clock=0, reset=1, N=0, Z=0, msbInstr=0;
  reg [11:0] instr=12'h002;
  wire kend_send;
  FSM dut(.clock(clock),.reset(reset),.N(N),.Z(Z),
          .instr(instr),.msbInstr(msbInstr),.kend_send(kend_send));
  always #5 clock=~clock;
  task tick;
    begin @(posedge clock); #1; end
  endtask
  initial begin
    tick; reset=0;
    tick; // fetch
    tick; // decode
    if(kend_send !== 0) $fatal(1,"premature pulse");
    tick; // KEND execution
    if(kend_send !== 1 || dut.vmaskreset !== 1) $fatal(1,"KEND not decoded");
    if(dut.RFWrite || dut.VRFWrite || dut.FlagWrite || dut.MemWrite || dut.PCwrite || dut.stop)
      $fatal(1,"unexpected KEND side effect");
    tick;
    if(kend_send !== 0 || dut.state !== dut.c1) $fatal(1,"pulse did not end");
    // NOP must continue and must not retain the KEND pulse.
    instr=12'h001; msbInstr=1;
    repeat(4) begin tick; if(kend_send !== 0) $fatal(1,"stale KEND pulse"); end
    // STOP retains its independent halt behavior.
    msbInstr=0;
    repeat(4) tick;
    if(dut.stop !== 1 || kend_send !== 0) $fatal(1,"STOP regression");
    $display("PASS: KEND decode, one-cycle pulse, mask reset, no writes, NOP/STOP");
    $finish;
  end
endmodule
