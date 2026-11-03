`timescale 1ns/1ps
module tb_exhibit_metadata;
 reg clk=0,rst_n=0,commit=0,enable=1,de=1; reg [31:0] source_size=0; reg [19:0] fitted_size=0;
 reg [9:0] x=0,y=0; reg [23:0] rgb=24'h8090a0; wire [23:0] result;
 exhibit_metadata_overlay dut(clk,rst_n,commit,source_size,fitted_size,enable,de,x,y,rgb,result);
 always #5 clk=~clk;
 task tick; begin @(posedge clk); #1; end endtask
 function [15:0] bcd(input integer n); bcd={4'(n/1000),4'(n/100%10),4'(n/10%10),4'(n%10)}; endfunction
 task load(input integer w,h); begin source_size={16'(w),16'(h)}; fitted_size={10'(640),10'(480)}; commit=1; tick; commit=0; repeat(16) tick; if(!dut.valid || dut.bcd_q!=={bcd(w),bcd(h),bcd(640),bcd(480)}) $fatal(1,"conversion failed"); end endtask
 initial begin
  tick; rst_n=1; tick; if(result!==rgb) $fatal(1,"reset bypass");
  load(960,645);
  x=528;y=8;#1;if(dut.glyph!==11) $fatal(1,"原 glyph");
  x=536;y=8;#1;if(dut.glyph!==12) $fatal(1,"图 glyph");
  x=560;y=8;#1;if(dut.glyph!==17) $fatal(1,"source digit");
  x=528;y=16;#1;if(dut.glyph!==14) $fatal(1,"输 glyph");
  x=592;y=16;#1;if(dut.glyph!==10) $fatal(1,"x glyph");
  x=527;y=8;#1;if(result!==rgb) $fatal(1,"left boundary");
  x=632;y=8;#1;if(result!==rgb) $fatal(1,"right boundary");
  enable=0;x=536;#1;if(result!==rgb) $fatal(1,"preview bypass");
  if(dut.font8(11)!==64'h3c66603c06663c00 || dut.font8(15)!==64'h6666666666663c00) $fatal(1,"S/U font");
  $display("PASS metadata: English SRC/OUT top-right overlay, leading zeros hidden"); $finish;
 end
endmodule
