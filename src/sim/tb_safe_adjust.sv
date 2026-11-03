`timescale 1ns/1ps
module tb_safe_adjust;
reg clk=0,rst_n=0,k2=1,k4=1;
always #5 clk=~clk;
wire [7:0] b,c;
image_hold_adjust #(.LONG_PRESS_CYCLES(10),.REPEAT_CYCLES(5)) dut(
 .clk(clk),.rst_n(rst_n),.enable(1'b1),.key1_n(k2),.key2_n(k4),.brightness(b),.contrast(c));
integer bsteps=0,csteps=0;
reg [7:0] last_b=220,last_c=128;
reg saw_default_b=0,saw_default_c=0;
always @(negedge clk)if(rst_n)begin
 if(b<156 || b>252 || c<64 || c>224)$fatal(1,"unsafe exhibition adjustment");
 if(b!=last_b)begin bsteps=bsteps+1;if(b==220)saw_default_b=1;end
 if(c!=last_c)begin csteps=csteps+1;if(c==128)saw_default_c=1;end
 last_b=b;last_c=c;
end
initial begin
 repeat(4)@(negedge clk);rst_n=1;k2=0;k4=0;
 repeat(180)@(negedge clk);
 if(bsteps<20 || csteps<20 || !saw_default_b || !saw_default_c)$fatal(1,"safe cycle lost default");
 k2=1;k4=1;repeat(5)@(negedge clk);
 rst_n=0;repeat(3)@(negedge clk);
 if(b!=220 || c!=128)$fatal(1,"reset defaults");
 $display("PASS safe adjustment: sustained hold stays bounded and cycles through defaults");$finish;
end
endmodule
