`timescale 1ns/1ps
module waveform_compare #(parameter D=12)(output reg done=0);
reg clk=0,rst=0,vs=1,de=0,en=1,valid=0;
always #5 clk=~clk;
reg [9:0] x=0;
reg signed [15:0] pcm=0;
reg [23:0] background=24'h123456;
wire [23:0] a,b;
wire hit_a,hit_b;
                                                                             
promax_audio_waveform #(.WAVE_X(8),.WAVE_Y(4),.WAVE_WIDTH(64),.WAVE_HEIGHT(64),.DECIMATE(D))
 candidate(clk,rst,vs,de,background,x,en,valid,pcm,a,hit_a);
audio_waveform_reference_4k #(.WAVE_X(8),.WAVE_Y(4),.WAVE_WIDTH(64),.WAVE_HEIGHT(64),.DECIMATE(D))
 baseline(clk,rst,vs,de,background,x,en,valid,pcm,b,hit_b);
reg [31:0] rng=32'hf789135a;
integer f,row,col,i;
always @(posedge clk)begin
 #1;
 if(rst && {a,hit_a}!=={b,hit_b})
   $fatal(1,"waveform D%0d f%0d row%0d x%0d mismatch %h/%h",D,f,row,x,a,b);
end
task random_audio;begin
 rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};
 pcm=rng[15:0];valid=rng[19];
end endtask
task boundary;begin
 @(negedge clk);vs=0;de=0;random_audio();
 @(negedge clk);vs=1;
end endtask
initial begin
 repeat(4)@(negedge clk);rst=1;
 for(f=0;f<12;f=f+1)begin
   boundary();
                                                                              
   for(i=0;i<(f%3==0 ? D*8 : D*96);i=i+1)begin
     @(negedge clk);random_audio();
     if(f==1)begin valid=1;pcm=-16'sd256;end
     if(f==2)begin valid=1;pcm=16'h8000;end
     if(f==3)begin valid=1;pcm=16'h7fff;end
     if(f==4)begin valid=1;pcm=0;end
   end
   boundary();
   for(row=0;row<70;row=row+1)begin
     for(col=0;col<92;col=col+1)begin
       @(negedge clk);de=1;x=col;
       random_audio();background=rng[23:0];en=(col%7!=0);
     end
     @(negedge clk);de=0;en=1;random_audio();
   end
 end
 rst=0;@(negedge clk);rst=1;boundary();
 done=1;
end
endmodule
                                                                     
                                                                          
module waveform_large_decimation(output reg done=0);
reg clk=0,rst=0,vs=1,valid=0;
always #5 clk=~clk;
wire [23:0] rgb;
wire active;
promax_audio_waveform #(.DECIMATE(300)) dut(
 .clk(clk),.rst_n(rst),.vsync(vs),.de(1'b0),.rgb_in(24'd0),
 .pixel_x(10'd0),.enable(1'b1),.pcm_tap_valid(valid),
 .pcm_tap_left(16'sh4000),.rgb_out(rgb),.waveform_active(active));
integer n,expected;
reg [8:0] saved_skip;
initial begin
 repeat(4)@(negedge clk);rst=1;
 for(n=0;n<9600;n=n+1)begin
   @(negedge clk);valid=1;
   @(posedge clk);#1;
   expected=n/300+1;
   if(dut.capture_count!==expected)
     $fatal(1,"DECIMATE300 valid sample %0d count %0d expected %0d",n,dut.capture_count,expected);
   if(n%17==0)begin
     @(negedge clk);valid=0;saved_skip=dut.skip_samples;
     repeat(3)begin
       @(posedge clk);#1;
       if(dut.skip_samples!==saved_skip || dut.capture_count!==expected)
         $fatal(1,"Invalid audio must not advance decimation");
     end
   end
 end
 @(negedge clk);valid=0;vs=0;
 @(posedge clk);#1;
 if(!dut.display_valid || dut.display_peak!==8'd64 || dut.capture_count!==0)
   $fatal(1,"DECIMATE300 complete frame publication failed");
 done=1;
end
endmodule
module tb_waveform_refactor;
wire a,b,c;
waveform_compare #(1) one(a);
waveform_compare #(12) twelve(b);
waveform_large_decimation threehundred(c);
initial begin wait(a&&b&&c);$display("PASS waveform refactor: old-reference pixel equivalence for DECIMATE 1/12; full/partial frames, signed extremes/remainders, stalls, blanking and enable; DECIMATE300 interval and publication");$finish;end
initial begin #10000000;$fatal(1,"waveform comparison timeout");end
endmodule
