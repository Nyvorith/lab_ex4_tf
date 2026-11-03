`timescale 1ns/1ps
module tb_preview_warmup;
reg clk=0,rst=1; always #5 clk=~clk;
wire mode,loading;
sd_card_bmp #(.CLK_FREQ_HZ(1000),.PREVIEW_WARMUP(1),.PREVIEW_FOCUS_PREFETCH(1),.AUTO_PREFETCH(1),
 .AUTO_FROM_CAPTION(1),.MANUAL_PREFETCH(1)) dut(
 .clk(clk),.rst(rst),.key_next(1'b1),.key_auto(1'b1),.key_mode(1'b1),
 .preview_mode(mode),.image_loading(loading),.auto_advance_event(1'b0),
 .bmp_width(16'd640),.bmp_height(16'd480),.sdr_init_done(1'b1),
 .next_req_gated(1'b0),.wav_sd_req(1'b0),.wav_sd_lba(32'd0),
 .write_finish_toggle(1'b0),.write_req_ack(1'b0),.SD_MISO(1'b1));
task cycles(input integer n); repeat(n) @(negedge clk); endtask
task mode_press; begin
 force dut.key_mode_press=1;cycles(1);force dut.key_mode_press=0;cycles(1);
end endtask
integer i; reg old_commit; reg [1:0] old_bank;
initial begin
 force dut.sd_init_done=1;force dut.scanner_scan_done=0;
 force dut.scan_resource_valid=4'b1111;force dut.bmp_ready=1;
 force dut.load_error=0;force dut.scaler_done=0;force dut.write_finish_pulse=0;
 cycles(5);rst=0;cycles(1);
 dut.scan_kicked=1;dut.scan_done=1;dut.first_image_committed=1;
 dut.img_found_count=4;dut.img_idx=0;dut.display_valid=1;dut.preview_loaded=1;
 old_commit=dut.index_commit_tgl;old_bank=dut.disp_buf_idx;
 wait(dut.load_busy);cycles(1);
 mode_press();
 if(mode || !dut.preview_open_pending)$fatal(1,"early entry exposed incomplete wall");
 mode_press();
 if(mode || dut.preview_open_pending)$fatal(1,"pending entry did not cancel");
 mode_press();
 for(i=1;i<4;i=i+1) begin
   wait(dut.load_busy);cycles(1);
   if(dut.load_idx!==i[1:0] || !dut.load_preview_only || loading ||
      dut.write_buf_idx==old_bank)$fatal(1,"wrong warmup target/bank/visibility");
   dut.source_done_seen=1;cycles(2);
   if(!dut.load_busy || dut.preview_loaded[i])$fatal(1,"source alone marked cache complete");
   dut.write_done_seen=1;cycles(1);
   if(dut.img_idx!==0 || dut.disp_buf_idx!==old_bank || dut.index_commit_tgl!==old_commit ||
      !dut.prefetched_valid || dut.load_idx!==i[1:0])$fatal(1,"warmup lost staged frame or published it");
   if(i<3 && mode)$fatal(1,"wall appeared before all caches ready");
 end
 cycles(5);
 if(!mode || dut.preview_loaded!==15 || dut.preview_focus!==0)
   $fatal(1,"ready wall not opened with original focus");
 mode_press();cycles(5);
 if(mode || dut.img_idx!==0)$fatal(1,"cancel state mode=%b idx=%d pending=%b busy=%b select=%b",mode,dut.img_idx,dut.preview_open_pending,dut.load_busy,dut.preview_select_pending);
 wait(dut.load_busy);cycles(1);
 if(!dut.load_prefetch || dut.load_preview_only || dut.load_idx!==1)
   $fatal(1,"next-frame prefetch not restored after warmup");
 $display("PASS warmup: all caches without full-frame commit, delayed/cancelled entry, complete wall, next prefetch restored");
 $finish;
end
initial begin #2000000;$fatal(1,"warmup timeout");end
endmodule
