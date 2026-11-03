`timescale 1ns/1ps

module image_hold_adjust #(

    parameter integer LONG_PRESS_CYCLES = 50_000_000,
    parameter integer REPEAT_CYCLES = 25_000_000,
    parameter integer STEP = 8'd32
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       enable,
    input  wire       key1_n,
    input  wire       key2_n,
    output reg  [7:0] brightness,
    output reg  [7:0] contrast
);
    reg [1:0] key1_sync, key2_sync;
    reg key1_seen, key2_seen;
    reg [26:0] key1_count, key2_count;
    reg key1_long, key2_long;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key1_sync <= 2'b11;
            key2_sync <= 2'b11;
            key1_seen <= 1'b1;
            key2_seen <= 1'b1;
            key1_count <= 26'd0;
            key2_count <= 26'd0;
            key1_long <= 1'b0;
            key2_long <= 1'b0;

            brightness <= 8'd220;
            contrast <= 8'd128;
        end else begin
            key1_sync <= {key1_sync[0], key1_n};
            key2_sync <= {key2_sync[0], key2_n};

            if (!enable) begin
                key1_count <= 0;
                key2_count <= 0;
                key1_seen <= 1'b0;
                key2_seen <= 1'b0;
                key1_long <= 1'b0;
                key2_long <= 1'b0;
            end else begin

            if (key1_sync[1] == 1'b0) begin
                key1_seen <= 1'b0;
                if (key1_count < LONG_PRESS_CYCLES + REPEAT_CYCLES - 1)
                    key1_count <= key1_count + 1'b1;
                if (key1_count >= LONG_PRESS_CYCLES - 1)
                    key1_long <= 1'b1;
                if ((!key1_long && key1_count >= LONG_PRESS_CYCLES - 1) ||
                    (key1_long && key1_count >= LONG_PRESS_CYCLES + REPEAT_CYCLES - 1)) begin
                    brightness <= (brightness >= 8'd252) ? 8'd156 : brightness + 8'd16;
                    key1_count <= LONG_PRESS_CYCLES - 1;
                end
            end else if (!key1_seen) begin
                key1_seen <= 1'b1;
                key1_count <= 26'd0;
                key1_long <= 1'b0;
            end

            if (key2_sync[1] == 1'b0) begin
                key2_seen <= 1'b0;
                if (key2_count < LONG_PRESS_CYCLES + REPEAT_CYCLES - 1)
                    key2_count <= key2_count + 1'b1;
                if (key2_count >= LONG_PRESS_CYCLES - 1)
                    key2_long <= 1'b1;
                if ((!key2_long && key2_count >= LONG_PRESS_CYCLES - 1) ||
                    (key2_long && key2_count >= LONG_PRESS_CYCLES + REPEAT_CYCLES - 1)) begin
                    contrast <= (contrast >= 8'd224) ? 8'd64 : contrast + STEP;
                    key2_count <= LONG_PRESS_CYCLES - 1;
                end
            end else if (!key2_seen) begin
                key2_seen <= 1'b1;
                key2_count <= 26'd0;
                key2_long <= 1'b0;
            end
            end
        end
    end
endmodule
