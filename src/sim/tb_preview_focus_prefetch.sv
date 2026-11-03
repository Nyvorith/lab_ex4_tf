`timescale 1ns/1ps
module tb_preview_focus_prefetch;
reg clk=0,rst=1; always #5 clk=~clk;
wire loading,mode;
reg [31:0] source_size={16'd1024,16'd768};
reg [19:0] fitted_size={10'd640,10'd480};
sd_card_bmp #(.CLK_FREQ_HZ(1000),.AUTO_FROM_CAPTION(1),.AUTO_PREFETCH(1),
 .PREVIEW_WARMUP(1),.PREVIEW_FOCUS_PREFETCH(1)) dut(
 .clk(clk),.rst(rst),.key_next(1'b1),.key_auto(1'b1),.key_mode(1'b1),
 .preview_mode(mode),.image_loading(loading),.auto_advance_event(1'b0),
 .bmp_width(16'd640),.bmp_height(16'd480),.sdr_init_done(1'b1),
 .next_req_gated(1'b0),.wav_sd_req(1'b0),.wav_sd_lba(32'd0),
 .write_finish_toggle(1'b0),.write_req_ack(1'b0),.SD_MISO(1'b1));
integer starts=0; reg old_commit; reg [1:0] old_bank;
always @(posedge clk) if(!rst && dut.load_start_pulse) starts=starts+1;
task cycles(input integer n);repeat(n)@(negedge clk);endtask
task focus_next;begin
 force dut.key_next_press=1;cycles(1);force dut.key_next_press=0;cycles(1);
end endtask
task confirm;begin
 force dut.key_auto_press=1;cycles(1);force dut.key_auto_press=0;cycles(1);
end endtask
task enter;begin
 force dut.key_mode_press=1;cycles(1);force dut.key_mode_press=0;cycles(2);
 if(!mode)$fatal(1,"preview did not open");
end endtask
task staged(input integer target);begin
 wait(dut.load_busy);cycles(2);
 if(dut.load_idx!==target[1:0] || !dut.load_prefetch || loading ||
    dut.write_buf_idx==dut.disp_buf_idx)$fatal(1,"bad focused preload %0d",target);
end endtask
task finish;begin
 cycles(2);dut.source_done_seen=1;cycles(2);
 if(!dut.load_busy)$fatal(1,"source only released frame");
 dut.write_done_seen=1;cycles(1);
end endtask
initial begin
 force dut.sd_init_done=1;force dut.scanner_scan_done=0;
 force dut.scan_resource_valid=4'b1111;force dut.bmp_ready=1;
 force dut.load_error=0;force dut.scaler_done=0;force dut.write_finish_pulse=0;
 force dut.scaler_source_size=source_size;force dut.scaler_fitted_size=fitted_size;
 force dut.key_next_press=0;force dut.key_auto_press=0;force dut.key_mode_press=0;
 cycles(5);rst=0;cycles(1);
 dut.scan_kicked=1;dut.scan_done=1;dut.first_image_committed=1;
 dut.img_found_count=4;dut.img_idx=0;dut.display_valid=1;dut.preview_loaded=15;
 dut.prefetch_guard=50;
 old_commit=dut.index_commit_tgl;old_bank=dut.disp_buf_idx;
 enter();focus_next();staged(1);
 confirm();cycles(4);
 if(!mode || dut.img_idx!==0 || dut.index_commit_tgl!==old_commit)
   $fatal(1,"confirmation published incomplete frame");
 finish();cycles(4);
 if(mode || dut.img_idx!==1 || starts!=1 || dut.index_commit_tgl===old_commit ||
    dut.disp_buf_idx===old_bank || dut.committed_source_size!==source_size)
   $fatal(1,"in-flight confirmation reloaded or lost metadata");
                                                                                
 enter();focus_next();staged(2);focus_next();confirm();
 old_commit=dut.index_commit_tgl;finish();cycles(3);
 if(!dut.load_busy || dut.load_idx!==3 || dut.load_prefetch || !mode ||
    dut.index_commit_tgl!==old_commit)$fatal(1,"stale focus buffer used for selection");
 finish();cycles(4);
 if(mode || dut.img_idx!==3 || starts!=3)$fatal(1,"rapid selection fallback failed");
                                                                                 
 enter();focus_next();staged(0);old_commit=dut.index_commit_tgl;finish();cycles(20);
 if(!mode || !dut.prefetched_valid || dut.img_idx!==3 ||
    dut.index_commit_tgl!==old_commit || starts!=4)$fatal(1,"focus committed without confirm");
 confirm();cycles(4);
 if(mode || dut.img_idx!==0 || starts!=4 || dut.index_commit_tgl===old_commit)
   $fatal(1,"completed focus was not directly committed");
                                                                                 
 enter();focus_next();staged(1);old_commit=dut.index_commit_tgl;
 force dut.load_error=1;force dut.bmp_error=3'd1;cycles(1);
 force dut.load_error=0;cycles(2);force dut.load_error=1;cycles(1);
 force dut.load_error=0;cycles(80);
 if(dut.load_busy || dut.prefetched_valid || dut.index_commit_tgl!==old_commit || !mode)
   $fatal(1,"failed focused read published or retried forever");
 confirm();cycles(3);
 if(!dut.load_busy || dut.load_prefetch || dut.load_idx!==1)
   $fatal(1,"confirmation did not fall back after failed prefetch");
 finish();cycles(4);
 if(mode || dut.img_idx!==1)$fatal(1,"foreground recovery after failed focus");
 rst=1;cycles(3);
 if(dut.prefetched_valid || dut.preview_focus_attempted || mode)
   $fatal(1,"reset kept stale selection");
 $display("PASS focused prefetch: ready/in-flight confirmation without reread, stale focus rejection, no early commit, metadata, failure fallback, reset");
 $finish;
end
initial begin #3000000;$fatal(1,"focus test timeout");end
endmodule
