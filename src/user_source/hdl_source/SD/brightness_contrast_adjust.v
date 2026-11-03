`timescale 1ns/1ps

module brightness_contrast_adjust (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       in_de,
    input  wire [23:0] rgb_in,
    input  wire [7:0] brightness,
    input  wire [7:0] contrast,
    output reg        out_de,
    output reg  [23:0] rgb_out
);
    function [7:0] adjust_channel;
        input [7:0] pixel;
        integer p_i;
        integer b_i;
        integer c_i;
        integer value_i;
        begin
            p_i = pixel;
            b_i = brightness;
            c_i = contrast;
            value_i = (p_i * b_i) >>> 8;
            value_i = (((value_i - 128) * c_i) >>> 7) + 128;
            if (value_i < 0)
                adjust_channel = 8'd0;
            else if (value_i > 255)
                adjust_channel = 8'd255;
            else
                adjust_channel = value_i[7:0];
        end
    endfunction

    always @* begin
        out_de = in_de;
        rgb_out = {adjust_channel(rgb_in[23:16]),
                   adjust_channel(rgb_in[15:8]),
                   adjust_channel(rgb_in[7:0])};
    end
endmodule
