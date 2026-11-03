`timescale 1ns/1ps
module tb_resident_memory;
reg mem_clk=0,pix_clk=0,rst_n=0,frame_start=0,consume=0,start=0,produce=0;
always #12.5 mem_clk=~mem_clk;
always #20 pix_clk=~pix_clk;
reg [1:0] load_bank=0,display_bank=0;
wire ri,ra,wi,wa,rd,wr,ready,valid,done,underflow,safe;
wire [20:0] raddr,waddr;
wire [31:0] wdata;
wire [23:0] rgb;
wire [7:0] re,we;
wire [3:0] complete;
reg [31:0] memory[0:1228799];
reg [31:0] dpipe[0:5];
reg [5:0] vpipe=0;
integer sent=0,writes=0,pixels=0,i,b,x,y;
wire send_pixel=produce && ready && sent<307200;
function [23:0] pattern(input integer bank,input integer n);
 pattern=((n*24'h13579b)^24'h5ac389) ^ (bank*24'h394127);
endfunction
media_frame_loader loader(.clk(mem_clk),.rst_n(rst_n),.load_start(start),
 .image_index(load_bank),.pixel_valid(send_pixel),.pixel_rgb(pattern(load_bank,sent)),
 .pixel_ready(ready),.frame_commit(1'b0),.decode_error(8'd0),.load_done(done),
 .image_complete(complete),.memory_error(we),.controller_init_done(1'b1),
 .controller_busy(1'b0),.refresh_active(1'b0),.bus_grant(wi&&!ra&&!ri&&safe),
 .wr_burst_active(wa),.wr_start_intent(wi),.app_wr_en(wr),.app_wr_addr(waddr),.app_wr_data(wdata));
media_frame_reader reader(.mem_clk(mem_clk),.mem_rst_n(rst_n),.controller_init_done(1'b1),
 .controller_busy(1'b0),.refresh_active(1'b0),.bus_grant(ri&&!wa),.rd_burst_active(ra),
 .rd_start_intent(ri),.writer_window_safe(safe),.app_rd_en(rd),.app_rd_addr(raddr),
 .sdram_rd_valid(vpipe[5]),.sdram_rd_data(dpipe[5]),.pix_clk(pix_clk),.pix_rst_n(rst_n),
 .frame_start(frame_start),.active_index(display_bank),.pixel_consume(consume),
 .pixel_rgb(rgb),.pixel_valid(valid),.underflow(underflow),.reader_error(re));
always @(posedge mem_clk)if(rst_n)begin
 if(send_pixel)sent<=sent+1;
 if(wr)begin
  if(waddr>=1228800 || waddr/307200!=load_bank)$fatal(1,"resident write escaped bank");
  memory[waddr]<=wdata;writes=writes+1;
 end
 for(i=5;i>0;i=i-1)begin dpipe[i]<=dpipe[i-1];vpipe[i]<=vpipe[i-1];end
 vpipe[0]<=rd;if(rd)begin
  if(raddr>=1228800)$fatal(1,"resident read escaped memory");
  dpipe[0]<=memory[raddr];
 end
 if(re!=0 || we!=0 || underflow)$fatal(1,"memory errors r=%h w=%h underflow=%b",re,we,underflow);
end
initial begin
 repeat(10)@(negedge mem_clk);rst_n=1;
 for(b=0;b<4;b=b+1)begin
  @(negedge mem_clk);load_bank=b;sent=0;start=1;
  @(negedge mem_clk);start=0;produce=1;
  wait(done);@(negedge mem_clk);produce=0;
  if(sent!=307200)$fatal(1,"incomplete resident writes");
 end
 if(complete!=15 || writes!=1228800)$fatal(1,"four bank completion");
 for(b=0;b<4;b=b+1)begin
  display_bank=b;pixels=0;
  for(y=0;y<525;y=y+1)for(x=0;x<800;x=x+1)begin
   @(negedge pix_clk);frame_start=(x==0&&y==0);consume=(x>=160&&y>=45);
   @(posedge pix_clk);
   if(consume)begin
    if(!valid || rgb!==pattern(b,(479-pixels/640)*640+pixels%640))
     $fatal(1,"resident bank%0d pixel%0d rgb=%h",b,pixels,rgb);
    pixels=pixels+1;
   end
  end
  if(pixels!=307200)$fatal(1,"short readback");
 end
 $display("PASS resident memory: 1228800 actual writes and 1228800 exact pixel readbacks in four full-size banks, 40/25MHz clocks, six-cycle SDRAM model");
 $finish;
end
initial begin #200000000;$fatal(1,"resident memory timeout");end
endmodule
