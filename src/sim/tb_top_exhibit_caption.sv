`timescale 1ns/1ps
module tb_top_exhibit_caption;
    reg clk=0,rst_n=0; always #10 clk=~clk;
    top dut(.clk(clk),.rst_n(rst_n),.key2(1'b1),.key3(1'b1),.key4(1'b1),.sd_miso(1'b1));
    reg [1:0] bank=0;
    reg [3:0] state=0;
    reg toggle=0, valid=0, frame=0, preview=0;
    reg failed_toggle=0;
    reg auto_mode=0;
    reg narration_on=0;
    reg [31:0] audio_samples=0;
    reg [11:0] scan_x=160,scan_y=477;
    reg scan_de=0,scan_hs=1,scan_vs=1;
    reg [23:0] color=24'h8090a0;
    reg [31:0] source_size={16'd1920,16'd1080};
    reg [19:0] fitted_size={10'd640,10'd360};
    task tick; begin @(posedge clk); #1; @(negedge clk); end endtask
    task boundary;
        begin frame=1; tick; frame=0; repeat(4) tick; end
    endtask
    task successful(input [1:0] b,input [3:0] s);
        begin bank=b; state=s; valid=1; toggle=~toggle; repeat(7) tick; end
    endtask
    task pixel(input [11:0] px,input [11:0] py,input [23:0] expected);
        begin
            scan_x=px; scan_y=py; scan_de=1; repeat(4) tick;
            if(dut.vout_data!==expected || dut.de!==1) $fatal(1,"Top caption pixel %0d,%0d rgb=%h expected=%h",px,py,dut.vout_data,expected);
        end
    endtask
    integer i;
    integer reading_events=0;
    integer accepted_reading_events=0;
    always @(posedge clk) if(dut.sdcard_rst_n && (dut.reading_sd2 ^ dut.reading_sd3))
        reading_events=reading_events+1;
    always @(posedge clk) if(dut.sdcard_rst_n && dut.reading_event_sd)
        accepted_reading_events=accepted_reading_events+1;
    reg [23:0] q0,q1;
    reg [2:0] s0,s1;
    initial begin
        force dut.por_done=1;
        force dut.narration_enabled=narration_on;
        force dut.speech_playing_pix=narration_on;
        force dut.wav_samples_consumed=audio_samples;
        force dut.disp_buf_idx=bank;
        force dut.state_code=state;
        force dut.index_commit_tgl=toggle;
        force dut.load_failed_tgl=failed_toggle;
        force dut.display_valid=valid;
        force dut.auto_play_en_sd=auto_mode;
        force dut.committed_source_size=source_size;
        force dut.committed_fitted_size=fitted_size;
        force dut.reader_frame_start=frame;
        force dut.preview_mode_q=preview;
        force dut.raw_x=scan_x; force dut.raw_y=scan_y;
        force dut.raw_de=scan_de; force dut.raw_hs=scan_hs; force dut.raw_vs=scan_vs;
        force dut.reader_pixel_valid=1;
        force dut.waveform_rgb_out=color;
        repeat(20) tick; rst_n=1; repeat(20) tick;
        if(dut.sd_card_bmp_m0.FULL_FRAME_CACHE!=1 || dut.u_video_fade_transition.REVEAL_ON_COMMIT!=2 || dut.AUDIO_ENABLE!=0 || dut.THUMBNAIL_MODE!=0 || dut.CAPTION_ENABLE!=1) $fatal(1,"Wrong build defaults");
        successful(1,2);
        if(dut.exhibit_display_bank!=0 || dut.g_exhibit_caption.u_caption.valid) $fatal(1,"Premature commit");
        boundary;
        repeat(20) tick;
        pixel(168,69,24'h8090a0);                                                
        pixel(688,53,24'h8090a0);                                            
        preview=1; pixel(168,69,24'h8090a0); preview=0;
        if(dut.brightness_cfg!==220 || dut.brightness_q!==220 || dut.contrast_q!==128)
            $fatal(1,"Startup adjustment is not near-unity brightness / neutral contrast");
        if(dut.exhibit_display_bank!=1 || dut.g_exhibit_caption.u_caption.picture!=1 || dut.u_media_frame_reader.request_index_pix!=1)
            $fatal(1,"Reader/caption did not adopt PIC2 bank1 together");
        pixel(160,476,24'h8090a0);                              
        pixel(160,477,24'h8090a0);                                  
        narration_on=1;repeat(6)tick;
        pixel(160,477,24'h8090a0);                           
        boundary;pixel(160,477,24'h202428);
        pixel(176,493,24'h202428);                                                        
        pixel(783,519,24'h202428);                                                   
        auto_mode=1;repeat(6)tick;
        pixel(783,519,24'h202428);                                                
        boundary;pixel(783,519,24'h384048);
        pixel(160,477,24'h8090a0);                                                    
        auto_mode=0;repeat(6)tick;
        pixel(783,519,24'h384048);
        boundary;pixel(783,519,24'h202428);
        narration_on=0;repeat(6)tick;boundary;
        pixel(160,477,24'h8090a0);
        narration_on=1;repeat(6)tick;boundary;
        if(dut.g_exhibit_caption.u_caption.scroll!==0) $fatal(1,"caption did not restart");
        preview=1; pixel(160,477,24'h8090a0); preview=0;
                                                                               
        source_size={16'd800,16'd800}; fitted_size={10'd480,10'd480};
        repeat(3) boundary;
        pixel(688,53,24'h8090a0);                                      
        if(dut.g_exhibit_caption.u_caption.picture!=1 || dut.exhibit_display_bank!=1) $fatal(1,"Failed load changed binding");
                                                                            
                                                                               
        force dut.u_video_fade_transition.g_fade.state=2'd2;
        tick;
        release dut.u_video_fade_transition.g_fade.state;
        failed_toggle=~failed_toggle;repeat(8)tick;
        if(dut.fade_alpha!==0 || !dut.failed_pending) $fatal(1,"Failure was not deferred to boundary");
        boundary;
        if(dut.index_commit_pix || dut.u_video_fade_transition.g_fade.state!==3)
            $fatal(1,"Failure did not recover without commit");
        repeat(16)boundary;
        if(dut.fade_alpha!==255 || dut.fade_active || dut.fade_busy)
            $fatal(1,"Top failed-load fade stuck black");
        if(dut.exhibit_display_bank!==1 || dut.g_exhibit_caption.u_caption.picture!==1)
            $fatal(1,"Recovery altered bank/caption/dimensions");
                                                                                 
        bank=0; state=4; toggle=~toggle; repeat(2) tick;
        frame=1; tick; frame=0;
        if(dut.exhibit_display_bank!=1 || dut.g_exhibit_caption.u_caption.picture!=1) $fatal(1,"Boundary race adopted partial metadata");
        repeat(5) tick; boundary;
        repeat(20) tick;
        pixel(688,53,24'h8090a0);                                           
        if(dut.exhibit_display_bank!=0 || dut.g_exhibit_caption.u_caption.picture!=3 || dut.u_media_frame_reader.request_index_pix!=0)
            $fatal(1,"PIC4 bank0 commit failed");
                                                                   
        auto_mode=1;repeat(6)tick;boundary;
        repeat(119)boundary;repeat(8)tick;
        if(reading_events!==1 || dut.sd_card_bmp_m0.AUTO_FROM_CAPTION!==1)
            $fatal(1,"reading completion CDC/config not wired");
        if(accepted_reading_events!==1 || dut.reading_index_sd2!==3)
            $fatal(1,"current picture reading event rejected");
                                                                          
        state=1;repeat(6)tick;
        auto_mode=0;repeat(6)tick;boundary;
        auto_mode=1;repeat(6)tick;boundary;
        repeat(119)boundary;repeat(8)tick;
        if(reading_events!==2 || accepted_reading_events!==1)
            $fatal(1,"stale picture completion leaked across commit");
        if(dut.g_exhibit_caption.u_caption.progress_pixels>608)
            $fatal(1,"reading guide overflow");
        force dut.fade_active=0;
        successful(0,4);boundary;boundary;
        if(dut.g_exhibit_caption.u_caption.ARTWORK_LABEL!==1 ||
           dut.g_exhibit_caption.u_caption.label_frames!==90)
            $fatal(1,"artwork label not enabled after fade");
        pixel(512,61,24'h404850);
        force dut.fade_active=1;pixel(512,61,24'h8090a0);
        force dut.fade_active=0;
        preview=1;pixel(512,61,24'h8090a0);preview=0;
        repeat(90)boundary;pixel(512,61,24'h8090a0);
        release dut.fade_active;
        if(dut.g_exhibit_caption.u_caption.SPEECH_SYNC!==1)
            $fatal(1,"production speech timing disabled");
        auto_mode=0;narration_on=1;audio_samples=700000;
        repeat(80)tick;repeat(5)boundary;
        if(dut.g_exhibit_caption.u_caption.speech_target==0 || dut.g_exhibit_caption.u_caption.scroll==0 ||
           dut.g_exhibit_caption.u_caption.scroll>20)
            $fatal(1,"real top audio counter did not drive bounded caption motion");
        audio_samples=0;repeat(80)tick;repeat(10)boundary;
        if(dut.g_exhibit_caption.u_caption.scroll!=0)$fatal(1,"top audio rewind retained old scroll");
        narration_on=0;boundary;
                                                                             
        scan_x=200; scan_y=200; scan_de=1; repeat(4) tick;
        q0=color; q1=color; s0=3'b111; s1=3'b111;
        for(i=0;i<20;i=i+1) begin
            color=24'h123400+i; scan_hs=i[0]; scan_vs=i[1]; scan_de=i[2];
            @(posedge clk); #1;
            if(dut.vout_data!==(s1[0]?q1:24'd0) || {dut.hs,dut.vs,dut.de}!==s1)
                $fatal(1,"Top video pipeline misaligned at %0d",i);
            q1=q0; q0=color; s1=s0; s0={scan_hs,scan_vs,scan_de};
            @(negedge clk);
        end
        $display("PASS top caption: successful/failed commits, boundary race, same reader bank, normalized x/y, preview bypass, RGB/HS/VS/DE alignment, mute defaults");
        $finish;
    end
    initial begin #1000000; $fatal(1,"timeout"); end
endmodule
