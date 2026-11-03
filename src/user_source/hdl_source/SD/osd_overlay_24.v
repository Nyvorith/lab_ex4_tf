`timescale 1ns/1ps

module osd_overlay_24 #(
    parameter integer OSD_X = 8,
    parameter integer OSD_Y = 8,
    parameter integer EXHIBITION_UI = 0,
    parameter integer HIDE_OVERLAY = 0
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        vsync,
    input  wire        de,
    input  wire [23:0] rgb_in,
    input  wire [9:0]  pixel_x,
    input  wire [1:0]  active_index,
    input  wire        auto_enabled,
    input  wire [7:0]  error_code,
    input  wire [2:0]  audio_status,
    input  wire        image_loading,
    input  wire        display_ready,
    input  wire        preview_active,
    output wire [23:0] rgb_out,
    output wire        de_out,
    output wire        osd_active
);
    reg [11:0] line_y;
    reg de_q;
    reg vs_q;
    wire frame_start = vs_q && !vsync;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            line_y <= 12'd0;
            de_q <= 1'b0;
            vs_q <= 1'b1;
        end else begin
            de_q <= de;
            vs_q <= vsync;

            if (!vsync)
                line_y <= 12'd0;
            else if (de_q && !de)
                line_y <= line_y + 1'b1;
        end
    end

    wire [11:0] osd_rgb12;
    wire osd_hit;

    status_osd_overlay #(
        .OSD_X(OSD_X),
        .OSD_Y(OSD_Y), .EXHIBITION_UI(EXHIBITION_UI)
    ) u_osd (
        .clk(clk), .rst_n(rst_n),
        .frame_start(frame_start),
        .active_index(active_index), .auto_enabled(auto_enabled),
        .error_code(error_code),
        .audio_status(audio_status),
        .image_loading(image_loading), .display_ready(display_ready),
        .preview_active(preview_active),
        .in_de(de),
        .in_rgb({rgb_in[23:20], rgb_in[15:12], rgb_in[7:4]}),
        .pixel_x({2'b00, pixel_x}),
        .pixel_y(line_y),
        .out_rgb(osd_rgb12),
        .out_de(),
        .osd_pixel(osd_hit)
    );

    assign rgb_out = (osd_hit && !HIDE_OVERLAY) ?
        {osd_rgb12[11:8], osd_rgb12[11:8],
         osd_rgb12[7:4],  osd_rgb12[7:4],
         osd_rgb12[3:0],  osd_rgb12[3:0]} : rgb_in;
    assign de_out = de;
    assign osd_active = osd_hit && !HIDE_OVERLAY;
endmodule
