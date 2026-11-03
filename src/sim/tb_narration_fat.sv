`timescale 1ns/1ps
module tb_narration_fat;
reg clk=0,rd=0,rst=0,play=0,valid=0,done=0;always #5 clk=~clk;always #13 rd=~rd;
reg tick=0;always @(negedge rd)tick=~tick;
reg [7:0] data=0;reg [8:0] idx=0;wire req,ended;wire [31:0] lba,count;wire signed [15:0] sample;wire sample_valid;
integer requests=0,heard=0,k;reg [31:0] sector;
wav_stream_player #(.FAT_ENABLE(1),.ADDR_WIDTH(10)) dut(.wr_clk(clk),.wr_rst_n(rst),.play_enable(play),
.start_lba(32'd108),.total_sectors(32'd2),.first_cluster(32'd10),.file_size(32'd514),
.sectors_per_cluster(8'd1),.fat_start_lba(32'd50),.data_start_lba(32'd100),.max_cluster(32'd100),
.sd_req(req),.sd_lba(lba),.sd_busy(1'b0),.sd_valid(valid),.sd_byte(data),.sd_byte_index(idx),.sd_done(done),.sd_error(8'd0),
.rd_clk(rd),.rd_rst_n(rst),.sample_tick(tick),.sample_out(sample),.sample_valid(sample_valid),.sample_ready(1'b1),.sample_counter(count),.stream_end(ended));
always @(negedge rd)if(sample_valid && sample!=0)begin
if(sample !== (heard<256 ? 16'h1234 : 16'h5678))$fatal(1,"fragment/padding sample%0d got%h",heard,sample);
heard=heard+1;
end
initial begin #30;rst=1;#50;play=1;wait(ended);#100;
if(heard!=257 || count!=257 || requests!=3)$fatal(1,"exact length/FAT counts %0d %0d %0d",heard,count,requests);
$display("PASS narration FAT: cluster10 -> cluster30, FAT LBA, exact514 bytes, final sector padding excluded");$finish;end
initial forever begin
wait(req);wait(!req);@(negedge clk);sector=lba;requests=requests+1;
if((requests==1 && sector!=108)||(requests==2 && sector!=50)||(requests==3 && sector!=128))$fatal(1,"fragment LBA%0d",sector);
for(k=0;k<512;k=k+1)begin
idx=k;valid=1;
if(sector==50)data=(k==40)?30:0;
else if(sector==108)data=k%2?8'h12:8'h34;
else data=k%2?8'h56:8'h78;
@(negedge clk);
end
valid=0;done=1;@(negedge clk);done=0;
end
initial begin #100000;$fatal(1,"timeout state%0d req%0d heard%0d count%0d level%0d",dut.wstate,requests,heard,count,dut.level_rd);end
endmodule
