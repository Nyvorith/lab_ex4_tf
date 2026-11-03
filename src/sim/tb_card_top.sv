`timescale 1ns/1ps
module tb_card_top;
reg clk=0,rst_n=0;always #10 clk=~clk;
reg frame=0,preview=0;
reg [1:0] focus=0;
top dut(.clk(clk),.rst_n(rst_n),.key2(1'b1),.key3(1'b1),.key4(1'b1),.sd_miso(1'b1));
task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
task boundary;begin frame=1;tick();frame=0;repeat(4)tick();end endtask
integer i;
initial begin
 force dut.por_done=1;
 force dut.reader_frame_start=frame;
 force dut.preview_mode_sd=preview;
 force dut.preview_focus_sd=focus;
 force dut.preview_loaded_sd=15;
 force dut.display_valid=1;
 force dut.index_commit_tgl=0;
 force dut.state_code=1;
 force dut.reader_pixel_valid=1;
 force dut.raw_x=12'd208;
 force dut.raw_y=12'd397;
 force dut.raw_de=1;
 force dut.raw_hs=1;force dut.raw_vs=1;
 force dut.preview_rgb=24'h8090a0;
 repeat(10)tick();rst_n=1;repeat(20)tick();
 preview=1;repeat(5)tick();boundary();
 for(i=0;i<4;i=i+1)begin
  focus=i;repeat(5)tick();
  if(dut.preview_focus_q!==(i==0 ? 2'd0 : 2'(i-1)))$fatal(1,"preview changed outside frame boundary");
  boundary();
  if(dut.preview_focus_q!==i[1:0] || dut.g_exhibit_caption.u_caption.preview_focus!==i[1:0])
   $fatal(1,"card and preview focus mismatch");
  if(dut.vout_data!==24'h1c2a38)$fatal(1,"card missing from final HDMI pipeline");
 end
 preview=0;repeat(5)tick();boundary();
 if(dut.g_exhibit_caption.u_caption.card_box)$fatal(1,"card leaked to full view");
 $display("PASS card top: four focus bindings at frame boundaries, active preview integration, final HDMI card color and full-view hiding");
 $finish;
end
initial begin #1000000;$fatal(1,"card top timeout");end
endmodule
