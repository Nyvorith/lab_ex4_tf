`timescale 1ns/1ps
module tb_autoplay_prefetch;
reg clk=0,rst=1; always #5 clk=~clk;
reg advance=0;
reg [31:0] source_size={16'd960,16'd764};
reg [19:0] fitted_size={10'd640,10'd480};
wire loading;
sd_card_bmp #(.CLK_FREQ_HZ(1000),.AUTO_FROM_CAPTION(1),.AUTO_PREFETCH(1)) dut(
 .clk(clk),.rst(rst),.key_next(1'b1),.key_auto(1'b1),.key_mode(1'b1),
 .auto_advance_event(advance),.bmp_width(16'd640),.bmp_height(16'd480),
 .sdr_init_done(1'b1),.next_req_gated(1'b0),.wav_sd_req(1'b0),.wav_sd_lba(32'd0),
 .write_finish_toggle(1'b0),.write_req_ack(1'b0),.SD_MISO(1'b1),.image_loading(loading));
integer starts=0;reg old_commit;reg [1:0] old_bank;reg [31:0] old_source;
always @(posedge clk) if(!rst && dut.load_start_pulse)starts=starts+1;
task cycles(input integer n);repeat(n)@(negedge clk);endtask
task expiry;begin advance=1;cycles(1);advance=0;cycles(3);end endtask
task finish;begin
 cycles(3);dut.source_done_seen=1;cycles(2);
 if(!dut.load_busy || dut.prefetched_valid)$fatal(1,"source completion alone published frame");
 dut.write_done_seen=1;cycles(1);
end endtask
task wait_stage(input [1:0] expected);begin
 wait(dut.load_busy);cycles(1);
 if(!dut.load_prefetch || dut.load_idx!==expected || dut.write_buf_idx==dut.disp_buf_idx)
  $fatal(1,"prefetch target/bank expected%0d got%0d",expected,dut.load_idx);
 if(loading)$fatal(1,"background preload advertised foreground LOAD");
end endtask
initial begin
 force dut.sd_init_done=1;force dut.scanner_scan_done=0;
 force dut.scan_resource_valid=4'b1111;force dut.bmp_ready=1;
 force dut.load_error=0;force dut.scaler_done=0;force dut.write_finish_pulse=0;
 force dut.scaler_source_size=source_size;force dut.scaler_fitted_size=fitted_size;
 cycles(5);rst=0;cycles(1);
 dut.scan_kicked=1;dut.scan_done=1;dut.first_image_committed=1;
 dut.img_found_count=4;dut.img_idx=0;dut.state_code=1;dut.display_valid=1;
 dut.disp_buf_idx=0;dut.auto_play_en=1;dut.prefetch_guard=0;
 old_commit=dut.index_commit_tgl;old_source=dut.committed_source_size;
 cycles(49);if(starts || dut.load_busy)$fatal(1,"reused old read bank before guard");
 wait_stage(1);finish();cycles(10);
 if(!dut.prefetched_valid || dut.index_commit_tgl!==old_commit || dut.img_idx!==0 ||
    dut.committed_source_size!==old_source)$fatal(1,"prefetch committed early");
 if(starts!=1)$fatal(1,"duplicate speculative load");
 expiry();
 if(dut.img_idx!==1 || dut.state_code!==2 || dut.disp_buf_idx!==1 ||
    dut.index_commit_tgl===old_commit || dut.committed_source_size!==source_size || starts!=1)
  $fatal(1,"ready frame did not switch directly on expiry");
                                                                                     
 old_commit=dut.index_commit_tgl;wait_stage(2);expiry();
 if(!dut.auto_req_pending || dut.index_commit_tgl!==old_commit)$fatal(1,"lost in-flight expiry");
 finish();cycles(4);
 if(dut.img_idx!==2 || dut.disp_buf_idx!==0 || dut.index_commit_tgl===old_commit || starts!=2)
  $fatal(1,"late preload failed to publish without reload");
                                                                      
 old_commit=dut.index_commit_tgl;wait_stage(3);finish();cycles(3);
 force dut.key_auto_press=1;advance=1;cycles(1);
 release dut.key_auto_press;advance=0;cycles(5);
 if(dut.auto_play_en || dut.auto_req_pending || dut.index_commit_tgl!==old_commit)
  $fatal(1,"stop/expiry race published preload");
                                                                        
 dut.next_req_pending=1;cycles(3);
 if(dut.img_idx!==3 || dut.index_commit_tgl===old_commit || starts!=3)
  $fatal(1,"manual next reloaded prepared frame");
                                                                        
 dut.auto_play_en=1;old_commit=dut.index_commit_tgl;wait_stage(0);
 dut.preview_mode=1;force dut.preview_missing=0;expiry();finish();cycles(5);
 if(dut.index_commit_tgl!==old_commit || dut.auto_req_pending || !dut.prefetched_valid)
  $fatal(1,"preview/expiry published preload");
 dut.preview_mode=0;cycles(3);expiry();cycles(3);
 if(dut.img_idx!==0 || starts!=4)$fatal(1,"wrap/preview return");
 release dut.preview_missing;
                                                                              
 old_commit=dut.index_commit_tgl;wait_stage(1);
 force dut.load_error=1;force dut.bmp_error=3'd1;cycles(1);
 if(dut.retry_count!=1 || !dut.load_busy || !dut.load_prefetch)$fatal(1,"prefetch retry lost classification");
 cycles(1);force dut.load_error=0;release dut.bmp_error;cycles(4);
 if(dut.load_busy || dut.prefetched_valid || dut.auto_req_pending || dut.index_commit_tgl!==old_commit)
  $fatal(1,"failed prefetch changed display/deadline");
 cycles(80);if(dut.load_busy)$fatal(1,"endless background retries");
 expiry();cycles(2);
 if(!dut.load_busy || dut.load_prefetch || dut.load_idx!==1 || !loading)
  $fatal(1,"expiry fallback busy%0d spec%0d idx%0d loading%0d auto%0d pending%0d err%0d starts%0d",dut.load_busy,dut.load_prefetch,dut.load_idx,loading,dut.auto_play_en,dut.auto_req_pending,dut.last_error_code,starts);
                                                               
 dut.source_done_seen=1;dut.write_done_seen=1;cycles(2);
 if(dut.img_idx!==1 || dut.index_commit_tgl===old_commit)$fatal(1,"foreground recovery");
                                                                   
 wait_stage(2);expiry();
 dut.load_timeout_cnt=dut.load_timeout_cycles+1;cycles(1);
 if(dut.load_busy || !dut.load_abort || !dut.auto_req_pending)
  $fatal(1,"timeout lost expiry or failed to abort");
 cycles(3);
 if(dut.scan_done || !dut.auto_req_pending || dut.prefetched_valid)
  $fatal(1,"rescan failed to preserve deadline / invalidate cache");
                                                                              
 dut.scan_done=1;dut.img_found_count=4;cycles(4);
 if(!dut.load_busy || dut.load_prefetch || dut.load_idx!==2)
  $fatal(1,"timeout rescan stalled expired autoplay");
                                            
 rst=1;cycles(2);if(dut.prefetched_valid || dut.load_prefetch)$fatal(1,"reset stale cache");
 $display("PASS autoplay prefetch: inactive bank guard, both completions, no early commit, no reload on expiry, late expiry queued, stop race, manual reuse, preview, wrap, failed preload retry/fallback, reset");$finish;
end
initial begin #100000;$fatal(1,"timeout idx%0d busy%0d stage%0d",dut.img_idx,dut.load_busy,dut.prefetched_valid);end
endmodule
