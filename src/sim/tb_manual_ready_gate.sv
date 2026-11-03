`timescale 1ns/1ps
module tb_manual_ready_gate;
reg clk=0,pix=0,rst=1,frame=0;
always #5 clk=~clk;
always #7 pix=~pix;
wire request,gated,busy,commit_tgl,active,wipe;
wire [7:0] alpha;
reg c1=0,c2=0,c3=0;
always @(posedge pix) begin c1<=commit_tgl;c2<=c1;c3<=c2;end
sd_card_bmp #(.CLK_FREQ_HZ(1000),.AUTO_FROM_CAPTION(1),.AUTO_PREFETCH(1),
 .MANUAL_PREFETCH(1),.MANUAL_READY_GATE(1),.PREVIEW_WARMUP(1),
 .PREVIEW_FOCUS_PREFETCH(1)) dut(
 .clk(clk),.rst(rst),.key_next(1'b1),.key_auto(1'b1),.key_mode(1'b1),
 .key_next_req(request),.manual_transition_busy(busy),.next_req_gated(gated),
 .auto_advance_event(1'b0),.bmp_width(16'd640),.bmp_height(16'd480),
 .sdr_init_done(1'b1),.wav_sd_req(1'b0),.wav_sd_lba(32'd0),
 .write_finish_toggle(1'b0),.write_req_ack(1'b0),.SD_MISO(1'b1),
 .index_commit_tgl(commit_tgl));
video_fade_transition #(.FADE_FRAMES(4)) fade(
 .ctrl_clk(clk),.ctrl_rst_n(!rst),.next_event_in(request),
 .next_event_out(gated),.fade_busy(busy),.pix_clk(pix),.pix_rst_n(!rst),
 .player_active(1'b1),.frame_start(frame),.index_commit(c2^c3),
 .load_failed(1'b0),.active_index(2'd0),.alpha_out(alpha),
 .fade_active(active),.wipe_active(wipe),.ramp_out(),.transition_kind());
integer starts=0,releases=0,i,snapshot;
always @(posedge clk) if(!rst)begin
 if(dut.load_start_pulse) starts=starts+1;
 if(gated) releases=releases+1;
end
task cycles(input integer n);repeat(n)@(negedge clk);endtask
task press;begin
 force dut.key_next_press=1;cycles(1);force dut.key_next_press=0;cycles(2);
end endtask
task boundary;begin
 @(negedge pix);frame=1;@(negedge pix);frame=0;repeat(6)@(negedge pix);
end endtask
task boot;begin
 rst=1;cycles(4);rst=0;cycles(1);
 dut.scan_kicked=1;dut.scan_done=1;dut.first_image_committed=1;
 dut.img_found_count=4;dut.img_idx=0;dut.display_valid=1;
 dut.preview_loaded=1;dut.prefetch_guard=0;
                                                                    
 dut.load_busy=1;dut.load_preview_only=1;dut.load_prefetch=0;
 dut.load_idx=3;dut.pending_buf_idx=1;dut.write_buf_idx=1;
 dut.source_done_seen=0;dut.write_done_seen=0;
end endtask
initial begin
 force dut.sd_init_done=1;force dut.scanner_scan_done=0;
 force dut.scan_resource_valid=4'b1111;force dut.bmp_ready=1;
 force dut.load_error=0;force dut.scaler_done=0;force dut.write_finish_pulse=0;
 force dut.key_next_press=0;force dut.key_auto_press=0;force dut.key_mode_press=0;
 boot();press();
 repeat(6)boundary();
 if(alpha!=255 || active || !dut.manual_ready_pending || dut.img_idx!=0)
   $fatal(1,"cold manual request must retain old image while unrelated read runs");
 dut.source_done_seen=1;cycles(4);
 if(active)$fatal(1,"source-only completion faded early");
 dut.write_done_seen=1;cycles(1);
 wait(dut.load_busy);cycles(2);
 if(dut.load_idx!=1 || !dut.load_prefetch || dut.load_preview_only)
   $fatal(1,"manual target lost priority to thumbnail warmup");
 repeat(5)boundary();
 if(active || alpha!=255)$fatal(1,"manual target not yet complete but screen darkened");
 dut.source_done_seen=1;cycles(8);
 if(active)$fatal(1,"target source without SDRAM completion faded");
 dut.write_done_seen=1;cycles(1);
 wait(active);cycles(5);snapshot=starts;
                                                                        
                                                                         
 cycles(180);
 if(starts!=snapshot || !dut.prefetched_valid || dut.load_idx!=1 || !dut.manual_frame_reserved)
   $fatal(1,"ready manual frame overwritten during fade-out");
 for(i=0;i<4;i=i+1)begin
   boundary();
   if(wipe || alpha !== (i==3 ? 8'd0 : (3-i)*64) || dut.img_idx!=0)
     $fatal(1,"manual fade-out changed");
 end
 boundary();cycles(8);repeat(6)@(negedge pix);
 if(dut.img_idx!=1 || starts!=snapshot || releases!=1 || alpha!=0 || wipe)
   $fatal(1,"black-point commit delayed or duplicate TF read");
 for(i=0;i<4;i=i+1)begin
   boundary();
   if(wipe || alpha !== (i==3 ? 8'd255 : (i+1)*64))
     $fatal(1,"manual fade-in changed");
 end
 boot();press();
 force dut.key_mode_press=1;cycles(1);force dut.key_mode_press=0;cycles(2);
 if(dut.manual_ready_pending || dut.manual_frame_reserved || active)
   $fatal(1,"preview intention did not cancel waiting manual request");
 boot();press();dut.load_failed_tgl=~dut.load_failed_tgl;cycles(3);
 if(dut.manual_ready_pending || active || alpha!=255)
   $fatal(1,"failed preparation must cancel without a black screen");
 rst=1;cycles(2);
 if(dut.manual_ready_pending || dut.manual_frame_reserved)
   $fatal(1,"reset left a manual request armed");
 $display("PASS manual ready gate: cold/unrelated warmup priority, both completions before fade, reserved bank, no black TF wait/reread, original fade-out/in, cancel/failure/reset");
 $finish;
end
initial begin #500000;$fatal(1,"manual readiness timeout");end
endmodule
