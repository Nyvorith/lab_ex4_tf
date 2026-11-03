`timescale 1ns/1ps
module transition_compare #(parameter N=16)(output reg done=0);
reg ctrl=0,pix=0,reset=0,request=0,frame=0,commit=0,failed=0,playing=1;
always #5 ctrl=~ctrl;
always #13 pix=~pix;
reg [1:0] picture=0;
wire req_a,busy_a,active_a,wipe_a,req_b,busy_b,active_b,wipe_b;
wire [7:0] alpha_a,alpha_b;
wire [4:0] ramp_a,ramp_b;
wire [1:0] kind_a,kind_b;
video_fade_transition #(.FADE_FRAMES(N)) candidate(ctrl,reset,request,req_a,busy_a,
 pix,reset,playing,frame,commit,failed,1'b0,picture,alpha_a,active_a,wipe_a,ramp_a,kind_a);
video_fade_reference_4k #(.FADE_FRAMES(N)) baseline(ctrl,reset,request,req_b,busy_b,
 pix,reset,playing,frame,commit,failed,picture,alpha_b,active_b,wipe_b,ramp_b,kind_b);
reg compare=1;
integer released=0,i;
always @(posedge ctrl) begin
 #1;
 if(reset && req_a)released=released+1;
 if(reset && compare && {req_a,busy_a} !== {req_b,busy_b})
   $fatal(1,"N%0d control mismatch",N);
end
always @(posedge pix)begin
 #1;
 if(reset && compare && {alpha_a,active_a,wipe_a,kind_a} !== {alpha_b,active_b,wipe_b,kind_b})
   $fatal(1,"N%0d display mismatch",N);
 if(reset && compare && active_a && ramp_a!==ramp_b)
   $fatal(1,"N%0d active ramp mismatch",N);
end
task boundary;begin
 @(negedge pix);frame=1;@(negedge pix);frame=0;repeat(3)@(negedge pix);
end endtask
task press;begin @(negedge ctrl);request=1;@(negedge ctrl);request=0;end endtask
task recover(input bit error);begin
 @(negedge pix);commit=!error;failed=error;
 @(negedge pix);commit=0;failed=0;
 repeat(N+2)boundary();
end endtask
initial begin
 repeat(4)@(negedge pix);reset=1;repeat(8)@(negedge pix);
 if(N==0)begin
   press();playing=0;recover(0);done=1;
 end else begin
                                                                                
   for(i=0;i<4;i=i+1)begin picture=i;recover(0);end
   press();repeat(8)@(negedge pix);repeat(N+1)boundary();
   repeat(8)@(negedge ctrl);if(released!=1)$fatal(1,"missing black request");
   recover(0);
   press();repeat(8)@(negedge pix);repeat(N+1)boundary();recover(1);
   if(released!=2)$fatal(1,"failure path request count");
   playing=0;press();repeat(12)@(negedge pix);
   if(active_a || alpha_a!=255)$fatal(1,"inactive player faded");
   playing=1;
                                                                           
                                                                       
   compare=0;
   @(negedge pix);press();press();
   repeat(12)@(negedge pix);
   if(!active_a)$fatal(1,"CDC admission lost rapid requests");
   repeat(N+1)boundary();repeat(8)@(negedge ctrl);
   if(released!=3)$fatal(1,"rapid request not exactly once");
   recover(0);
   if(active_a || busy_a)$fatal(1,"transition stuck");
   reset=0;repeat(5)@(negedge pix);
   if(req_a || active_a || busy_a || alpha_a!=255)$fatal(1,"reset contract");
   done=1;
 end
end
endmodule
module tb_transition_refactor;
wire a,b,c,d;
transition_compare #(0) bypass(a);
transition_compare #(1) one(b);
transition_compare #(4) four(c);
transition_compare #(16) sixteen(d);
initial begin wait(a&&b&&c&&d);$display("PASS refactored transition: frozen-reference outputs at 0/1/4/16 frames, auto identities, manual success/failure, inactive player, CDC rapid pulses, reset");$finish;end
initial begin #1000000;$fatal(1,"transition test timeout");end
endmodule
