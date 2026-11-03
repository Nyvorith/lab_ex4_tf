`timescale 1ns/1ps
module tb_narration_catalog;
reg clk=0,rst=0,start=0,valid=0,done=0;
always #5 clk=~clk;
reg [7:0] byte_data=0;
reg [8:0] idx=0;
wire req,finished; wire [31:0] lba;
wire [3:0] tracks,images; wire [127:0] clusters,sizes;
wire [7:0] error;
reg [7:0] boot[0:511]; reg [7:0] root[0:1023];
integer n,base,pass;
fat32_volume_scanner dut(.clk(clk),.rst_n(rst),.scan_start(start),.scan_done(finished),
.fs_error(error),.resource_valid(images),.narration_valid(tracks),.narration_clusters(clusters),
.narration_sizes(sizes),.sector_req(req),.sector_lba(lba),.sector_busy(1'b0),
.sector_valid(valid),.sector_byte(byte_data),.sector_byte_index(idx),.sector_done(done),.sector_error(8'd0));
task entry(input integer slot,input [87:0] name,input integer cluster,input integer bytes,input [7:0] attr);
integer i;
begin
base=slot*32;
for(i=0;i<11;i=i+1)root[base+i]=name[(10-i)*8+:8];
root[base+11]=attr;root[base+26]=cluster;root[base+27]=cluster>>8;
for(i=0;i<4;i=i+1)root[base+28+i]=bytes>>(8*i);
end endtask
initial begin
                                                                
for(n=0;n<256;n=n+1)
    if(dut.valid_spc(n[7:0]) !== (n!=0 && ((n & (n-1))==0)))
        $fatal(1,"SPC validity mismatch for %0d",n);
for(n=0;n<512;n=n+1)boot[n]=0;
for(n=0;n<1024;n=n+1)root[n]=0;
boot[0]=8'heb;boot[11]=0;boot[12]=2;boot[13]=2;boot[14]=32;
boot[16]=1;boot[33]=8'h10;boot[36]=1;boot[44]=2;boot[510]=8'h55;boot[511]=8'haa;
entry(0,"AUDIO4  PCM",44,1026,8'h21);                              
entry(1,"PIC1    BMP",10,900000,8'h21);
entry(5,"PIC2    BMP",20,900000,8'h00);
entry(6,"PIC3    BMP",30,900000,8'h10);
entry(7,"PIC4    BMP",40,900000,8'h08);
entry(2,"AUDIO1  PCM",11,514,8'h20);
entry(3,"AUDIO2  PCM",22,0,8'h20);                        
entry(4,"AUDIO3  PCM",33,1024,8'h10);                            
entry(17,"AUDIO3  PCM",33,1536,8'h20);                      
entry(18,"AUDIO   PCM",55,2048,8'h20);                              
#30;rst=1;#20;start=1;#10;start=0;
wait(finished);#1;
if(error!=0 || tracks!==4'b1101 || images!==4'b0011)$fatal(1,"catalog flags %h/%h err%h",tracks,images,error);
if(clusters[31:0]!=11 || clusters[95:64]!=33 || clusters[127:96]!=44 || sizes[31:0]!=514)$fatal(1,"catalog identity/size");
if(dut.audio_first_cluster!=55)$fatal(1,"legacy metadata lost");
                                                           
for(n=0;n<1024;n=n+1)root[n]=0;
entry(0,"PIC1    BMP",10,900000,8'h20);
#30;start=1;#10;start=0;wait(finished);#1;
if(tracks!==0 || images!==1)$fatal(1,"stale tracks survived rescan");
$display("PASS narration catalog: BMP read-only/no-archive accepted, directory/volume excluded, shuffled names, root second sector, missing/empty/directory, legacy independence, rescan");$finish;
end
initial forever begin
wait(req);@(negedge clk);
for(n=0;n<512;n=n+1)begin
idx=n;valid=1;
if(lba==0)byte_data=boot[n];else if(lba==33)byte_data=root[n];else if(lba==34)byte_data=root[n+512];else $fatal(1,"unexpected LBA%0d",lba);
@(negedge clk);
end
valid=0;done=1;@(negedge clk);done=0;
end
initial begin #100000;$fatal(1,"timeout");end
endmodule
