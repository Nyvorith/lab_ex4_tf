`timescale 1ns/1ps
module tb_artwork_label;
    reg clk=0; always #5 clk=~clk;
    reg rst_n=0, frame_start=0, commit=0, display_valid=0, preview_mode=0;
    reg artwork_ready=0, auto_mode=0, caption_enabled=0;
    reg [1:0] commit_index=0;
    reg [9:0] x=0,y=0;
    reg hs_in=1,vs_in=1,de_in=1;
    reg [23:0] rgb_in=24'h8090a0;
    wire hs_out,vs_out,de_out,caption_hit,reading_done_tgl;
    wire [23:0] rgb_out;
    wire [1:0] reading_done_index;
    exhibit_caption_overlay #(.ARTWORK_LABEL(1),.LABEL_FRAMES(5),
        .SWITCHABLE_CAPTION(1),.READING_GUIDE(1)) dut(.waveform_hit(1'b0), .brightness_value(8'd220), .contrast_value(8'd128), .preview_focus(2'd0), .speech_playing(1'b0), .speech_samples(32'd0), .*);
    reg [15:0] font[0:4095];
    reg [7:0] texts[0:511];
    integer picture,xx,yy,row,col,address,checks=0;
    reg [23:0] expected;
    reg [15:0] bits;
    task tick; begin @(posedge clk); #1; @(negedge clk); end endtask
    task boundary;
        begin frame_start=1;tick;frame_start=0;tick;end
    endtask
    task pixel(input integer px,py,input [23:0] wanted);
        begin
            x=px;y=py;repeat(3)tick;
            if(rgb_out!==wanted || {hs_out,vs_out,de_out}!=={hs_in,vs_in,de_in})
                $fatal(1,"label pixel p=%0d x=%0d y=%0d rgb=%h expected=%h",picture,px,py,rgb_out,wanted);
            checks=checks+1;
        end
    endtask
    reg [23:0] q0,q1,current_expected;
    reg [2:0] s0,s1;
    integer i;
    initial begin
        $readmemh("assets/exhibition/captions/generated/glyph_rows.hex",font);
        $readmemh("assets/exhibition/captions/generated/text_ids.hex",texts);
        repeat(3)tick;rst_n=1;repeat(3)tick;
        for(picture=0;picture<4;picture=picture+1) begin
            artwork_ready=0;display_valid=1;commit=1;commit_index=picture;
            boundary;commit=0;
            repeat(12)boundary;
            pixel(352,16,24'h8090a0);
            if(dut.label_frames!==0 || !dut.label_pending)$fatal(1,"label consumed during fade");
            artwork_ready=1;boundary;
            if(dut.label_frames!==5 || dut.picture!==picture)$fatal(1,"wrong successful commit/label start");
            for(yy=12;yy<68;yy=yy+1) begin
                for(xx=348;xx<628;xx=xx+1) begin
                    expected=24'h8090a0;
                    if(xx>=352 && xx<624 && yy>=16 && yy<64) begin
                        expected=24'h404850;
                        row=yy>=40 ? yy-40 : yy-20;
                        if(xx>=360 && xx<616 && row>=0 && row<16) begin
                            col=(xx-360)/16;
                            address=picture*128+96+(yy>=40 ? 16 : 0)+col;
                            bits=font[texts[address]*16+row];
                            if(bits[15-((xx-360)%16)])expected=yy>=40 ? 24'he0e4e8 : 24'hf0e4c8;
                        end
                    end
                    pixel(xx,yy,expected);
                end
            end
            repeat(4)boundary;pixel(352,16,24'h404850);
            boundary;pixel(352,16,24'h8090a0);
            repeat(3)boundary;
            if(dut.label_frames!==0)$fatal(1,"expired label restarted without commit");
        end
        commit=1;commit_index=2;boundary;commit=0;boundary;
        preview_mode=1;boundary;pixel(352,16,24'h8090a0);
        repeat(8)boundary;preview_mode=0;boundary;
        pixel(352,16,24'h404850);
        if(dut.picture!==2 || dut.label_frames!==5)$fatal(1,"preview return failed");
        artwork_ready=0;pixel(352,16,24'h8090a0);
        artwork_ready=1;de_in=0;pixel(352,16,24'h8090a0);de_in=1;
        x=352;y=16;repeat(3)tick;q0=24'h404850;q1=q0;s0=3'b111;s1=s0;
        for(i=0;i<64;i=i+1) begin
            x=i[0] ? 351 : 352;hs_in=i[1];vs_in=i[2];de_in=i[3];
            current_expected=de_in && x==352 ? 24'h404850 : rgb_in;
            @(posedge clk);#1;
            if(rgb_out!==q0 || {hs_out,vs_out,de_out}!==s0)$fatal(1,"dynamic label pipeline");
            q1=q0;q0=current_expected;s1=s0;s0={hs_in,vs_in,de_in};
            @(negedge clk);
        end
        display_valid=0;boundary;de_in=1;pixel(352,16,24'h8090a0);
        rst_n=0;tick;rst_n=1;boundary;
        if(dut.label_pending || dut.label_frames!==0)$fatal(1,"label reset");
        $display("PASS artwork label: %0d pixels, four artwork bindings, fade wait, exact expiry, no failed-load replacement, preview return, blanking, sync alignment, reset",checks);
        $finish;
    end
    initial begin #10000000;$fatal(1,"timeout");end
endmodule
