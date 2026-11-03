`timescale 1ns/1ps

module bmp_fit_scaler #(parameter integer PIXEL_GAP=63,
                           parameter integer KEEP_ASPECT=1) (
    input wire clk, rst, start,
    input wire byte_valid,
    input wire [7:0] byte_data,
    input wire file_done,
    input wire [7:0] fs_error,
    output wire pause_file,
    output reg write_req,
    input wire write_ack,
    input wire pixel_ready,
    output reg pixel_valid,
    output reg [23:0] pixel,
    output reg error_pulse,
    output reg [2:0] error_code,
    output reg done,
    output wire busy,
    output wire [31:0] source_size,
    output wire [19:0] fitted_size
);
    localparam FETCH=0, PARSE=1, Y_INIT=2, ROW_END=3,
               READ_PIXEL=4, EMIT=5, X_STEP=6, Y_STEP=7, DRAIN=8, IDLE=9,
               LAYOUT=10, DIVIDE=11, PAD=12;
    reg [3:0] state, return_state;
    reg active, eof_seen, bad_header, overflow_seen;
    assign busy = active;
    reg [7:0] io_error;
    reg [7:0] byte_fifo [0:1023];
    reg [9:0] wp, rp;
    reg [10:0] used;
    reg [7:0] current_byte;
    wire push = active && byte_valid;
    wire pop = active && state==FETCH && used!=0;
    assign pause_file = used >= 11'd128;

    reg [23:0] row_ram [0:2047];
    reg [23:0] row_pixel;
    reg [31:0] offset, data_offset;
    reg [15:0] width, height;
    assign source_size = {width, height};
    reg [12:0] row_bytes, row_pos;
    reg [11:0] source_x, source_y, target_x, target_y;
    reg [12:0] x_remainder, y_remainder;
    reg [9:0] dest_x, dest_y;
    reg [1:0] channel;
    reg [15:0] bg;
    reg in_pixels, request_sent;
    reg [5:0] pace;
    reg [9:0] scaled_w, scaled_h, left_pad, bottom_pad;
    assign fitted_size = {scaled_w, scaled_h};
    reg [21:0] layout_remainder;
    reg [15:0] layout_divisor;
    reg [9:0] layout_quotient;
    reg wide_image;
    wire [21:0] width_times_480 = {6'd0,width} * 22'd480;
    wire [21:0] height_times_640 = {6'd0,height} * 22'd640;
    wire content_x = dest_x >= left_pad && dest_x < left_pad + scaled_w;

    always @(posedge clk) begin
        if (push && used < 1024) byte_fifo[wp] <= byte_data;
        if (pop) current_byte <= byte_fifo[rp];
        if (active && state==PARSE && in_pixels && !bad_header &&
            row_pos < row_bytes && channel==2)
            row_ram[source_x[10:0]] <= {current_byte,bg};
        if (state==READ_PIXEL) row_pixel <= row_ram[target_x[10:0]];
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state<=IDLE; return_state<=PARSE; active<=0; eof_seen<=0;
            bad_header<=0; overflow_seen<=0; io_error<=0;
            wp<=0; rp<=0; used<=0; offset<=0; data_offset<=54;
            width<=0; height<=0; row_bytes<=0; row_pos<=0;
            source_x<=0; source_y<=0; target_x<=0; target_y<=0;
            x_remainder<=0; y_remainder<=0; dest_x<=0; dest_y<=0;
            channel<=0; bg<=0; in_pixels<=0; request_sent<=0; pace<=0;
            write_req<=0; pixel_valid<=0; pixel<=0;
            error_pulse<=0; error_code<=0; done<=0;
            scaled_w<=640; scaled_h<=480; left_pad<=0; bottom_pad<=0;
            layout_remainder<=0; layout_divisor<=1; layout_quotient<=0; wide_image<=0;
        end else begin
            pixel_valid<=0; error_pulse<=0; done<=0;
            if(write_req && write_ack) write_req<=0;
            if(pace!=0) pace<=pace-1'b1;
            if(start) begin
                state<=FETCH; return_state<=PARSE; active<=1; eof_seen<=0;
                bad_header<=0; overflow_seen<=0; io_error<=0;
                wp<=0; rp<=0; used<=0; offset<=0; data_offset<=54;
                width<=0; height<=0; row_bytes<=0; row_pos<=0;
                source_x<=0; source_y<=0; target_x<=0; target_y<=0;
                x_remainder<=0; y_remainder<=0; dest_x<=0; dest_y<=0;
                channel<=0; bg<=0; in_pixels<=0; request_sent<=0; pace<=0;
                write_req<=0; error_code<=0;
                scaled_w<=640; scaled_h<=480; left_pad<=0; bottom_pad<=0;
                layout_remainder<=0; layout_divisor<=1; layout_quotient<=0; wide_image<=0;
            end else if(active) begin
                if(push) begin
                    wp<=wp+1'b1;
                    if(used==1024) overflow_seen<=1;
                end
                if(pop) rp<=rp+1'b1;
                case({push,pop})
                    2'b10: used<=used+1'b1;
                    2'b01: used<=used-1'b1;
                    default: ;
                endcase
                if(file_done) begin eof_seen<=1; io_error<=fs_error; end
                case(state)
                    FETCH: if(used!=0) state<=return_state;
                        else if(eof_seen) begin
                            active<=0; state<=IDLE; write_req<=0; done<=1;
                            if(bad_header || io_error!=0 || overflow_seen || dest_y!=480) begin
                                error_pulse<=1;
                                error_code<=bad_header ? 1 : (io_error!=0 ? 2 : 3);
                            end
                        end
                    PARSE: begin
                        state<=FETCH;
                        offset<=offset+1'b1;
                        if(!in_pixels) begin
                            case(offset)
                                0: if(current_byte!=8'h42) bad_header<=1;
                                1: if(current_byte!=8'h4d) bad_header<=1;
                                10: data_offset[7:0]<=current_byte;
                                11: data_offset[15:8]<=current_byte;
                                12: data_offset[23:16]<=current_byte;
                                13: begin
                                    data_offset[31:24]<=current_byte;
                                    if({current_byte,data_offset[23:0]}<54) bad_header<=1;
                                end
                                14: if(current_byte<40) bad_header<=1;
                                15,16,17: if(current_byte!=0) bad_header<=1;
                                18: width[7:0]<=current_byte;
                                19: begin
                                    width[15:8]<=current_byte;
                                    if({current_byte,width[7:0]}==0 ||
                                       {current_byte,width[7:0]}>2048) bad_header<=1;
                                end
                                20,21,24,25: if(current_byte!=0) bad_header<=1;
                                22: height[7:0]<=current_byte;
                                23: begin
                                    height[15:8]<=current_byte;
                                    if({current_byte,height[7:0]}==0 ||
                                       {current_byte,height[7:0]}>2048) bad_header<=1;
                                end
                                26: if(current_byte!=1) bad_header<=1;
                                27: if(current_byte!=0) bad_header<=1;
                                28: if(current_byte!=24) bad_header<=1;
                                29,30,31,32,33: if(current_byte!=0) bad_header<=1;
                                default: ;
                            endcase
                            if(offset==40 && !bad_header && !request_sent) begin
                                write_req<=1; request_sent<=1;
                            end
                            if(offset==data_offset-1) begin
                                in_pixels<=1;
                                row_bytes<=width+{width[11:0],1'b0};
                                y_remainder<=height-1'b1;
                                state<=LAYOUT;
                            end
                        end else if(!bad_header && source_y<height) begin
                            row_pos<=row_pos+1'b1;
                            if(row_pos<row_bytes) begin
                                case(channel)
                                    0: begin bg[7:0]<=current_byte; channel<=1; end
                                    1: begin bg[15:8]<=current_byte; channel<=2; end
                                    2: begin channel<=0; source_x<=source_x+1'b1; end
                                endcase
                            end
                            if(row_pos+1'b1==((row_bytes+13'd3)&13'h1ffc)) begin
                                row_pos<=0; source_x<=0; channel<=0;
                                state<=ROW_END;
                            end
                        end
                    end
                    LAYOUT: begin
                        if(!KEEP_ASPECT || bad_header) state<=Y_INIT;
                        else begin
                            wide_image<=width_times_480>=height_times_640;
                            layout_remainder<=width_times_480>=height_times_640 ? height_times_640 : width_times_480;
                            layout_divisor<=width_times_480>=height_times_640 ? width : height;
                            layout_quotient<=0; state<=DIVIDE;
                        end
                    end
                    DIVIDE: if(layout_remainder>=layout_divisor) begin
                        layout_remainder<=layout_remainder-layout_divisor;
                        layout_quotient<=layout_quotient+1'b1;
                    end else begin

                        if(wide_image) begin
                            scaled_h<=layout_quotient==0 ? 10'd1 : layout_quotient;
                            bottom_pad<=(480-(layout_quotient==0 ? 10'd1 : layout_quotient))/2;
                        end else begin
                            scaled_w<=layout_quotient==0 ? 10'd1 : layout_quotient;
                            left_pad<=(640-(layout_quotient==0 ? 10'd1 : layout_quotient))/2;
                        end
                        state<=Y_INIT;
                    end
                    Y_INIT: if(y_remainder>=scaled_h) begin
                        y_remainder<=y_remainder-scaled_h; target_y<=target_y+1'b1;
                    end else if(dest_y<bottom_pad) state<=PAD;
                    else state<=FETCH;
                    PAD: if(pace==0 && pixel_ready && !write_req) begin
                        pixel<=0; pixel_valid<=1; pace<=PIXEL_GAP;
                        if(dest_x==639) begin
                            dest_x<=0; dest_y<=dest_y+1'b1;
                            if(dest_y==479) begin return_state<=DRAIN; state<=FETCH; end
                            else if(dest_y+1'b1==bottom_pad) state<=FETCH;
                        end else dest_x<=dest_x+1'b1;
                    end
                    ROW_END: if(source_y==target_y && dest_y<480) begin
                        dest_x<=0; target_x<=0; x_remainder<=0; state<=READ_PIXEL;
                    end else begin source_y<=source_y+1'b1; state<=FETCH; end
                    READ_PIXEL: state<=EMIT;
                    EMIT: if(pace==0 && pixel_ready && !write_req) begin
                        pixel<=content_x ? row_pixel : 24'd0; pixel_valid<=1; pace<=PIXEL_GAP;
                        if(dest_x==639) begin
                            dest_y<=dest_y+1'b1;
                            y_remainder<=y_remainder+height;
                            state<=Y_STEP;
                        end else begin
                            dest_x<=dest_x+1'b1;
                            if(content_x) x_remainder<=x_remainder+width;
                            state<=X_STEP;
                        end
                    end
                    X_STEP: if(x_remainder>=scaled_w) begin
                        x_remainder<=x_remainder-scaled_w; target_x<=target_x+1'b1;
                    end else state<=READ_PIXEL;
                    Y_STEP: if(dest_y==480) begin
                        return_state<=DRAIN; state<=FETCH;
                    end else if(dest_y==bottom_pad+scaled_h) begin
                        dest_x<=0; state<=PAD;
                    end else if(y_remainder>=scaled_h) begin
                        y_remainder<=y_remainder-scaled_h; target_y<=target_y+1'b1;
                    end else state<=ROW_END;
                    DRAIN: state<=FETCH;
                    default: state<=IDLE;
                endcase
            end
        end
    end
endmodule
