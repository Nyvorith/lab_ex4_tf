`timescale 1ns/1ps

module promax_audio_waveform #(
    parameter integer WAVE_X=64, WAVE_Y=400,
    parameter integer WAVE_WIDTH=512, WAVE_HEIGHT=64, DECIMATE=12,
    parameter integer GUIDE_MODE=0
)(
    input wire clk, rst_n, vsync, de,
    input wire [23:0] rgb_in,
    input wire [9:0] pixel_x,
    input wire enable, pcm_tap_valid,
    input wire signed [15:0] pcm_tap_left,
    output wire [23:0] rgb_out,
    output wire waveform_active
);
    localparam integer POINTS=32;
    localparam integer COLUMN_WIDTH=WAVE_WIDTH/POINTS;
    localparam integer MIDLINE=WAVE_Y+WAVE_HEIGHT/2;
    localparam integer SKIP_BITS=DECIMATE<=1 ? 1 : $clog2(DECIMATE);
    reg previous_vs, previous_de;
    reg [11:0] scanline;
    wire publish_boundary=previous_vs && !vsync;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            previous_vs<=1; previous_de<=0; scanline<=0;
        end else begin
            previous_vs<=vsync; previous_de<=de;
            if(!vsync) scanline<=0;
            else if(previous_de && !de) scanline<=scanline+1'b1;
        end
    end

    reg signed [7:0] samples [0:63];
    reg capture_bank, shown_bank;
    reg [5:0] capture_count;
    reg [SKIP_BITS-1:0] skip_samples;
    reg [7:0] capture_peak, display_peak;
    reg display_valid;
    wire signed [7:0] amplitude=pcm_tap_left[15:8];
    wire [7:0] magnitude=amplitude[7] ? -amplitude : amplitude;
    wire take_sample=pcm_tap_valid && capture_count<POINTS && skip_samples==0;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            capture_bank<=0; shown_bank<=1; capture_count<=0;
            skip_samples<=0; capture_peak<=0; display_peak<=0; display_valid<=0;
        end else if(GUIDE_MODE && !enable) begin
            capture_bank<=0; shown_bank<=1; capture_count<=0;
            skip_samples<=0; capture_peak<=0; display_peak<=0; display_valid<=0;
        end else if(publish_boundary) begin
            if(capture_count==POINTS) begin
                shown_bank<=capture_bank;
                capture_bank<=!capture_bank;
                display_peak<=capture_peak;
                display_valid<=1;
            end
            if(GUIDE_MODE && capture_count!=POINTS) display_valid<=0;
            capture_count<=0; skip_samples<=0; capture_peak<=0;
        end else if(pcm_tap_valid && capture_count<POINTS) begin
            if(take_sample) begin
                capture_count<=capture_count+1'b1;
                skip_samples<=DECIMATE-1;
                if(magnitude>capture_peak) capture_peak<=magnitude;
            end else skip_samples<=skip_samples-1'b1;
        end
    end

    always @(posedge clk) begin
        if(rst_n && !publish_boundary && take_sample && (!GUIDE_MODE || enable))
            samples[{capture_bank,capture_count[4:0]}]<=amplitude;
    end

    wire paint=enable && de;
    wire in_panel=paint && pixel_x>=WAVE_X && pixel_x<WAVE_X+WAVE_WIDTH &&
                  scanline>=WAVE_Y && scanline<WAVE_Y+WAVE_HEIGHT;

    function integer scale_height;
        input integer value;
        input [7:0] peak;
        integer scaled;
        begin
            scaled=peak<2 ? 0 : peak<8 ? value : peak<16 ? value/2 :
                   peak<32 ? value/4 : peak<64 ? value/8 : value/16;
            if(scaled>4) scaled=4;
            if(scaled< -4) scaled= -4;
            scale_height=scaled;
        end
    endfunction
    integer column, signed_height, trace_y, guide_height, previous_height, previous_y, segment_phase;
    reg trace_hit;
    always @* begin
        column=0; signed_height=0; trace_y=MIDLINE; trace_hit=0; guide_height=0; previous_height=0; previous_y=MIDLINE; segment_phase=0;
        if(in_panel && display_valid) begin
            column=(pixel_x-WAVE_X)/COLUMN_WIDTH;
            if(column<POINTS) begin
                signed_height=$signed(samples[{shown_bank,column[4:0]}]);
                guide_height=scale_height(signed_height,display_peak);
                trace_y=MIDLINE-(GUIDE_MODE ? guide_height : signed_height/4);
                if(GUIDE_MODE) begin
                    previous_height=column==0 ? guide_height : scale_height($signed(samples[{shown_bank,column[4:0]-5'd1}]),display_peak);
                    previous_y=MIDLINE-previous_height;
                    segment_phase=((pixel_x-WAVE_X)%COLUMN_WIDTH)+1;
                    trace_y=segment_phase==1 ? previous_y : segment_phase==2 ? (trace_y+previous_y)/2 : trace_y;
                    trace_hit=scanline==trace_y;
                end else trace_hit=scanline+1>=trace_y && scanline<=trace_y+1;
            end
        end
    end
    wire baseline_hit=in_panel && scanline==MIDLINE && (!GUIDE_MODE || display_valid);
    wire meter_hit=!GUIDE_MODE && paint && pixel_x>=WAVE_X+WAVE_WIDTH+8 &&
                   pixel_x<WAVE_X+WAVE_WIDTH+16 &&
                   scanline>=WAVE_Y+WAVE_HEIGHT-(display_peak>>2) &&
                   scanline<WAVE_Y+WAVE_HEIGHT;
    wire [7:0] guide_r=8'd52+{3'b0,rgb_in[23:19]};
    wire [7:0] guide_g=8'd50+{3'b0,rgb_in[15:11]};
    wire [7:0] guide_b=8'd46+{3'b0,rgb_in[7:3]};
    assign waveform_active=GUIDE_MODE ? trace_hit : (trace_hit | baseline_hit | meter_hit);
    assign rgb_out=GUIDE_MODE ? (trace_hit ? {guide_r,guide_g,guide_b} : rgb_in) :
                   trace_hit ? 24'h20ff90 : meter_hit ? 24'hffb020 :
                   baseline_hit ? 24'h406060 : rgb_in;
endmodule
