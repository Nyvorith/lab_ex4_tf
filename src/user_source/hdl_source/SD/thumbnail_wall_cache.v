`timescale 1ns/1ps

module thumbnail_wall_cache #(parameter integer INTRO_CARD=0) (
    input wire capture_clk,
    input wire capture_rst_n,
    input wire capture_start,
    input wire [1:0] capture_index,
    input wire pixel_valid,
    input wire [23:0] pixel_rgb,
    input wire pix_clk,
    input wire in_de,
    input wire [11:0] pixel_x,
    input wire [11:0] pixel_y,
    input wire [1:0] focus_index,
    input wire [3:0] image_ready,
    input wire [3:0] image_available,
    output reg [23:0] rgb_out
);
    reg [15:0] preview_ram [0:16383];
    reg [15:0] ram_q;
    reg [1:0] write_index;
    reg [9:0] capture_x;
    reg [8:0] capture_y;
    reg [3:0] phase_x, phase_y;
    reg [5:0] sample_x, sample_y;
    reg capture_active;
    wire sample_write = capture_active && pixel_valid &&
                        phase_x == 0 && phase_y == 9 && !capture_start;
    wire [13:0] write_address = {write_index, sample_y, sample_x};
    wire [15:0] write_rgb = {pixel_rgb[23:19], pixel_rgb[15:10], pixel_rgb[7:3]};

    always @(posedge capture_clk) begin
        if (sample_write)
            preview_ram[write_address] <= write_rgb;
    end

    always @(posedge capture_clk or negedge capture_rst_n) begin
        if (!capture_rst_n) begin
            write_index <= 0;
            capture_x <= 0;
            capture_y <= 0;
            phase_x <= 0;
            phase_y <= 0;
            sample_x <= 0;
            sample_y <= 47;
            capture_active <= 0;
        end else if (capture_start) begin
            write_index <= capture_index;
            capture_x <= 0;
            capture_y <= 0;
            phase_x <= 0;
            phase_y <= 0;
            sample_x <= 0;
            sample_y <= 47;
            capture_active <= 1;
        end else if (capture_active && pixel_valid) begin
            if (capture_x == 639) begin
                capture_x <= 0;
                sample_x <= 0;
                phase_x <= 0;
                capture_y <= capture_y + 1'b1;
                if (phase_y == 9) begin
                    phase_y <= 0;
                    sample_y <= sample_y - 1'b1;
                end else
                    phase_y <= phase_y + 1'b1;
                if (capture_y == 479)
                    capture_active <= 0;
            end else begin
                capture_x <= capture_x + 1'b1;
                if (phase_x == 9) begin
                    phase_x <= 0;
                    sample_x <= sample_x + 1'b1;
                end else
                    phase_x <= phase_x + 1'b1;
            end
        end
    end

    wire [11:0] next_x = pixel_x + 12'd1;
    wire read_right = next_x >= 320;
    wire read_bottom = pixel_y >= (INTRO_CARD ? 192 : 240);
    wire [11:0] read_x = next_x - (read_right ? (INTRO_CARD ? 12'd384 : 12'd352) : (INTRO_CARD ? 12'd64 : 12'd32));
    wire [11:0] read_y = pixel_y - (read_bottom ? (INTRO_CARD ? 12'd192 : 12'd264) : 12'd24);
    wire [5:0] sample_read_x = INTRO_CARD ? read_x[7:0]/3 : read_x[7:2];
    wire [5:0] sample_read_y = INTRO_CARD ? read_y[7:0]/3 : read_y[7:2];
    wire [13:0] read_address = {read_bottom, read_right, sample_read_y, sample_read_x};
    always @(posedge pix_clk)
        ram_q <= preview_ram[read_address];

    wire right_slot = pixel_x >= 320;
    wire bottom_slot = pixel_y >= (INTRO_CARD ? 192 : 240);
    wire [1:0] slot_index = {bottom_slot, right_slot};
    wire [11:0] local_x = pixel_x - (right_slot ? (INTRO_CARD ? 12'd384 : 12'd352) : (INTRO_CARD ? 12'd64 : 12'd32));
    wire [11:0] local_y = pixel_y - (bottom_slot ? (INTRO_CARD ? 12'd192 : 12'd264) : 12'd24);
    wire inside_slot = local_x < (INTRO_CARD ? 192 : 256) && local_y < (INTRO_CARD ? 144 : 192);
    wire border = local_x < 3 || local_x >= (INTRO_CARD ? 189 : 253) || local_y < 3 || local_y >= (INTRO_CARD ? 141 : 189);
    wire [23:0] cached_rgb = {ram_q[15:11], ram_q[15:13],
                              ram_q[10:5], ram_q[10:9],
                              ram_q[4:0], ram_q[4:2]};
    always @* begin
        rgb_out = 24'h101820;
        if (in_de && inside_slot) begin
            if (image_ready[slot_index])
                rgb_out = cached_rgb;
            else if (image_available[slot_index])
                rgb_out = (local_x[4] ^ local_y[4]) ? 24'h304860 : 24'h203040;
            else
                rgb_out = 24'h181818;
            if (border)
                rgb_out = (slot_index == focus_index) ? 24'hffcc20 : 24'h607080;
        end
    end
endmodule
