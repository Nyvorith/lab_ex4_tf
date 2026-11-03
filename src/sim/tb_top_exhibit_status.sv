`timescale 1ns/1ps
module tb_top_exhibit_status;
    reg clk=0,rst_n=0; always #10 clk=~clk;
    top dut(.clk(clk),.rst_n(rst_n),.key2(1'b1),.key3(1'b1),.key4(1'b1),.sd_miso(1'b1));
    reg busy=0,valid=0,vs=1;
    reg [3:0] error=0;
    reg [11:0] px=168;
    reg [11:0] overlay_y=0;
    integer scan_x,scan_y,selection;
    task tick; begin @(posedge clk); #1; @(negedge clk); end endtask
    task frame;
        begin vs=1;repeat(6) tick; vs=0;repeat(2) tick;vs=1;repeat(6) tick;end
    endtask
    initial begin
        force dut.por_done=1;
        force dut.image_loading_sd=busy;
        force dut.display_valid=valid;
        force dut.osd_err_v2=error;
        force dut.preview_mode_q=0;
        force dut.raw_x=px; force dut.raw_y=12'd53;
        force dut.raw_de=1; force dut.raw_hs=1; force dut.raw_vs=vs;
        force dut.reader_pixel_rgb=24'habcdef;
        force dut.u_osd_overlay_24.line_y=overlay_y;
        repeat(20) tick;rst_n=1;repeat(20) tick;
        frame;
        if(dut.u_osd_overlay_24.u_osd.state_text!=="INIT") $fatal(1,"initial state hidden");
        if(dut.vout_data!==24'h000000 || !dut.de) $fatal(1,"first-image status suppressed: %h",dut.vout_data);
        px=400;repeat(5) tick;
        if(dut.vout_data!==0) $fatal(1,"first-image background not black");
        busy=1;frame;
        if(dut.u_osd_overlay_24.u_osd.state_text!=="LOAD") $fatal(1,"busy CDC disconnected");
        busy=0;error=2;px=168;frame;
        if(dut.u_osd_overlay_24.u_osd.state_text!=="ERR " || dut.vout_data!==24'h000000)
            $fatal(1,"no-first-image error hidden");
        if(dut.u_media_frame_reader.reader_busy || dut.reader_underflow ||
           dut.reader_error!=0 || dut.reader_scan_enabled)
            $fatal(1,"reader armed before first successful image");
                                                                          
                                                                             
        error=0;valid=1;repeat(8) tick;
        if(dut.reader_scan_enabled || dut.reader_app_rd_en)
            $fatal(1,"reader enabled mid-frame");
        error=0;valid=1;frame;
        if(!dut.reader_scan_enabled || !dut.u_media_frame_reader.frame_armed_pix)
            $fatal(1,"first committed image failed to arm reader at frame boundary");
        if(dut.u_osd_overlay_24.u_osd.state_text!=="SHOW" || dut.reader_display_rgb!==24'habcdef)
            $fatal(1,"ready state not connected");
        for(selection=0;selection<4;selection=selection+1)begin
            force dut.osd_index=selection[1:0];
            frame;
            for(scan_y=0;scan_y<40;scan_y=scan_y+1)begin
                overlay_y=scan_y;
                for(scan_x=0;scan_x<160;scan_x=scan_x+1)begin
                    px=scan_x+160;tick;
                    if(dut.osd_active!==0 || dut.osd_rgb_out!==dut.u_osd_overlay_24.rgb_in)
                        $fatal(1,"persistent number changed pixel %0d,%0d selection%0d",scan_x,scan_y,selection);
                end
            end
        end
        $display("PASS top clean display: all four indices, 25600 upper-left pixels unchanged, status CDC retained, black invalid frame and frame-boundary startup");
        $finish;
    end
    initial begin #2000000; $fatal(1,"timeout");end
endmodule
