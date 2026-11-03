`timescale 1ns/1ps
module tb_exhibit_recovery;
    reg ctrl=0,pix=0,rst=0,request=0,frame=0,commit=0,failed=0;
    always #5 ctrl=~ctrl;
    always #7 pix=~pix;
    wire issued,busy,active,wipe;
    wire [7:0] alpha;
    integer requests=0;
    always @(posedge ctrl) if(issued && rst) requests=requests+1;
    video_fade_transition #(.FADE_FRAMES(4)) dut(
        .ctrl_clk(ctrl),.ctrl_rst_n(rst),.next_event_in(request),
        .next_event_out(issued),.fade_busy(busy),
        .pix_clk(pix),.pix_rst_n(rst),.player_active(1'b1),
        .frame_start(frame),.index_commit(commit),.load_failed(failed),
        .active_index(2'd0),.alpha_out(alpha),.fade_active(active),
        .wipe_active(wipe),.ramp_out(),.transition_kind());
    task tick; begin @(negedge pix);end endtask
    task boundary;
        begin frame=1;tick;frame=0;repeat(3)tick;end
    endtask
    task begin_switch;
        begin
            @(negedge ctrl);request=1;@(negedge ctrl);request=0;
            repeat(6)tick;
            repeat(5)boundary;
            if(alpha!==0 || !active) $fatal(1,"not waiting on black");
            repeat(8)tick;
        end
    endtask
    task restore;
        begin
            repeat(4)boundary;repeat(8)tick;
            if(alpha!==255 || active || busy || wipe) $fatal(1,"recovery stuck");
        end
    endtask
    initial begin
        repeat(3)tick;rst=1;repeat(4)tick;
                                                    
        failed=1;boundary;failed=0;
        if(active || alpha!==255) $fatal(1,"idle failure changed display");
        begin_switch;
                                                                                 
        repeat(8)boundary;
        if(alpha!==0 || requests!==1) $fatal(1,"retry escaped hold");
        failed=1;boundary;failed=0;
        restore;
        if(requests!==1) $fatal(1,"failure reissued switch");
        begin_switch;
        commit=1;boundary;commit=0;restore;
        if(requests!==2) $fatal(1,"next key did not recover");
        begin_switch;
        failed=1;commit=1;boundary;failed=0;commit=0;restore;
        $display("PASS recovery: async clocks, hold/retry, failure fade-in, no synthetic request, next request, success/failure collision");
        $finish;
    end
    initial begin #100000; $fatal(1,"timeout");end
endmodule
