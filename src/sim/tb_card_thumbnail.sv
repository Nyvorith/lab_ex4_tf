`timescale 1ns/1ps
module tb_card_thumbnail;
    reg capture_clk=0, pix_clk=0, rst_n=0;
    always #5 capture_clk=~capture_clk;
    always #7 pix_clk=~pix_clk;
    reg start=0, valid=0;
    reg [1:0] index=0, focus=0;
    reg [23:0] rgb=0;
    reg [11:0] x=0,y=0;
    reg [3:0] ready=15, available=15;
    wire [23:0] out_rgb;
    thumbnail_wall_cache #(.INTRO_CARD(1)) dut(capture_clk,rst_n,start,index,valid,rgb,
                              pix_clk,1'b1,x,y,focus,ready,available,out_rgb);
    function [23:0] pattern(input integer bank, input integer px, input integer py);
        pattern = {8'((px/10)*3+bank*19),8'((py/10)*5+bank*11),8'(px/10+py/10+bank*37)};
    endfunction
    function [15:0] pack565(input [23:0] c);
        pack565={c[23:19],c[15:10],c[7:3]};
    endfunction
    function [23:0] expand565(input [15:0] c);
        expand565={c[15:11],c[15:13],c[10:5],c[10:9],c[4:0],c[4:2]};
    endfunction
    task check_pixel(input integer px,input integer py,input [23:0] expected);
        begin
            @(negedge pix_clk); x=px-1; y=py;
            @(posedge pix_clk); #1; x=px; #1;
            if(out_rgb !== expected)
                $fatal(1,"pixel (%0d,%0d) got %h expected %h",px,py,out_rgb,expected);
        end
    endtask
    integer b,ix,iy,sy,sx;
    reg [15:0] expected;
    initial begin
        repeat(4) @(negedge capture_clk); rst_n=1;

        start=1; @(negedge capture_clk); start=0; valid=1;
        repeat(27) @(negedge capture_clk); valid=0;
        for(b=0;b<4;b=b+1) begin
            @(negedge capture_clk); index=b; start=1;
            @(negedge capture_clk); start=0;
            for(iy=0;iy<480;iy=iy+1)
                for(ix=0;ix<640;ix=ix+1) begin
                    if(ix%37==0) begin
                        valid=0; @(negedge capture_clk);
                    end
                    valid=1; rgb=pattern(b,ix,479-iy);
                    @(negedge capture_clk);
                end
            valid=0;
            for(sy=0;sy<48;sy=sy+1)
                for(sx=0;sx<64;sx=sx+1) begin
                    expected=pack565(pattern(b,sx*10,sy*10));
                    if(dut.preview_ram[b*4096+sy*64+sx] !== expected)
                        $fatal(1,"cache bank%0d x%0d y%0d mismatch",b,sx,sy);
                end

            for(sx=1;sx<63;sx=sx+1) begin
                check_pixel((b%2)*320+64+sx*3,(b/2)*168+24+3,
                            expand565(pack565(pattern(b,sx*10,10))));
            end
            check_pixel((b%2)*320+64+186,(b/2)*168+24+140,
                        expand565(pack565(pattern(b,620,460))));
        end
        focus=2;
        check_pixel(64,192,24'hffcc20);
        ready=0;
        check_pixel(100,64,24'h203040);
        available=0;
        check_pixel(100,64,24'h181818);
        check_pixel(310,200,24'h101820);
        $display("PASS card thumbnails: four distinct caches, 192x144 aspect-preserving layout, native sample boundaries, row ends, vertical flip, stalls, restart, RGB565, synchronous read, focus and placeholders");
        $finish;
    end
    initial begin #30000000; $fatal(1,"cache test timeout"); end
endmodule
