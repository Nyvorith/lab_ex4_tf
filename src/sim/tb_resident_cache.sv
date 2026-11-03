`timescale 1ns/1ps
module tb_resident_cache;
reg clk=0,pix=0,rst=1,frame=0,advance=0;
always #5 clk=~clk;
always #7 pix=~pix;
wire request,gated,busy,toggle,active,wipe;
wire [7:0] alpha;
reg c1=0,c2=0,c3=0;
always @(posedge pix) begin c1<=toggle;c2<=c1;c3<=c2;end
sd_card_bmp #(.FULL_FRAME_CACHE(1),.CLK_FREQ_HZ(1000),.AUTO_FROM_CAPTION(1),
 .AUTO_PREFETCH(1),.MANUAL_PREFETCH(1),.MANUAL_READY_GATE(1),
 .PREVIEW_WARMUP(1),.PREVIEW_FOCUS_PREFETCH(1)) dut(
 .clk(clk),.rst(rst),.key_next(1'b1),.key_auto(1'b1),.key_mode(1'b1),
 .key_next_req(request),.manual_transition_busy(busy),.next_req_gated(gated),
 .auto_advance_event(advance),.bmp_width(16'd640),.bmp_height(16'd480),
 .sdr_init_done(1'b1),.wav_sd_req(1'b0),.wav_sd_lba(32'd0),
 .write_finish_toggle(1'b0),.write_req_ack(1'b0),.SD_MISO(1'b1),
 .index_commit_tgl(toggle));
video_fade_transition #(.FADE_FRAMES(4),.REVEAL_ON_COMMIT(2)) fade(
 .ctrl_clk(clk),.ctrl_rst_n(!rst),.next_event_in(request),.next_event_out(gated),
 .fade_busy(busy),.pix_clk(pix),.pix_rst_n(!rst),.player_active(dut.display_valid),.reveal_commit(dut.auto_play_en),
 .frame_start(frame),.index_commit(c2^c3),.load_failed(1'b0),
 .active_index(dut.img_idx),.alpha_out(alpha),.fade_active(active),
 .wipe_active(wipe),.ramp_out(),.transition_kind());
integer starts=0,commits=0,i,snapshot,old_commits;
reg previous_toggle;
reg [31:0] source_size={16'd960,16'd764};
reg [19:0] fitted_size={10'd603,10'd480};
reg [3:0] loaded_banks=0;
always @(posedge clk) if(!rst) begin
 if(dut.load_start_pulse) begin
  starts=starts+1;
  if(dut.display_valid && dut.write_buf_idx==dut.disp_buf_idx)
   $fatal(1,"writing displayed bank");
  if(dut.write_buf_idx!==dut.load_idx || loaded_banks[dut.load_idx])
   $fatal(1,"wrong or duplicate resident load");
  loaded_banks[dut.load_idx]=1;
 end
 if(toggle!=previous_toggle)commits=commits+1;
 previous_toggle=toggle;
 if(wipe && !dut.auto_play_en)$fatal(1,"manual or preview used reveal");
end
task cycles(input integer n);repeat(n)@(negedge clk);endtask
task boundary;begin
 @(negedge pix);frame=1;@(negedge pix);frame=0;repeat(8)@(negedge pix);
end endtask
task next_key;begin force dut.key_next_press=1;cycles(1);force dut.key_next_press=0;cycles(2);end endtask
task mode_key;begin force dut.key_mode_press=1;cycles(1);force dut.key_mode_press=0;cycles(2);end endtask
task auto_key;begin force dut.key_auto_press=1;cycles(1);force dut.key_auto_press=0;cycles(2);end endtask
task finish_load;begin
 wait(dut.load_busy);cycles(3);
 dut.source_done_seen=1;cycles(3);
 if(!dut.load_busy || dut.resident_valid[dut.load_idx])$fatal(1,"published source-only cache");
 dut.write_done_seen=1;cycles(3);
end endtask
task settle;begin repeat(14)boundary();cycles(5);if(active||busy||alpha!=255)$fatal(1,"fade stuck");end endtask
initial begin
 force dut.sd_init_done=1;force dut.scanner_scan_done=0;
 force dut.scan_resource_valid=4'b1111;force dut.bmp_ready=1;
 force dut.load_error=0;force dut.scaler_done=0;force dut.write_finish_pulse=0;
 force dut.scaler_source_size=source_size;
 force dut.scaler_fitted_size=fitted_size;
 force dut.key_next_press=0;force dut.key_auto_press=0;force dut.key_mode_press=0;
 cycles(5);rst=0;cycles(1);previous_toggle=toggle;
 dut.scan_kicked=1;dut.scan_done=1;dut.img_found_count=4;
 for(i=0;i<4;i=i+1)begin
  wait(dut.load_busy);cycles(1);
  if(dut.load_idx!==i[1:0])$fatal(1,"warmup wrong target");
  source_size={16'(960+i),16'(764+i)};
  fitted_size={10'(600+i),10'd480};
  finish_load();
 end
 settle();snapshot=starts;
 if(snapshot!=4 || dut.resident_valid!=15 || dut.disp_buf_idx!=0)
  $fatal(1,"four resident frames missing");
 next_key();wait(active);mode_key();
 if(dut.preview_mode||dut.preview_open_pending||!dut.manual_frame_reserved)
  $fatal(1,"preview stole in-flight fade");
 settle();
 if(dut.img_idx!=1 || starts!=snapshot || dut.committed_source_size!={16'd961,16'd765} ||
    dut.committed_fitted_size!={10'd601,10'd480})$fatal(1,"manual cached flip read TF or selected wrong image");
 mode_key();cycles(5);
 if(!dut.preview_mode)$fatal(1,"ready wall did not open");
 next_key();auto_key();settle();
 if(dut.preview_mode || dut.img_idx!=2 || starts!=snapshot)$fatal(1,"preview confirmation missed resident bank");
 auto_key();cycles(3);advance=1;cycles(1);advance=0;
 wait(active);cycles(5);
 if(!wipe || alpha!=255 || dut.img_idx!=3)$fatal(1,"automatic commit did not restore reveal");
 old_commits=commits;
 next_key();advance=1;cycles(1);advance=0;
 settle();
 if(dut.img_idx!=3 || commits!=old_commits || starts!=snapshot)
  $fatal(1,"automatic reveal reentered or reread TF");
 next_key();wait(active);cycles(5);
 if(wipe)$fatal(1,"manual next in auto mode must fade");
 old_commits=commits;
 advance=1;cycles(1);advance=0;
 repeat(3)boundary();
 if(dut.img_idx!=3 || commits!=old_commits)$fatal(1,"manual committed before black");
 settle();
 if(dut.img_idx!=0 || commits!=old_commits+1 || starts!=snapshot)
  $fatal(1,"auto/manual race skipped picture or read TF");
 auto_key();mode_key();cycles(5);mode_key();settle();
 if(dut.img_idx!=0 || dut.preview_mode)$fatal(1,"same-image preview return");
 next_key();settle();
 if(dut.img_idx!=1 || starts!=snapshot)$fatal(1,"resident wraparound reread TF");
 rst=1;cycles(4);rst=0;cycles(1);loaded_banks=0;
 dut.scan_kicked=1;dut.scan_done=1;dut.img_found_count=4;
 finish_load();settle();
 mode_key();
 if(!dut.preview_open_pending)$fatal(1,"early preview not pending");
 next_key();cycles(4);
 if(dut.preview_open_pending || !dut.manual_ready_pending)$fatal(1,"early next did not cancel preview wait");
 while(!dut.resident_valid[1])begin finish_load();end
 settle();
 if(dut.img_idx!=1)$fatal(1,"early preview/next deadlock");
 force dut.sd_init_done=0;cycles(3);
 if(dut.resident_valid!=0 || dut.preview_mode)$fatal(1,"reinitialization retained stale cache");
 $display("PASS resident cache: four distinct frames, dual-completion, no TF reads after warmup, manual fade/auto reveal/preview fade, fade interlock, cold-key recovery, invalidation");
 $finish;
end
initial begin #300000; $display("request=%b ready=%b next=%d busy=%b target_waiting=%b display=%b modepress=%b autopress=%b",request,dut.manual_cache_ready,dut.next_from_current,busy,dut.resident_target_waiting,dut.display_valid,dut.key_mode_press,dut.key_auto_press);$display("debug starts=%d valid=%b busy=%b idx=%d phase=%d pending=%b reserved=%b pre=%b open=%b scan=%b first=%b missing=%b",starts,dut.resident_valid,dut.load_busy,dut.img_idx,fade.g_fade.state,dut.manual_ready_pending,dut.manual_frame_reserved,dut.preview_mode,dut.preview_open_pending,dut.scan_done,dut.first_image_committed,dut.resident_missing); $fatal(1,"resident control timeout");end
endmodule
