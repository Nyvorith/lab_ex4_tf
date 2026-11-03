`timescale 1ns/1ps
module tb_preview_card;
reg clk=0;always #5 clk=~clk;
reg rst_n=0,frame_start=0,commit=0,display_valid=1,preview_mode=1;
reg [1:0] preview_focus=0,commit_index=0;
reg [9:0] x=0,y=0;
reg hs_in=1,vs_in=1,de_in=1;
reg [23:0] rgb_in=24'h8090a0;
wire [23:0] rgb_out;
wire hs_out,vs_out,de_out;
exhibit_caption_overlay #(.INTRO_CARD(1),.ARTWORK_LABEL(1),.SWITCHABLE_CAPTION(1)) dut(
 .clk(clk),.rst_n(rst_n),.frame_start(frame_start),.commit(commit),.commit_index(commit_index),
 .display_valid(display_valid),.preview_mode(preview_mode),.preview_focus(preview_focus),
 .auto_mode(1'b0),.caption_enabled(1'b0),.artwork_ready(1'b0),
 .speech_playing(1'b0),.speech_samples(32'd0),.x(x),.y(y),
 .hs_in(hs_in),.vs_in(vs_in),.de_in(de_in),.rgb_in(rgb_in),
 .rgb_out(rgb_out),.hs_out(hs_out),.vs_out(vs_out),.de_out(de_out));
reg [15:0] font[0:4095];
reg [7:0] ids[0:255];
reg [23:0] q0,q1,expected;
reg [2:0] sync0,sync1;
reg [15:0] bits;
integer p,xx,yy,row,line_y,col,checks=0,stage=0;
function [23:0] oracle(input integer px,py);
 integer r,ly,c,a;
 reg [15:0] mask;
 begin
  oracle=rgb_in;
  if(preview_mode && display_valid && de_in && px>=48 && px<592 && py>=352 && py<456)begin
   oracle=24'h1c2a38;
   r=py>=412 ? 2 : py>=388 ? 1 : 0;
   ly=py-364-r*24;c=(px-64)/16;
   a=preview_focus*64+(r==2 ? 32 : r*16)+c;
   if(px>=64 && px<576 && ly>=0 && ly<16 && (r==2 || c<16))begin
    mask=font[ids[a]*16+ly];
    if(mask[15-((px-64)%16)])oracle=r==0 ? 24'hf0e4c8 : r==1 ? 24'hb8c8d8 : 24'hf0f4f8;
   end
  end
 end
endfunction
task tick;
 begin @(posedge clk);#1;@(negedge clk);end
endtask
initial begin
 $readmemh("assets/exhibition/captions/generated/glyph_rows.hex",font);
 $readmemh("assets/exhibition/captions/generated/preview_card_ids.hex",ids);
 repeat(4)tick();rst_n=1;repeat(4)tick();
 for(p=0;p<4;p=p+1)begin
  preview_focus=p;
  for(yy=348;yy<460;yy=yy+1)for(xx=44;xx<596;xx=xx+1)begin
   x=xx;y=yy;expected=oracle(xx,yy);repeat(3)tick();
   if(rgb_out!==expected)$fatal(1,"card picture%0d pixel%0d,%0d actual%h expected%h",p,xx,yy,rgb_out,expected);
   checks=checks+1;
  end
 end
 for(stage=0;stage<4;stage=stage+1)begin
  preview_mode=stage!=0;display_valid=stage!=1;de_in=stage!=2;
  q0=rgb_in;q1=rgb_in;sync0={hs_in,vs_in,de_in};sync1=sync0;
  repeat(4)tick();
  q0=oracle(x,y);q1=q0;
  for(xx=0;xx<2000;xx=xx+1)begin
   @(negedge clk);
   x=44+xx%552;y=348+xx%112;rgb_in=24'h123456+xx;
   hs_in=xx%3!=0;vs_in=xx%5!=0;
   expected=oracle(x,y);
   @(posedge clk);#1;
   if(rgb_out!==q0 || {hs_out,vs_out,de_out}!==sync0)$fatal(1,"card pipeline/hiding mismatch stage%0d",stage);
   q1=q0;q0=expected;sync1=sync0;sync0={hs_in,vs_in,de_in};
  end
 end
 $display("PASS preview card: %0d exact pixels, four focus identities, three text rows, borders, no wrap, full-view/invalid/blanking hiding and RGB/HS/VS/DE pipeline",checks);
 $finish;
end
initial begin #30000000;$fatal(1,"preview card timeout");end
endmodule
