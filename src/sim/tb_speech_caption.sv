`timescale 1ns/1ps
module tb_speech_caption;
reg clk=0,rst_n=0,frame=0,commit=0,playing=0,preview=0,auto_mode=0,enabled=1;
always #20 clk=~clk;
reg [1:0] picture=0;
reg [31:0] samples=0;
wire [10:0] goal;
narration_caption_timeline timeline(.clk(clk),.rst_n(rst_n),.restart(commit||preview),
 .playing(playing),.picture(picture),.samples(samples),.scroll_target(goal));
exhibit_caption_overlay #(.SPEECH_SYNC(1),.SWITCHABLE_CAPTION(1),.READING_GUIDE(1)) overlay(
 .clk(clk),.rst_n(rst_n),.frame_start(frame),.commit(commit),.commit_index(picture),
 .display_valid(1'b1),.preview_mode(preview),.auto_mode(auto_mode),.caption_enabled(enabled),
 .artwork_ready(1'b1),.speech_playing(playing),.speech_samples(samples),
 .x(10'd16),.y(10'd448),.hs_in(1'b1),.vs_in(1'b1),.de_in(1'b1),.rgb_in(24'h8090a0),
 .hs_out(),.vs_out(),.de_out(),.rgb_out(),.caption_hit(),.reading_done_tgl(),.reading_done_index());
integer test_picture,test_sample,test_character,length,fd,rc,i,n=0,expected,previous=0,oldscroll;
reg [1023:0] oracle;
task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
task boundary;begin frame=1;tick();frame=0;tick();end endtask
initial begin
 if(!$value$plusargs("oracle=%s",oracle))$fatal(1,"missing independent speech oracle");
 fd=$fopen(oracle,"r");if(!fd)$fatal(1,"cannot read speech oracle");
 repeat(5)tick();rst_n=1;
 while(!$feof(fd))begin
  rc=$fscanf(fd,"%d %d %d %d\n",test_picture,test_sample,test_character,length);
  if(rc==4)begin
   if(picture!=test_picture || n==0)begin
    playing=0;picture=test_picture;repeat(70)tick();
    commit=1;boundary();commit=0;playing=1;samples=0;previous=0;repeat(70)tick();
   end
   samples=test_sample;repeat(70)tick();
   expected=test_character;
   if(goal+1<expected || goal>expected+1)
       $fatal(1,"interpolation mismatch pic%0d sample%0d got%0d expected%0d",picture,samples,goal,expected);
   if(goal<previous)$fatal(1,"continuous target moved backwards");
   oldscroll=overlay.scroll;boundary();
   if(overlay.scroll>oldscroll+4 || overlay.scroll+4<oldscroll)$fatal(1,"scroll jumps during playback");
   previous=expected;n=n+1;
  end
 end
 $fclose(fd);
 repeat(240)begin
  oldscroll=overlay.scroll;boundary();
  if(overlay.scroll>oldscroll+4 || overlay.scroll+4<oldscroll)$fatal(1,"scroll jumps");
 end
 if(overlay.scroll!=goal || !overlay.text_visible)$fatal(1,"speech scroll failed to settle");
 oldscroll=overlay.scroll;repeat(60)boundary();
 if(overlay.scroll!=oldscroll)$fatal(1,"buffer stall did not pause scroll");
 auto_mode=1;repeat(3)boundary();if(overlay.text_visible)$fatal(1,"auto showed text");
 auto_mode=0;preview=1;repeat(3)boundary();
 if(goal!=0)$fatal(1,"preview did not reset time cursor");
 preview=0;samples=0;playing=0;repeat(3)boundary();
 if(overlay.text_visible || goal!=0)$fatal(1,"ended audio retained text");
 playing=1;samples=100;repeat(70)tick();repeat(3)boundary();
 if(overlay.scroll!=0)$fatal(1,"audio restart did not reset scroll");
 enabled=0;repeat(3)boundary();if(overlay.text_visible)$fatal(1,"mute retained text");
 if(n<4000)$fatal(1,"incomplete continuous oracle");
 $display("PASS speech captions: %0d probes at frame cadence and every word boundary against independent rational CSV oracle, within one pixel, monotonic motion, stalls, auto hide, preview, stop/restart/mute",n);$finish;
end
initial begin #20000000;$fatal(1,"speech caption timeout");end
endmodule
