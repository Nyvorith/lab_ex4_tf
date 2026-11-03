`timescale 1ns/1ps
module tb_exhibit_caption;
    wire caption_enabled = 1'b1;
    wire reading_done_tgl;
    wire [1:0] reading_done_index;
    `include "caption_config.vh"
    function integer reference_length(input integer p);
        case(p)
            0:reference_length=CAPTION_LENGTH_0;
            1:reference_length=CAPTION_LENGTH_1;
            2:reference_length=CAPTION_LENGTH_2;
            3:reference_length=CAPTION_LENGTH_3;
        endcase
    endfunction
    reg clk=0; always #5 clk=~clk;
    reg rst_n=0, frame_start=0, commit=0, display_valid=0, preview_mode=0;
    reg auto_mode=0;
    reg [1:0] commit_index=0;
    reg [9:0] x=0,y=0;
    reg hs_in=1,vs_in=1,de_in=0;
    reg [23:0] rgb_in=24'habcdef;
    wire [23:0] rgb_out;
    wire hs_out,vs_out,de_out,caption_hit;
    exhibit_caption_overlay dut(.waveform_hit(1'b0), .brightness_value(8'd220), .contrast_value(8'd128), .preview_focus(2'd0), .speech_playing(1'b0), .speech_samples(32'd0), .artwork_ready(1'b1), .*);
    reg [15:0] font [0:CAPTION_GLYPH_ROW_DEPTH-1];
    reg [7:0] texts [0:511];
    integer model_pic=0, model_scroll=0, model_count=0;
    reg model_valid=0;
    reg [23:0] previous_rgb=0, expected_rgb;
    reg [2:0] previous_sync=3'b110;
    reg previous_hit=0, expected_hit;
    integer position, gid, checks=0, wrap_checks=0, carry_checks=0;
    always @(posedge clk) begin
        if (!rst_n) begin
            model_pic=0; model_scroll=0; model_count=0; model_valid=0;
            previous_rgb=0; previous_sync=3'b110; previous_hit=0;
        end else begin
            expected_rgb=rgb_in; expected_hit=0;
            if(model_valid && display_valid && !preview_mode && de_in && x<640 && y>=432 && y<480) begin
                expected_rgb={2'b0,rgb_in[23:18],2'b0,rgb_in[15:10],2'b0,rgb_in[7:2]};
                if(x>=16 && x<624 && y>=448 && y<464) begin
                    position=(x-16+model_scroll)%(reference_length(model_pic)*16+608);
                    if(x-16+model_scroll>2047) carry_checks=carry_checks+1;
                    if(position<reference_length(model_pic)*16) begin
                        gid=texts[model_pic*128+position/16];
                        expected_hit=(font[gid*16+(y-448)] >> (15-position%16)) & 1;
                        if(expected_hit) expected_rgb=24'hf0f4f8;
                    end
                end
            end
            if(frame_start) begin
                if(!display_valid) begin model_valid=0; model_scroll=0; model_count=0; end
                else if(commit) begin model_valid=1; model_pic=commit_index; model_scroll=0; model_count=0; end
                else if(!preview_mode && model_valid) begin
                    model_count=model_count+1;
                    if(model_count==3) begin
                        model_count=0; model_scroll=(model_scroll+1)%(reference_length(model_pic)*16+608);
                        if(model_scroll==0) wrap_checks=wrap_checks+1;
                    end
                end
            end
            #1;
            if(rgb_out !== previous_rgb || {hs_out,vs_out,de_out} !== previous_sync || caption_hit !== previous_hit)
                $fatal(1,"pipeline/pixel mismatch x=%0d y=%0d picture=%0d scroll=%0d rgb=%h wanted=%h sync=%b wanted=%b",x,y,model_pic,model_scroll,rgb_out,previous_rgb,{hs_out,vs_out,de_out},previous_sync);
            previous_rgb=expected_rgb; previous_sync={hs_in,vs_in,de_in}; previous_hit=expected_hit;
            checks=checks+1;
        end
    end
    task tick;
        begin @(posedge clk); #2; @(negedge clk); end
    endtask
    task boundary(input reg do_commit,input [1:0] index);
        begin
            frame_start=1; commit=do_commit; commit_index=index; de_in=0;
            tick; frame_start=0; commit=0; tick;
        end
    endtask
    integer pic,xx,yy,step,j,old_scroll;
    integer carry_possible=0;
    initial begin
        $readmemh("assets/exhibition/captions/generated/glyph_rows.hex",font);
        $readmemh("assets/exhibition/captions/generated/text_ids.hex",texts);
        repeat(3) tick; rst_n=1;
                                                                         
        display_valid=1; de_in=1; x=16; y=448; repeat(10) tick;
        for(pic=0;pic<4;pic=pic+1) begin
                                                                             
            if(reference_length(pic)*16+608-1+607>2047) carry_possible=1;
            boundary(1,pic);
                                                                                 
            for(yy=431;yy<481;yy=yy+1) begin
                for(xx=0;xx<641;xx=xx+1) begin
                    x=xx; y=yy; de_in=(xx<640 && yy<480);
                    rgb_in={xx[7:0],yy[7:0],8'h97}; hs_in=xx[0]; vs_in=yy[0]; tick;
                end
            end
            if(dut.scroll!=0) $fatal(1,"Moved inside a frame");
                                                                               
            for(step=0;step<(reference_length(pic)*16+608)*3;step=step+1) begin
                boundary(0,(pic+1)%4);                                                         
                x=623; y=451; de_in=1; tick;
                x=16; y=457; tick;
            end
            if(dut.picture!=pic || dut.scroll!=0) $fatal(1,"Bad wrap or uncommitted target adopted");
            boundary(0,0); boundary(0,0); boundary(0,0);
            old_scroll=dut.scroll; preview_mode=1;
            for(j=0;j<8;j=j+1) begin boundary(0,0); de_in=1; x=100; y=450; tick; end
            if(dut.scroll!=old_scroll) $fatal(1,"Preview moved scroll");
            preview_mode=0;
        end
        display_valid=0; boundary(0,0); de_in=1; repeat(4) tick;
        if(dut.valid) $fatal(1,"Invalid display retained caption");
        if(wrap_checks!=4 || (carry_possible && carry_checks==0)) $fatal(1,"Missing reachable wrap/carry coverage");
        $display("PASS caption: %0d pixels/cycles, four pictures, wrap=%0d carry=%0d, sync alignment, preview, no-commit retention",checks,wrap_checks,carry_checks);
        $finish;
    end
endmodule
