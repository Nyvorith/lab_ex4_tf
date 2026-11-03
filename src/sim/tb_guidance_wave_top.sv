`timescale 1ns/1ps
module tb_guidance_wave_top;
reg clk=0,rst_n=0;always #10 clk=~clk;
top dut(.clk(clk),.rst_n(rst_n),.key2(1'b1),.key3(1'b1),.key4(1'b1),.sd_miso(1'b1));
reg playing=0,enabled=0,active=0,valid=1,fading=0,commit=0,auto_mode=0,preview=0;
reg sample_valid=0,vs=1;
reg signed [15:0] sample_data=0;
reg [11:0] px=0,py=0;
integer i,x,y,kind,checks=0,col,current_y,previous_y,peak,old_y;
reg [23:0] expected;
reg expected_hit;
function integer value;
 input integer point,mode;
 begin
 case(mode)
 0:value=(point%8-4)*16;
 1:value=(point%2)==0 ? 127 : -128;
 2:value=point%7-3;
 3:value=0;
 default:value=point<16 ? 24 : -24;
 endcase
 end
endfunction
function integer height;
 input integer v,p;
 integer h;
 begin
 h=p<2 ? 0 : p<8 ? v : p<16 ? v/2 : p<32 ? v/4 : p<64 ? v/8 : v/16;
 height=h>4 ? 4 : h< -4 ? -4 : h;
 end
endfunction
task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
task frame;begin vs=0;repeat(3)tick;vs=1;repeat(3)tick;end endtask
task capture;
 input integer mode;
 integer n;
 begin
 for(n=0;n<384;n=n+1)begin
  sample_data=(n%12)==0 ? value(n/12,mode)*256 : 16'h7f00;
  sample_valid=1;tick;sample_valid=0;tick;
 end
 end
endtask
task hidden;begin
 tick;
 if(dut.guide_wave_visible!==0 || dut.u_audio_waveform.waveform_active!==0 ||
    dut.waveform_rgb_out!==24'h183048)$fatal(1,"waveform should be hidden");
end endtask
task raster;
 input integer mode;
 begin
 peak=0;
 for(i=0;i<32;i=i+1)if((value(i,mode)<0 ? -value(i,mode) : value(i,mode))>peak)
  peak=value(i,mode)<0 ? -value(i,mode) : value(i,mode);
 for(y=430;y<466;y=y+1)for(x=490;x<630;x=x+1)begin
  px=x;py=y;#1;expected_hit=0;
  if(x>=528 && x<624 && y>=434 && y<446)begin
   col=(x-528)/3;
   current_y=440-height(value(col,mode),peak);
   previous_y=col==0 ? current_y : 440-height(value(col-1,mode),peak);
   expected_hit=y==((x-528)%3==0 ? previous_y : (x-528)%3==1 ? (current_y+previous_y)/2 : current_y);
  end
  expected=expected_hit ? 24'h373837 : 24'h183048;
  if(dut.waveform_rgb_out!==expected || dut.u_audio_waveform.waveform_active!==expected_hit)
   $fatal(1,"PCM time-wave raster %0d,%0d mode%0d actual%h expected%h",x,y,mode,dut.waveform_rgb_out,expected);
  checks=checks+1;
 end
 end
endtask
initial begin
 force dut.por_done=1;
 force dut.raw_de=1;force dut.raw_vs=vs;force dut.osd_pixel_x=px;
 force dut.osd_rgb_out=24'h183048;
 force dut.u_audio_waveform.scanline=py;
 force dut.speech_playing_pix=playing;force dut.caption_enable_v2=enabled;
 force dut.wav_active_v=active;force dut.dv_v2=valid;force dut.fade_active=fading;
 force dut.index_commit_pix=commit;force dut.osd_auto_v2=auto_mode;force dut.preview_mode_q=preview;
 force dut.wav_sample_valid=sample_valid;force dut.wav_mono_16=sample_data;
 repeat(20)tick;rst_n=1;repeat(20)tick;
 px=500;py=440;hidden;
 if(dut.narration_enabled!==0)$fatal(1,"default mute changed");
 playing=1;enabled=1;active=1;tick;
 if(!dut.guide_wave_visible)$fatal(1,"runtime narration did not enable wave");
 for(kind=0;kind<5;kind=kind+1)begin
  enabled=0;hidden;enabled=1;tick;
  for(i=0;i<384;i=i+1)begin
   sample_data=(i%12)==0 ? value(i/12,kind)*256 : 16'h7f00;
   sample_valid=1;tick;sample_valid=0;tick;
  end
  if(dut.u_audio_waveform.display_valid!==0)$fatal(1,"capture published before frame boundary");
  frame;
  raster(kind);
  force dut.display_y=py;force dut.final_raw_de=1;
  force dut.g_exhibit_caption.u_caption.valid=1;
  force dut.g_exhibit_caption.u_caption.text_visible=1;
  px=529;py=440-height(value(0,kind),peak);repeat(5)tick;
  if(dut.vout_data!==24'h373837 || dut.de!==1)$fatal(1,"wave missing after subtitle pipeline");
  px=527;py=440;repeat(5)tick;
  if(dut.vout_data!==24'h060c12)$fatal(1,"subtitle background altered");
  px=529;py=440-height(value(0,kind),peak);repeat(5)tick;
  force dut.osd_rgb_out=24'hffffff;repeat(5)tick;
  if(dut.vout_data!==24'h53514d)$fatal(1,"wave brightness cap on white");
  force dut.osd_rgb_out=24'h000000;repeat(5)tick;
  if(dut.vout_data!==24'h34322e)$fatal(1,"wave blend on black");
  force dut.osd_rgb_out=24'h183048;repeat(5)tick;
  old_y=py;
  sample_data=16'h0000;
  for(i=0;i<192;i=i+1)begin sample_valid=1;tick;sample_valid=0;tick;end
  if(dut.waveform_rgb_out!==24'h373837)$fatal(1,"partial bank changed published snapshot");
  frame;
  if(dut.u_audio_waveform.display_valid!==0 || dut.u_audio_waveform.waveform_active!==0)
   $fatal(1,"incomplete capture left stale waveform");
 end
 enabled=0;hidden;enabled=1;tick;
 capture(1);frame;raster(1);
 for(kind=0;kind<3;kind=kind+1)begin
  capture(3);frame;
  if(!dut.u_audio_waveform.display_valid)$fatal(1,"held snapshot lost validity");
  raster(3);
 end
 capture(3);frame;raster(3);
 frame;
 if(dut.u_audio_waveform.display_valid!==0)$fatal(1,"missing samples during held interval left stale wave");
 capture(2);frame;raster(2);
 preview=1;hidden;preview=0;
 auto_mode=1;hidden;auto_mode=0;
 fading=1;hidden;fading=0;
 commit=1;hidden;commit=0;
 valid=0;hidden;valid=1;
 playing=0;hidden;playing=1;
 enabled=0;hidden;enabled=1;
 active=0;hidden;active=1;tick;
 if(dut.u_audio_waveform.display_valid!==0)$fatal(1,"stale waveform on re-enable");
 $display("PASS PCM waveform: %0d pixel reference checks, per-frame publication, stable within-frame snapshots, immediate missing-sample invalidation and recovery, signed PCM, decimation, extremes, silence, single-pixel interpolated trace, low-brightness blend, subtitle/HDMI alignment, visibility gates",checks);
 $finish;
end
initial begin #10000000;$fatal(1,"timeout");end
endmodule
