`timescale 1ns/1ps
module tb_resident_keys;
reg sd=0,ctrl=0,rst=1,key=1;
always #5 sd=~sd;
always #10 ctrl=~ctrl;
wire short_event;
wire [7:0] b,c;
integer shorts=0,adjustments=0;
reg [7:0] last_b=220;
key_press_debounce #(.CLK_FREQ_HZ(1000),.DEBOUNCE_MS(50),.LONG_PRESS_MS(850)) debounce(
 .clk(sd),.rst(rst),.button_in(key),.press_pulse(short_event),.long_press_pulse(),.button_stable_out());
image_hold_adjust #(.LONG_PRESS_CYCLES(500),.REPEAT_CYCLES(250)) adjust(
 .clk(ctrl),.rst_n(!rst),.enable(1'b1),.key1_n(key),.key2_n(1'b1),.brightness(b),.contrast(c));
always @(negedge sd)if(short_event)shorts=shorts+1;
always @(negedge ctrl)if(!rst)begin if(b!=last_b)adjustments=adjustments+1;last_b=b;end
task cycles(input integer n);repeat(n)@(negedge sd);endtask
task hold_key(input integer n);begin key=0;cycles(n);key=1;cycles(150);end endtask
initial begin
 cycles(10);rst=0;cycles(20);
 hold_key(500);
 if(shorts!=1 || adjustments!=0)$fatal(1,"short key did not act exactly once");
 hold_key(1010);
 if(shorts!=1 || adjustments!=1)$fatal(1,"near-threshold hold adjusted and short-triggered");
 hold_key(1650);
 if(shorts!=1 || adjustments<3)$fatal(1,"sustained hold double-triggered");
 $display("PASS resident keys: distinct 1000/500Hz control clocks, short release, near-threshold and repeating long holds without short action");$finish;
end
endmodule
