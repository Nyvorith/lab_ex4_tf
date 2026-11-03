`timescale 1ns/1ps
module tb_narration_top;
reg clk=0,rst=0,key3=1; always #10 clk=~clk;
top dut(.clk(clk),.rst_n(rst),.key2(1'b1),.key3(key3),.key4(1'b1),.sd_miso(1'b1));
defparam dut.sd_card_bmp_m0.u_key_mode.CLK_FREQ_HZ=1000;
reg [1:0] image=0; reg commit=0,frame=0,preview=0,auto_mode=0;
reg audio_tick=0;always @(negedge clk) audio_tick=~audio_tick;
reg valid=0,done=0,busy=0; reg [7:0] data=0; reg [8:0] idx=0;
reg [31:0] sector; integer b,requests=0,shorts=0,toggles=0,heard=0; reg reading=0;
reg [3:0] available=4'b1011;
always @(posedge clk) begin
if(dut.sd_card_bmp_m0.key_mode_press)shorts=shorts+1;
if(dut.narration_toggle)toggles=toggles+1;
end
task cycles(input integer n);repeat(n)@(negedge clk);endtask
task show(input [1:0] i);
begin image=i;commit=~commit;cycles(8);frame=1;cycles(1);frame=0;cycles(12);end endtask
task long_key;
begin key3=0;cycles(1150);key3=1;cycles(100);end endtask
initial begin
force dut.por_done=1;
force dut.sample_tick=audio_tick;
force dut.narration_valid=available;
force dut.narration_clusters={32'd40,32'd30,32'd20,32'd10};
force dut.narration_sizes={32'd512,32'd512,32'd512,32'd1024};
force dut.audio_data_start_lba=32'd100;force dut.audio_fat_start_lba=32'd50;
force dut.audio_max_cluster=32'd100;force dut.audio_sectors_per_cluster=8'd1;
force dut.exhibit_pending_index=image;force dut.index_commit_pix=frame;
force dut.preview_mode_sd=preview;
force dut.auto_play_en_sd=auto_mode;
force dut.wav_sd_valid=valid;force dut.wav_sd_done=done;force dut.wav_sd_busy=busy;
force dut.wav_sd_byte=data;force dut.wav_sd_byte_index=idx;force dut.wav_sd_error=8'd0;
force dut.reading_event_sd=reading;
cycles(20);rst=1;cycles(30);show(0);cycles(1500);
if(dut.wav_play_en || requests)$fatal(1,"default started audio");
auto_mode=1;cycles(1200);auto_mode=0;cycles(1500);
if(dut.narration_enabled || dut.wav_play_en || requests)$fatal(1,"auto exit enabled previously muted narration");
                                                                            
key3=0;cycles(150);key3=1;cycles(100);
if(shorts!=1 || toggles!=0)$fatal(1,"short key behavior");
long_key();wait(busy);cycles(100);
                                                                               
show(1);cycles(50);
if(dut.wav_play_en)$fatal(1,"switch failed to stop");
wait(dut.wav_play_en);cycles(20);
if(dut.narration_selected!=1 || dut.narration_cluster!=20)$fatal(1,"wrong selected track");
wait(dut.narration_finished);cycles(20);
if(shorts!=1 || toggles!=1)$fatal(1,"long leaked short press");
                                                                               
image=3;cycles(30);
if(dut.narration_selected!=1)$fatal(1,"uncommitted/failed image switched narration");
image=1;
                                               
b=requests;cycles(3000);if(requests!=b)$fatal(1,"unexpected replay");
show(2);cycles(1800);if(dut.wav_play_en)$fatal(1,"missing track started old audio");
show(3);wait(dut.wav_play_en);
cycles(1);reading=1;cycles(2);
if(!dut.sd_card_bmp_m0.auto_advance_event || dut.narration_finished)
    $fatal(1,"four-second event was held waiting for narration");
reading=0;cycles(2);
                                                                                
show(0);cycles(50);
if(dut.wav_play_en)$fatal(1,"auto display commit failed to stop old narration");
wait(dut.wav_play_en);
if(dut.narration_selected!=0)$fatal(1,"auto did not select new narration");
auto_mode=1;cycles(12);
if(dut.wav_play_en || dut.wav_active_v || !dut.narration_enabled)$fatal(1,"auto did not suspend voice or lost preference");
wait(!busy);cycles(1500);b=requests;
show(1);cycles(1600);show(3);cycles(1600);
if(requests!=b || dut.wav_play_en || dut.audio_left_16!==0 || dut.audio_right_16!==0)
    $fatal(1,"automatic overview fetched or played fragmented narration");
auto_mode=0;wait(dut.wav_play_en);cycles(20);
if(dut.narration_selected!=3 || dut.narration_cluster!=40 || dut.wav_samples_consumed!=0)
    $fatal(1,"manual return failed to restart current track from beginning");
wait(dut.wav_samples_consumed!=0);
auto_mode=1;cycles(20);long_key();cycles(1200);
if(dut.narration_enabled || dut.wav_play_en)$fatal(1,"mute preference not retained during auto");
auto_mode=0;cycles(1500);
if(dut.wav_play_en)$fatal(1,"manual return ignored muted preference");
long_key();wait(dut.wav_play_en);
                                                                        
preview=1;cycles(100);if(dut.wav_play_en)$fatal(1,"preview playing");
preview=0;wait(dut.wav_play_en);long_key();cycles(1500);
if(dut.narration_enabled || dut.wav_play_en || shorts!=1 || toggles!=4)$fatal(1,"mute/long release");
if(heard==0)$fatal(1,"no decoded audio samples");
$display("PASS narration top: default mute, short/long isolation, in-flight switch, correct track, missing file, once, auto bypasses audio wait, auto quiet overview, no new PCM reads, manual current-track restart, mute preference, preview, mute");$finish;
end
                                                                  
initial forever begin
wait(dut.wav_sd_req);wait(!dut.wav_sd_req);@(negedge clk);
sector=dut.wav_sd_lba;requests=requests+1;busy=1;cycles(200);
for(integer k=0;k<512;k=k+1)begin
idx=k;valid=1;
if(sector==50) data=(k==40)?11:0;                                                       
else data=(k%2==0)?sector[7:0]:8'h12;
cycles(1);
end
valid=0;done=1;cycles(1);done=0;busy=0;
end
always @(negedge clk) if(dut.wav_sample_valid && dut.wav_mono_16!=0) begin
heard=heard+1;
if(dut.narration_selected==1 && dut.wav_mono_16!==16'h1276)$fatal(1,"old samples leaked into track2: %h",dut.wav_mono_16);
end
initial begin #2000000;$fatal(1,"timeout state%0d selected%0d player%0d req%0d",dut.narration_state,dut.narration_selected,dut.u_wav_stream_player.wstate,requests);end
endmodule
