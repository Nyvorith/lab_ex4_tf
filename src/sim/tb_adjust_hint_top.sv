`timescale 1ns/1ps
module tb_adjust_hint_top;
reg clk=0,rst_n=0,key2=1,key4=1,frame=0,preview=0;
always #10 clk=~clk;
top dut(.clk(clk),.rst_n(rst_n),.key2(key2),.key3(1'b1),.key4(key4),.sd_miso(1'b1));
defparam dut.u_image_hold_adjust.LONG_PRESS_CYCLES=12;
defparam dut.u_image_hold_adjust.REPEAT_CYCLES=8;
task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
task boundary;begin frame=1;tick();frame=0;repeat(4)tick();end endtask
reg [7:0] captured;
initial begin
 force dut.por_done=1;
 force dut.reader_frame_start=frame;
 force dut.preview_mode_sd=preview;
 force dut.display_valid=1;
 force dut.index_commit_tgl=0;
 force dut.state_code=1;
 force dut.reader_pixel_valid=1;
 force dut.fade_active=0;
 force dut.raw_x=12'd168;
 force dut.raw_y=12'd73;
 force dut.raw_de=1;
 force dut.raw_hs=1;force dut.raw_vs=1;
 repeat(10)tick();rst_n=1;repeat(20)tick();boundary();boundary();
 if(dut.g_exhibit_caption.u_caption.hint_frames!=0)$fatal(1,"top default triggered hint");
 key2=0;repeat(16)tick();key2=1;repeat(6)tick();captured=dut.brightness_cfg;
 if(captured!=236)$fatal(1,"actual brightness key did not step once");
 boundary();
 if(dut.brightness_q!==captured || dut.g_exhibit_caption.u_caption.hint_brightness!==captured ||
    dut.g_exhibit_caption.u_caption.hint_contrast || dut.vout_data!==24'h1c2a38)
  $fatal(1,"brightness applied value / hint / HDMI mismatch");
 key4=0;repeat(16)tick();key4=1;repeat(6)tick();captured=dut.contrast_cfg;
 if(captured!=160)$fatal(1,"actual contrast key did not step once");
 boundary();
 if(dut.contrast_q!==captured || dut.g_exhibit_caption.u_caption.hint_contrast_value!==captured ||
    !dut.g_exhibit_caption.u_caption.hint_contrast)$fatal(1,"contrast hint metadata mismatch");
 preview=1;repeat(5)tick();boundary();boundary();
 if(dut.g_exhibit_caption.u_caption.hint_frames!=0)$fatal(1,"top preview retained hint");
 key4=0;repeat(40)tick();key4=1;repeat(6)tick();boundary();
 if(dut.contrast_cfg!=160)$fatal(1,"preview changed contrast");
 preview=0;repeat(5)tick();boundary();boundary();
 if(dut.g_exhibit_caption.u_caption.hint_frames!=0)$fatal(1,"preview exit replayed hint");
 rst_n=0;repeat(5)tick();rst_n=1;repeat(20)tick();boundary();
 if(dut.brightness_cfg!=220 || dut.contrast_cfg!=128 || dut.g_exhibit_caption.u_caption.hint_frames!=0)
  $fatal(1,"top reset did not restore silent defaults");
 $display("PASS adjustment hint top: actual KEY2/KEY4 holds, synchronized applied values match displayed values, final HDMI panel, preview adjustment disabled, reset defaults and no replay");
 $finish;
end
initial begin #1000000;$fatal(1,"adjust hint top timeout");end
endmodule
