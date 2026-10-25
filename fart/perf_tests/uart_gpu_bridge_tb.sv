`timescale 1ns/1ps
module bridge_tb;
reg clk=0, reset=1;
always #5 clk=~clk;
reg [7:0] rx_data=0;
reg rx_valid=0;
wire rx_ready,overflow,tx_start,tx_busy,serial,decoded_valid;
wire [7:0] tx_data,decoded;
wire [15:0] addr,wdata;
wire wr,rd,start,group_done;
reg ready=0,rvalid=0,done=0;
reg [15:0] rdata=0;
reg [15:0] mem[0:1023];
integer cycles=0,writes=0,launches=0,received=0,completions=0;
integer delay_read=0,gpu_delay=0,saved_addr=0,i;
reg prev_start=0;
uart_gpu_bridge dut(.clk(clk),.reset(reset),.rx_data(rx_data),.rx_valid(rx_valid),
.rx_ready(rx_ready),.rx_overflow(overflow),.tx_data(tx_data),.tx_start(tx_start),.tx_busy(tx_busy),
.host_addr(addr),.host_wdata(wdata),.host_write(wr),.host_read(rd),.host_ready(ready),
.host_rdata(rdata),.host_rvalid(rvalid),.gpu_start_req(start),.gpu_done(done),.group_done(group_done));
uart_tx tx(.clk(clk),.reset(reset),.data(tx_data),.start(tx_start),.busy(tx_busy),.tx(serial));
uart_rx rx(.clk(clk),.reset(reset),.rx(serial),.data(decoded),.data_valid(decoded_valid));
// Memory writes commit on acceptance, reads return after a variable delay.
always @(posedge clk) if(!reset) begin
 cycles=cycles+1;
 ready <= cycles%3!=0 && delay_read==0;
 rvalid <= 0;
 if(wr && ready) begin
   if(addr !== 128+writes%40 || wdata !== (writes/40)*256+writes%40)
     $fatal(1,"input write mismatch %0d addr=%0d data=%h",writes,addr,wdata);
   mem[addr] <= wdata; writes=writes+1;
 end
 if(rd && ready) begin saved_addr=addr; delay_read=4; ready<=0; end
 else if(delay_read>0) begin
   delay_read=delay_read-1;
   if(delay_read==0) begin rdata<=mem[saved_addr]; rvalid<=1; end
 end
 if(start && !prev_start) begin
   if(writes!=(launches+1)*40) $fatal(1,"launch before copy complete");
   if(launches>0 && completions!=launches) $fatal(1,"launch before TX drained");
   launches=launches+1; gpu_delay=8;
 end
 if(gpu_delay>0) begin
   gpu_delay=gpu_delay-1;
   if(gpu_delay==0) begin
     for(integer j=0;j<20;j=j+1) mem[128+j] <= 16'hA000+(launches-1)*256+j;
     done<=1;
   end
 end
 if(done && !start) done<=0;
 prev_start=start;
 if(decoded_valid) begin
   if(decoded !== ((received%2==0) ? (received/2)%20 : 8'hA0+received/40))
      $fatal(1,"TX mismatch at byte %0d: %h",received,decoded);
   received=received+1;
 end
 if(group_done) begin
   completions=completions+1;
   if(tx_busy || received!=completions*40) $fatal(1,"early completion");
 end
end
task send_group(input integer group_id);
begin
 for(integer j=0;j<40;j=j+1) begin
   @(negedge clk); if(!rx_ready) $fatal(1,"unexpected RX backpressure");
   rx_data=j;rx_valid=1;
   @(negedge clk);rx_data=group_id;
 end
 @(negedge clk);rx_valid=0;
end endtask
initial begin
 #22;reset=0;
 send_group(0);
 wait(tx_busy); send_group(1); // Actual RX/TX overlap.
 wait(completions==2);
 if(writes!=80 || launches!=2 || overflow) $fatal(1,"group accounting");
 // Fill a queued buffer and verify that an extra byte is rejected/reported.
 send_group(2);
 @(negedge clk);rx_data=8'hFF;rx_valid=1;
 @(negedge clk);rx_valid=0;
 if(!overflow) $fatal(1,"missing overflow flag");
 reset=1; #12;
 if(start || wr || rd || tx_start || overflow) $fatal(1,"reset failed");
 $display("PASS: two full groups, 80 writes, delayed reads, actual UART serialization, RX/TX overlap, completion, overflow/reset");
 $finish;
end
initial begin #2000000; $fatal(1,"timeout"); end
endmodule
