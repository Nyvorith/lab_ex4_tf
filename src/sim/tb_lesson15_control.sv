`timescale 1ns/1ps
module tb_lesson15_control;
    reg clk=0,rst=1,next_key=1,auto_key=1,mode_key=1;
    always #5 clk=~clk;
    wire mode;
    wire [1:0] focus;
    wire [3:0] loaded;
    wire next_req;
    reg [31:0] test_source_size=0;
    reg [19:0] test_fitted_size=0;
    reg [31:0] previous_source;
    reg previous_toggle;
    reg previous_failed;
    reg advance=0;
    sd_card_bmp #(.CLK_FREQ_HZ(1000),.AUTO_FROM_CAPTION(1)) dut (
        .clk(clk),.rst(rst),.key_next(next_key),.key_auto(auto_key),.key_mode(mode_key),
        .preview_mode(mode),.preview_focus(focus),.preview_loaded(loaded),
        .bmp_width(16'd640),.bmp_height(16'd480),.sdr_init_done(1'b1),
        .next_req_gated(1'b0),.wav_sd_req(1'b0),.wav_sd_lba(32'd0),
        .write_finish_toggle(1'b0),.write_req_ack(1'b0),.SD_MISO(1'b1),
        .key_next_req(next_req),
        .auto_advance_event(advance)
    );
    task tap_mode;
        begin
            @(negedge clk); mode_key=0;
            repeat(70) @(negedge clk); mode_key=1;
            repeat(70) @(negedge clk);
        end
    endtask
    task finish_load(input integer expected_index);
        begin
            wait(dut.load_busy);
            if(dut.load_idx !== expected_index[1:0])
                $fatal(1,"loading %0d expected %0d",dut.load_idx,expected_index);
                                                                            
                                                                
            repeat(5) @(negedge clk);
            previous_source=dut.committed_source_size;
            test_source_size={16'(320+expected_index*100),16'(240+expected_index*20)};
            test_fitted_size={10'd640,10'(400+expected_index)};
            @(negedge clk);
            if(dut.committed_source_size!==previous_source) $fatal(1,"Dimensions published before completion");
            dut.source_done_seen=1; dut.write_done_seen=1;
            @(negedge clk);
            if(dut.committed_source_size!==test_source_size || dut.committed_fitted_size!==test_fitted_size)
                $fatal(1,"Decoder dimensions not latched with successful picture");
        end
    endtask
    task focus_next;
        begin
            @(negedge clk); force dut.key_next_press=1;
            @(negedge clk); release dut.key_next_press;
        end
    endtask
    task confirm;
        begin
            @(negedge clk); force dut.key_auto_press=1;
            @(negedge clk); release dut.key_auto_press;
        end
    endtask
    initial begin
        force dut.sd_init_done=1;
        force dut.scanner_scan_done=0;
        force dut.scan_resource_valid=4'b1111;
        force dut.bmp_ready=1;
        force dut.load_error=0;
        force dut.streamer_file_done=0;
        force dut.scaler_source_size=test_source_size;
        force dut.scaler_fitted_size=test_fitted_size;
        repeat(5) @(negedge clk); rst=0;
        @(negedge clk);
        dut.scan_kicked=1; dut.scan_done=1; dut.first_image_committed=1;
        dut.img_found_count=4; dut.img_idx=0; dut.display_valid=1;
        dut.preview_loaded=1;
        tap_mode();
        if(!mode || focus!==0) $fatal(1,"mode entry failed");
        focus_next();
        if(next_req) $fatal(1,"preview key leaked to full-size next request");
        confirm();                                       
        if(!mode || dut.preview_select_pending) $fatal(1,"selected unloaded image");
        finish_load(1); finish_load(2); finish_load(3);
        repeat(5) @(negedge clk);
        if(loaded!==15) $fatal(1,"not all previews marked ready: %b",loaded);
        if(focus!==1) $fatal(1,"background loading moved focus");
        tap_mode();                                                         
        finish_load(0);
        repeat(5) @(negedge clk);
        if(mode || dut.img_idx!==0) $fatal(1,"background cancel lost original image");
        tap_mode(); focus_next();
        confirm();
        wait(dut.load_busy); repeat(4) @(negedge clk);
        if(!dut.preview_loaded[1] || dut.preview_capture_start)
            $fatal(1,"confirmed full-size reload invalidated completed thumbnail");
        finish_load(1);
        repeat(5) @(negedge clk);
        if(mode || dut.img_idx!==1 || dut.state_code!==2)
            $fatal(1,"direct selection did not commit selected full image");
        tap_mode();
        focus_next(); focus_next(); focus_next();
        if(focus!==0) $fatal(1,"focus did not wrap");
        tap_mode();                             
        repeat(5) @(negedge clk);
        if(mode || dut.img_idx!==1) $fatal(1,"cancel did not restore original image");
                                                                      
        @(negedge clk); auto_key=0;
        repeat(1200) @(negedge clk);
        if(dut.prev_req_pending || dut.auto_play_en || dut.load_busy)
            $fatal(1,"long press leaked into short/legacy controls");
        auto_key=1;
        repeat(70) @(negedge clk);
        if(dut.auto_play_en) $fatal(1,"long release toggled autoplay");
                                                                               
        dut.auto_play_en=1;
        repeat(1100) @(negedge clk);
        if(dut.load_busy || dut.auto_req_pending) $fatal(1,"Legacy timer interrupted reading");
        advance=1;@(negedge clk);advance=0;
        finish_load(2);
        dut.auto_play_en=0;
        repeat(5) @(negedge clk);
        advance=1;@(negedge clk);advance=0;repeat(4)@(negedge clk);
        if(dut.load_busy || dut.auto_req_pending) $fatal(1,"Manual mode consumed reading event");
        dut.auto_play_en=1;dut.auto_req_pending=1;
        force dut.key_auto_press=1;
        @(negedge clk);release dut.key_auto_press;
        repeat(4)@(negedge clk);
        if(dut.auto_play_en || dut.load_busy || dut.auto_req_pending)
            $fatal(1,"Stopping autoplay lost race with queued completion");
                                                                            
        previous_source=dut.committed_source_size;
        previous_toggle=dut.index_commit_tgl;
        previous_failed=dut.load_failed_tgl;
        test_source_size={16'd2048,16'd1};
        test_fitted_size={10'd640,10'd1};
        dut.load_busy=1; dut.source_done_seen=0; dut.write_done_seen=0;
        dut.load_timeout_cnt=dut.load_timeout_cycles+1;
        repeat(4) @(negedge clk);
        if(dut.committed_source_size!==previous_source || dut.index_commit_tgl!==previous_toggle)
            $fatal(1,"Timed-out load changed committed dimensions/toggle");
        if(dut.error_code!==4'd2) $fatal(1,"Timed-out load must expose error 02");
        if(dut.load_failed_tgl===previous_failed) $fatal(1,"Timeout missing final failure event");
        previous_failed=dut.load_failed_tgl;
                                                                            
        dut.scan_done=1; dut.load_busy=1; dut.retry_count=0;
        dut.load_timeout_cnt=0; dut.source_done_seen=0; dut.write_done_seen=0;
        force dut.load_error=1; force dut.bmp_error=3'd1;
        @(negedge clk);
        if(dut.load_failed_tgl!==previous_failed || !dut.load_busy || dut.retry_count!==1)
            $fatal(1,"Retry incorrectly reported final failure");
        @(negedge clk);
        if(dut.load_failed_tgl===previous_failed || dut.load_busy)
            $fatal(1,"Exhausted retry missing final failure");
        release dut.load_error; release dut.bmp_error;
        if(dut.committed_source_size!==previous_source || dut.index_commit_tgl!==previous_toggle)
            $fatal(1,"Failure changed displayed picture");
        $display("PASS controller metadata: success-only latch and timeout retention");
        $display("PASS: mode entry, unloaded selection guard, prefetch, focus, direct selection, cancel, long/short isolation");
        $finish;
    end
    initial begin #1000000; $fatal(1,"control test timeout"); end
endmodule
