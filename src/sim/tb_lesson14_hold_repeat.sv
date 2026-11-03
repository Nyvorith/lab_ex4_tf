`timescale 1ns/1ps
module tb_lesson14_hold_repeat;
    reg clk=0,rst_n=0,enable=1,k2=1,k4=1;
    always #5 clk=~clk;
    wire [7:0] brightness,contrast;
    image_hold_adjust #(.LONG_PRESS_CYCLES(10),.REPEAT_CYCLES(5)) dut (
        .clk(clk),.rst_n(rst_n),.enable(enable),.key1_n(k2),.key2_n(k4),
        .brightness(brightness),.contrast(contrast));
    integer changes=0;
    reg [7:0] previous=220;
    always @(negedge clk) if(brightness!==previous) begin
        changes=changes+1; previous=brightness;
    end
    initial begin
        repeat(4) @(negedge clk); rst_n=1;
        k2=0;
        repeat(37) @(negedge clk);
        if(changes<4) $fatal(1,"hold repetition stopped after %0d steps",changes);
        enable=0; k4=0;
        repeat(40) @(negedge clk);
        if(contrast!==128) $fatal(1,"preview changed contrast");
        k2=1;k4=1;
        repeat(5) @(negedge clk); enable=1;
        repeat(5) @(negedge clk);
        if(contrast!==128) $fatal(1,"mode exit adjusted released key");
        $display("PASS: sustained long-press repeats; preview disables adjustments");
        $finish;
    end
endmodule
