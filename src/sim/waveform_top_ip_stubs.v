`timescale 1ns/1ps
                                                                                
module sys_pll(input refclk, input reset, output extlock,
               output clk0_out, output clk1_out, output clk2_out);
    assign extlock = 1'b1;
    assign clk0_out = refclk;
    assign clk1_out = refclk;
    assign clk2_out = refclk;
endmodule

module video_pll(input refclk, input reset, output extlock,
                 output clk0_out, output clk1_out);
    assign extlock = 1'b1;
    assign clk0_out = refclk;
    assign clk1_out = refclk;
endmodule

module sdram(input Clk, input Clk_sft, input Rst,
             output Sdr_init_done, output Sdr_init_ref_vld, output Sdr_busy,
             input App_wr_en, input [20:0] App_wr_addr, input [3:0] App_wr_dm,
             input [31:0] App_wr_din, input App_rd_en, input [20:0] App_rd_addr,
             output Sdr_rd_en, output [31:0] Sdr_rd_dout);
    assign Sdr_init_done = 1'b1;
    assign Sdr_init_ref_vld = 1'b0;
    assign Sdr_busy = 1'b0;
    assign Sdr_rd_en = 1'b0;
    assign Sdr_rd_dout = 32'd0;
endmodule

module hdmi_1_4b_transmitter_core_wrapper #(
    parameter DEVICE = "EG", HTOTAL = 800, HSA = 96, HFP = 16, HBP = 48,
    HACTIVE = 640, VTOTAL = 525, VSA = 2, VFP = 10, VBP = 33, VACTIVE = 480,
    VIDEO_VIC = 1, VIDEO_TPG = "Disable", VIDEO_FORMAT = "RGB",
    AUDIO_SAMPLE_RATE = "48K", IIC_SCL_DIV = 250
)(
    input I_pixel_clk, I_rst, I_edid_read_trig,
    output O_edid_read_valid, output [7:0] O_edid_read_data,
    input I_axis_s_user, I_axis_s_valid, I_axis_s_last,
    input [23:0] I_axis_s_data, output O_axis_s_ready,
    input I_audio_valid, input [23:0] I_audio_left_data, I_audio_right_data,
    input I_acr_valid, input [19:0] I_acr_cts, I_acr_n,
    output O_video_locked, O_ddc_scl, inout IO_ddc_sda,
    output [9:0] O_ch0_tmds_data, O_ch1_tmds_data, O_ch2_tmds_data, O_clk_tmds_data
);
    assign O_axis_s_ready = 1'b1;
    assign O_video_locked = 1'b1;
endmodule

module EG_LOGIC_ODDR(input clk, rst, d0, d1, output q);
    assign q = clk ? d1 : d0;
endmodule
