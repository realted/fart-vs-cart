`timescale 1ns/1ps
module memory_dual_port_tb;
reg cpu=0,host=0,rd=1,we=0,hr=0,hw=0;
reg [7:0] addr=0,ha=0;
reg [15:0] data=0,hd=0;
wire [15:0] q,hq;
memory_dual_port #(.INIT_FILE("data_bank0.mif")) dut(
.clock_1(cpu),.rden_1(rd),.wren_1(we),.address_1(addr),.data_1(data),.q_1(q),
.clock_2(host),.rden_2(hr),.wren_2(hw),.address_2(ha),.data_2(hd),.q_2(hq));
task cp; begin #5;cpu=1;#5;cpu=0;#5;end endtask
task hp; begin #5;host=1;#5;host=0;#5;end endtask
initial begin
 addr=63;cp;
 if(q!==16'h0100) $fatal(1,"MIF initialization");
 ha=63;hr=1;hp;
 if(hq!==16'h0100) $fatal(1,"host MIF read");
 hr=0;ha=20;hd=16'hCAFE;hw=1;hp;hw=0;
 addr=20;cp;
 if(q!==16'hCAFE) $fatal(1,"host write CPU read");
 addr=21;data=16'hBEEF;we=1;cp;we=0;
 ha=21;hr=1;hp;
 if(hq!==16'hBEEF) $fatal(1,"CPU write host read");
 rd=0;#1;if(q!==0) $fatal(1,"CPU read gating");
 // Disabled host write must preserve the location.
 hd=0;hw=0;hp;
 if(hq!==16'hBEEF) $fatal(1,"disabled write");
 $display("PASS: MIF initialization, both-port reads/writes, CPU gating, disabled write");
 $finish;
end
endmodule
