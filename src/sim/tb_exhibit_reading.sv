`timescale 1ns/1ps
module tb_exhibit_reading;
    reg clk=0,rst=0,frame=0,commit=0,preview=0,valid=1,de=1;
    reg auto_mode=1;
    always #5 clk=~clk;
    reg [1:0] picture=0;
    reg [9:0] x=16,y=474;
    wire done;
    wire [1:0] completed_picture;
    wire [23:0] rgb;
    exhibit_caption_overlay #(.READING_GUIDE(1)) dut(
        .clk(clk),.rst_n(rst),.frame_start(frame),.commit(commit),.commit_index(picture),
        .display_valid(valid),.preview_mode(preview),.x(x),.y(y),
        .auto_mode(auto_mode),
        .hs_in(1'b1),.vs_in(1'b1),.de_in(de),.rgb_in(24'h8090a0),
        .hs_out(),.vs_out(),.de_out(),.rgb_out(rgb),.caption_hit(),.reading_done_tgl(done),
        .reading_done_index(completed_picture));
    task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
    task boundary;begin frame=1;tick;frame=0;tick;end endtask
    task color_is(input [23:0] expected);
        begin repeat(3)tick;if(rgb!==expected)$fatal(1,"guide color %h expected %h",rgb,expected);end
    endtask
    integer p,n,manual_scroll;
    reg old_done;
    initial begin
        repeat(2)tick;rst=1;tick;
        for(p=0;p<4;p=p+1) begin
            picture=p;commit=1;boundary;commit=0;
            old_done=done;
            x=16;color_is(24'h384048);
                                                                                 
            repeat(100)boundary;
            preview=1;repeat(12)boundary;
            if(dut.auto_frames!==0 || done!==old_done) $fatal(1,"preview timer/event");
            color_is(24'h8090a0);preview=0;
            for(n=1;n<=119;n=n+1) begin
                boundary;
                if(dut.progress_pixels!==n*608/119) $fatal(1,"timed progress p%0d n%0d",p,n);
                if(n<119 && done!==old_done) $fatal(1,"early timed next picture");
                if(n==60) begin
                    x=16;color_is(24'h20d8c0);
                    x=623;color_is(24'h384048);
                end
            end
            if(done===old_done || dut.progress_pixels!==608) $fatal(1,"missing two-second completion");
            if(completed_picture!==p[1:0]) $fatal(1,"wrong completed picture identity");
            x=623;color_is(24'h20d8c0);
            x=624;color_is(24'h202428);
            y=473;color_is(24'h202428);
            y=474;de=0;color_is(24'h8090a0);de=1;x=16;
            old_done=done;repeat(2000)boundary;
            if(dut.progress_pixels!==608 || done!==old_done)
                $fatal(1,"timer repeated during loading or caption wrapped progress");
                                                                             
            auto_mode=0;boundary;color_is(24'h202428);
            manual_scroll=dut.scroll;old_done=done;
            repeat(3)boundary;
            if(dut.scroll!==manual_scroll+1 || done!==old_done || dut.progress_pixels!==0)
                $fatal(1,"manual caption/timer");
            auto_mode=1;boundary;
            x=16;color_is(24'h384048);
            repeat(118)boundary;
            if(done!==old_done)$fatal(1,"auto entry did not restart full dwell");
            boundary;
            if(done===old_done)$fatal(1,"auto entry missing expiry");
        end
                                                                   
        commit=1;picture=0;boundary;commit=0;old_done=done;
        repeat(118)boundary;
        commit=1;picture=1;boundary;commit=0;
        if(done!==old_done || dut.auto_frames!==0)$fatal(1,"commit/expiry race");
        repeat(119)boundary;
        if(done===old_done || completed_picture!==1)$fatal(1,"new image dwell identity");
                                                                                     
        valid=0;boundary;old_done=done;repeat(500)boundary;
        if(done!==old_done || dut.progress_pixels!==0)$fatal(1,"invalid display expiry");
        $display("PASS two-second autoplay: 119 frames, all pictures, exact timed progress, one-shot, preview reset, mode entry/cancel, commit race, invalid display, colors/DE");
        $finish;
    end
endmodule
