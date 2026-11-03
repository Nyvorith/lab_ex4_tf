`timescale 1ns/1ps
module tb_manual_prefetch_fade;
reg clk=0,pix=0,rst=1,request=0,frame=0;
always #5 clk=~clk;
always #7 pix=~pix;
wire gated,commit_tgl;
reg c1=0,c2=0,c3=0;
always @(posedge pix) begin c1<=commit_tgl;c2<=c1;c3<=c2;end
wire [7:0] alpha;
wire wipe,active;
sd_card_bmp #(.CLK_FREQ_HZ(1000),.AUTO_FROM_CAPTION(1),.AUTO_PREFETCH(1),.MANUAL_PREFETCH(1)) dut(
 .clk(clk),.rst(rst),.key_next(1'b1),.key_auto(1'b1),.key_mode(1'b1),
 .auto_advance_event(1'b0),.bmp_width(16'd640),.bmp_height(16'd480),
 .sdr_init_done(1'b1),.next_req_gated(gated),.wav_sd_req(1'b0),.wav_sd_lba(32'd0),
 .write_finish_toggle(1'b0),.write_req_ack(1'b0),.SD_MISO(1'b1),.index_commit_tgl(commit_tgl));
video_fade_transition #(.FADE_FRAMES(4)) fade(
 .ctrl_clk(clk),.ctrl_rst_n(!rst),.next_event_in(request),.next_event_out(gated),.fade_busy(),
 .pix_clk(pix),.pix_rst_n(!rst),.player_active(1'b1),.frame_start(frame),
 .index_commit(c2^c3),.load_failed(1'b0),.active_index(2'd0),
 .alpha_out(alpha),.fade_active(active),.wipe_active(wipe),.ramp_out(),.transition_kind());
integer starts=0,i;
always @(posedge clk) if(!rst && dut.load_start_pulse) starts=starts+1;
task cycles(input integer n);repeat(n)@(negedge clk);endtask
task boundary;begin @(negedge pix);frame=1;@(negedge pix);frame=0;repeat(6)@(negedge pix);end endtask
initial begin
 force dut.sd_init_done=1;force dut.scanner_scan_done=0;
 force dut.scan_resource_valid=4'b1111;force dut.bmp_ready=1;
 force dut.load_error=0;force dut.scaler_done=0;force dut.write_finish_pulse=0;
 cycles(5);rst=0;cycles(1);
 dut.scan_kicked=1;dut.scan_done=1;dut.first_image_committed=1;
 dut.img_found_count=4;dut.img_idx=0;dut.state_code=1;dut.display_valid=1;
 dut.disp_buf_idx=0;dut.auto_play_en=0;dut.prefetch_guard=0;
 wait(dut.load_busy);cycles(3);
 if(!dut.load_prefetch || dut.load_idx!=1 || alpha!=255 || active)$fatal(1,"manual background preparation");
 dut.source_done_seen=1;dut.write_done_seen=1;cycles(4);
 if(!dut.prefetched_valid || dut.img_idx!=0 || starts!=1)$fatal(1,"manual preload early commit");
 @(negedge clk);request=1;@(negedge clk);request=0;
 repeat(5)@(negedge pix);
 for(i=0;i<4;i=i+1) begin
  boundary;
  if(alpha !== (i==3 ? 8'd0 : (3-i)*64) || wipe || dut.img_idx!=0)
   $fatal(1,"manual fade-out lost i%0d alpha%0d idx%0d",i,alpha,dut.img_idx);
 end
 boundary;                                                              
 cycles(8);repeat(6)@(negedge pix);
 if(dut.img_idx!=1 || starts!=1 || wipe || alpha!=0)$fatal(1,"cached commit missing or wipe used");
 for(i=0;i<4;i=i+1)begin
  boundary;
  if(wipe || alpha !== (i==3 ? 8'd255 : (i+1)*64))$fatal(1,"manual fade-in missing");
 end
 if(active || dut.auto_play_en)$fatal(1,"manual fade did not finish");
 $display("PASS manual prefetch + actual fade: auto off, old image retained during preload, no early commit, four-step fade-out/in, no wipe, no second load at black");$finish;
end
initial begin #100000;$fatal(1,"timeout");end
endmodule
