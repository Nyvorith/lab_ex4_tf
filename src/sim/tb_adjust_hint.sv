`timescale 1ns/1ps
module tb_adjust_hint;
reg clk=0;always #5 clk=~clk;
reg rst_n=0,frame=0,preview=0,ready=1,valid=1,commit=0;
reg [7:0] brightness=220,contrast=128;
reg [9:0] x=0,y=0;
reg de=1,hs=1,vs=1;
reg [23:0] rgb=24'h8090a0;
wire [23:0] out;
wire ho,vo,dout;
exhibit_caption_overlay #(.ADJUST_HINT(1),.HINT_FRAMES(5),.SWITCHABLE_CAPTION(1)) dut(
 .clk(clk),.rst_n(rst_n),.frame_start(frame),.commit(commit),.commit_index(2'd0),
 .display_valid(valid),.preview_mode(preview),.preview_focus(2'd0),
 .brightness_value(brightness),.contrast_value(contrast),.auto_mode(1'b0),
 .caption_enabled(1'b0),.artwork_ready(ready),.speech_playing(1'b0),.speech_samples(32'd0),
 .x(x),.y(y),.hs_in(hs),.vs_in(vs),.de_in(de),.rgb_in(rgb),
 .hs_out(ho),.vs_out(vo),.de_out(dout),.rgb_out(out));
task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
task boundary;begin frame=1;tick();frame=0;tick();end endtask
task pixel(input integer px,py,input [23:0] expected);
 begin x=px;y=py;repeat(3)tick();if(out!==expected)$fatal(1,"hint pixel %0d,%0d actual%h expected%h",px,py,out,expected);end
endtask
integer i,c,n;
reg [95:0] wanted;
reg [23:0] prior,expected;
reg [2:0] oldsync;
task check_text(input integer value,input integer is_contrast);
 begin
  wanted=is_contrast ? "CONTRAST 000" : "BRIGHT   000";
  wanted[23:16]=value>=100 ? "0"+value/100 : " ";
  wanted[15:8]=value>=10 ? "0"+(value/10)%10 : " ";
  wanted[7:0]="0"+value%10;
  for(c=0;c<12;c=c+1)begin
   x=16+c*12;y=36;tick();
   if(dut.hint_letter!==wanted[95-c*8-:8])$fatal(1,"value%0d character%0d got%h expected%h",value,c,dut.hint_letter,wanted[95-c*8-:8]);
  end
 end
endtask
initial begin
 repeat(4)tick();rst_n=1;boundary();
 if(dut.hint_frames!=0)$fatal(1,"startup hint not hidden");
 brightness=236;repeat(3)tick();if(dut.hint_frames!=0)$fatal(1,"midframe update");boundary();
 if(dut.hint_frames!=5 || dut.hint_contrast)$fatal(1,"brightness event missing");
 check_text(236,0);
 pixel(16,36,24'hf0e4c8);pixel(24,36,24'h1c2a38);
 pixel(8,28,24'h1c2a38);pixel(7,28,24'h8090a0);pixel(175,63,24'h1c2a38);pixel(176,63,24'h8090a0);
 for(i=0;i<4;i=i+1)boundary();
 if(dut.hint_frames!=1)$fatal(1,"early expiry");
 brightness=252;boundary();if(dut.hint_frames!=5)$fatal(1,"repeat did not refresh");
 check_text(252,0);
 for(i=0;i<5;i=i+1)boundary();pixel(16,36,24'h8090a0);
 for(n=0;n<256;n=n+1)begin
  contrast=n;boundary();check_text(n,1);
 end
 brightness=156;contrast=128;boundary();
 if(!dut.hint_contrast)$fatal(1,"simultaneous changes priority");
 ready=0;pixel(16,36,24'h8090a0);ready=1;
 de=0;pixel(16,36,24'h8090a0);de=1;
 preview=1;boundary();if(dut.hint_frames!=0)$fatal(1,"preview retained hint");
 brightness=172;boundary();preview=0;boundary();if(dut.hint_frames!=0)$fatal(1,"preview adjustment leaked");
 brightness=188;boundary();commit=1;boundary();commit=0;
 if(dut.hint_frames!=0)$fatal(1,"commit retained old hint");
 brightness=204;boundary();valid=0;boundary();valid=1;boundary();
 if(dut.hint_frames!=0)$fatal(1,"invalid display retained hint");
 brightness=220;boundary();pixel(8,28,24'h1c2a38);
 prior=24'h1c2a38;oldsync=3'b111;
 for(i=0;i<128;i=i+1)begin
  x=i[0] ? 7 : 8;y=28;de=i[1];hs=i[2];vs=i[3];rgb=24'h123400+i;
  expected=de && x==8 ? 24'h1c2a38 : rgb;
  @(posedge clk);#1;
  if(out!==prior || {ho,vo,dout}!==oldsync)$fatal(1,"dynamic hint pipeline");
  prior=expected;oldsync={hs,vs,de};@(negedge clk);
 end
 rst_n=0;tick();rst_n=1;boundary();if(dut.hint_frames!=0)$fatal(1,"reset retained hint");
 $display("PASS adjustment hint: all 256 decimal values without leading zeros, BRIGHT/CONTRAST identity, frame-only updates, initial silence, repeat refresh, exact expiry, preview/commit/invalid/fade/blanking hiding and RGB/HS/VS/DE pipeline");
 $finish;
end
initial begin #5000000;$fatal(1,"adjustment hint timeout");end
endmodule
