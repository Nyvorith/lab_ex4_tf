`timescale 1ns/1ps
module tb_audio_status_osd;
    reg clk=0, rst_n=0, frame=0;
    always #5 clk=~clk;
    reg [2:0] status=0;
    reg [11:0] x=48, y=8;
    wire [11:0] rgb;
    wire hit;
    status_osd_overlay dut(.clk(clk), .rst_n(rst_n), .frame_start(frame),
        .active_index(2'd0), .auto_enabled(1'b0), .error_code(8'd0),
        .audio_status(status), .in_de(1'b1), .in_rgb(12'h123),
        .pixel_x(x), .pixel_y(y), .out_rgb(rgb), .out_de(), .osd_pixel(hit));
    integer s, c;
    reg [4:0] expected;
    initial begin
        repeat(2) @(negedge clk); rst_n=1;
        for(s=0;s<5;s=s+1) begin
            @(negedge clk);
            status=s; frame=1;
            @(negedge clk); frame=0;
            case(s)
                0,2,3: expected=5'b11111;
                1: expected=5'b00100;
                4: expected=5'b10001;
            endcase
            for(c=0;c<5;c=c+1) begin
                x=48+c; #1;
                if(hit !== expected[4-c]) $fatal(1,"Status glyph %0d col %0d",s,c);
            end
            status=(s+1)%5; #1;
            if(dut.audio_q !== s) $fatal(1,"Status changed mid-frame");
            x=100; #1;
            if(rgb !== 12'h123 || hit !== 0) $fatal(1,"Background changed");
        end
        $display("PASS audio OSD: status glyphs 0..4, frame latch, background passthrough");
        $finish;
    end
endmodule
