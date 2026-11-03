`timescale 1ns/1ps
module status_compare #(parameter MODE=0, X=8, Y=8)(output reg done=0);
reg clk=0,rst=0,frame=0;
always #5 clk=~clk;
reg [1:0] index=0;
reg auto_en=0,loading=0,ready=0,preview=0,de=0;
reg [7:0] error=0;
reg [2:0] audio=0;
reg [11:0] x=0,y=0,bg=0;
wire [11:0] a,b;
wire da,db,ha,hb;
status_osd_overlay #(.EXHIBITION_UI(MODE),.OSD_X(X),.OSD_Y(Y)) candidate(
 clk,rst,frame,index,auto_en,error,audio,loading,ready,preview,de,bg,x,y,a,da,ha);
status_osd_reference_4m #(.EXHIBITION_UI(MODE),.OSD_X(X),.OSD_Y(Y)) baseline(
 clk,rst,frame,index,auto_en,error,audio,loading,ready,preview,de,bg,x,y,b,db,hb);
integer n,xx,yy,value,row;
reg [31:0] rng=32'h517e891b;
task compare;begin
 #1;if({a,da,ha}!=={b,db,hb})
 $fatal(1,"OSD mode%0d x%0d y%0d mismatch %h/%h",MODE,x,y,a,b);
end endtask
initial begin
 repeat(3)@(negedge clk);rst=1;
 for(value=0;value<16;value=value+1)
   for(row=0;row<8;row=row+1)
     if(candidate.font_row(value,row)!==baseline.font_row(value,row))
       $fatal(1,"font mismatch value%0d row%0d",value,row);
                                                                       
                                                                           
 for(n=0;n<512;n=n+1)begin
   @(negedge clk);
   index=n%4;auto_en=n%2;error=n;audio=(n/2)%8;
   loading=n[0];ready=n[1];preview=n[2];frame=1;
   @(negedge clk);frame=0;
   index=~index;error=~error;auto_en=~auto_en;
   for(yy=0;yy<10;yy=yy+1)begin
     y=Y+yy;
     for(xx=0;xx<138;xx=xx+1)begin
       x=X+xx;
       rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};
       bg=rng[11:0];de=rng[16];compare();
     end
   end
   x=0;y=0;de=1;compare();
   x=4095;y=4095;compare();
 end
 rst=0;@(negedge clk);compare();done=1;
end
endmodule
module tb_status_osd_refactor;
wire a,b,c,d;
status_compare #(0) legacy(a);
status_compare #(1) status(b);
status_compare #(2) number(c);
status_compare #(3,21,33) offset_status(d);
initial begin wait(a&&b&&c&&d);$display("PASS OSD refactor: four modes, packed digit rows, 512 status combinations, full glyph raster, frame latch, blanking, colors, offsets and reset");$finish;end
initial begin #5000000;$fatal(1,"OSD comparison timeout");end
endmodule
