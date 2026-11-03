`timescale 1ns/1ps
module tb_exhibit_status;
    reg clk=0, rst_n=0, frame=0, busy=0, ready=0, preview=0, de=1, auto_en=0;
    reg [7:0] error=0;
    reg [1:0] index=0;
    reg [11:0] x=8,y=8;
    wire [11:0] rgb;
    wire hit, out_de;
    wire [11:0] number_rgb;
    wire number_hit;
    status_osd_overlay #(.EXHIBITION_UI(2)) number_dut (
        .clk(clk),.rst_n(rst_n),.frame_start(frame),.active_index(index),
        .auto_enabled(auto_en),.error_code(error),.audio_status(3'd1),
        .image_loading(busy),.display_ready(ready),.preview_active(preview),
        .in_de(de),.in_rgb(12'h123),.pixel_x(x),.pixel_y(y),
        .out_rgb(number_rgb),.out_de(),.osd_pixel(number_hit));
    always #5 clk=~clk;
    status_osd_overlay #(.EXHIBITION_UI(1)) dut (
        .clk(clk),.rst_n(rst_n),.frame_start(frame),.active_index(index),
        .auto_enabled(auto_en),.error_code(error),.audio_status(3'd0),
        .image_loading(busy),.display_ready(ready),.preview_active(preview),
        .in_de(de),.in_rgb(12'h123),.pixel_x(x),.pixel_y(y),
        .out_rgb(rgb),.out_de(out_de),.osd_pixel(hit));
    task latch;
        begin @(negedge clk); frame=1; @(negedge clk); frame=0; #1; end
    endtask
    task state_is(input [31:0] expected);
        begin #1; if(dut.state_text!==expected) $fatal(1,"state %s expected %s",dut.state_text,expected); end
    endtask
    task top_row(input integer slot, input [4:0] expected);
        integer col;
        begin
            y=8;
            for(col=0;col<8;col=col+1) begin
                x=8+slot*8+col; #1;
                if(hit !== (col<5 ? expected[4-col] : 1'b0))
                    $fatal(1,"glyph slot %0d col %0d",slot,col);
            end
        end
    endtask
    integer i,xx,yy;
    reg [4:0] expected_row;
    initial begin
        repeat(2) @(negedge clk); rst_n=1; latch;
        if(number_hit || number_rgb!==12'h123) $fatal(1,"number visible before first image");
        state_is("INIT"); top_row(5,5'b11111); top_row(6,5'b10001);
        busy=1; state_is("INIT"); latch; state_is("LOAD");
        top_row(5,5'b10000); top_row(6,5'b01110); top_row(8,5'b11110);
        ready=1; index=2; busy=0; latch; state_is("SHOW");
        top_row(1,5'b11111); top_row(3,5'b10001);
        preview=1; latch; state_is("PREV"); top_row(5,5'b11110);
        error=8'h02; latch; state_is("ERR ");
        top_row(11,5'b11111); top_row(12,5'b11111);
        x=8;y=8;#1;if(rgb!==12'hf44) $fatal(1,"error not red");
        busy=1; latch; state_is("LOAD");                               
        busy=0; preview=0; latch; state_is("ERR ");
        if(dut.index_q!==2 || !dut.ready_q) $fatal(1,"failed load changed picture identity");
        error=0; auto_en=1; index=3; latch; state_is("SHOW");
        top_row(1,5'b10001); top_row(3,5'b01110);
        x=112;y=8;#1;if(rgb!==12'h123 || hit) $fatal(1,"outside overlay changed");
        x=8;y=16;#1;if(rgb!==12'h123 || hit) $fatal(1,"metadata area changed");
        x=8;y=8;de=0;#1;if(rgb!==12'h123 || hit || out_de) $fatal(1,"blanking changed");
        de=1;ready=1;
        for(i=0;i<4;i=i+1) begin
            index=i;error=8'h42;busy=1;auto_en=1;latch;
            for(yy=8;yy<16;yy=yy+1) begin
                y=yy;expected_row=number_dut.font_row(i+1,yy-8);
                for(xx=8;xx<136;xx=xx+1) begin
                    x=xx;#1;
                    if(number_hit !== ((xx<13 && yy<15) ? expected_row[12-xx] : 1'b0))
                        $fatal(1,"number-only glyph or hidden status leaked index%0d x%0d y%0d",i,xx,yy);
                    if(number_rgb !== (number_hit ? 12'hff0 : 12'h123))
                        $fatal(1,"number-only color/background");
                end
            end
        end
        x=10;y=8;de=0;#1;if(number_hit || number_rgb!==12'h123)$fatal(1,"number blanking");
        $display("PASS exhibition status: legacy status and number-only 1..4, no status/mode/error/audio glyphs, frame latch, color, bounds, DE");
        $finish;
    end
endmodule
