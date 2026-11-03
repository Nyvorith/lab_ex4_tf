

module exhibit_caption_overlay #(
    parameter integer SPEECH_SYNC = 0,
    parameter integer GUIDE_WAVE_FEEDBACK = 0,
    parameter integer INTRO_CARD = 0,
    parameter integer ADJUST_HINT = 0,
    parameter integer HINT_FRAMES = 90,
    parameter integer ARTWORK_LABEL = 0,
    parameter integer LABEL_FRAMES = 90,
    parameter integer FRAMES_PER_STEP = 3,
    parameter integer AUTO_FRAMES_PER_STEP = 1,
    parameter integer READING_GUIDE = 0,
    parameter integer SWITCHABLE_CAPTION = 0,

    parameter integer AUTO_HOLD_FRAMES = 119
)(
    input wire clk, rst_n, frame_start,
    input wire commit, input wire [1:0] commit_index,
    input wire display_valid, preview_mode,
    input wire [1:0] preview_focus,
    input wire [7:0] brightness_value, contrast_value,
    input wire auto_mode,
    input wire caption_enabled,
    input wire artwork_ready,
    input wire speech_playing,
    input wire [31:0] speech_samples,
    input wire [9:0] x, y,
    input wire hs_in, vs_in, de_in,
    input wire [23:0] rgb_in,
    input wire waveform_hit,
    output wire hs_out, vs_out, de_out,
    output wire [23:0] rgb_out,
    output wire caption_hit,
    output reg reading_done_tgl,
    output reg [1:0] reading_done_index
);

    reg hint_armed, hint_contrast;
    reg [7:0] hint_brightness, hint_contrast_value;
    reg [$clog2(HINT_FRAMES+1)-1:0] hint_frames;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hint_armed<=0; hint_contrast<=0; hint_frames<=0;
            hint_brightness<=220; hint_contrast_value<=128;
        end else if (frame_start && ADJUST_HINT) begin
            hint_armed<=1;
            hint_brightness<=brightness_value;
            hint_contrast_value<=contrast_value;
            if (!hint_armed || !display_valid || preview_mode || commit) hint_frames<=0;
            else if (brightness_value!=hint_brightness || contrast_value!=hint_contrast_value) begin
                hint_contrast<=contrast_value!=hint_contrast_value;
                hint_frames<=HINT_FRAMES;
            end else if (hint_frames!=0) hint_frames<=hint_frames-1'b1;
        end
    end
    wire hint_box=ADJUST_HINT && hint_frames!=0 && display_valid && !preview_mode &&
        artwork_ready && de_in && x>=8 && x<176 && y>=28 && y<64;
    wire [9:0] hint_x=x-16;
    wire [9:0] hint_y=y-36;
    wire [3:0] hint_col=hint_x/12;
    wire [3:0] hint_bit=(hint_x%12)/2;
    wire [7:0] hint_value=hint_contrast ? hint_contrast_value : hint_brightness;
    wire [7:0] hint_tail=hint_value>=200 ? hint_value-200 : hint_value>=100 ? hint_value-100 : hint_value;
    reg [7:0] hint_letter;
    always @* begin
        hint_letter=" ";
        case(hint_col)
            0: hint_letter=hint_contrast ? "C" : "B";
            1: hint_letter=hint_contrast ? "O" : "R";
            2: hint_letter=hint_contrast ? "N" : "I";
            3: hint_letter=hint_contrast ? "T" : "G";
            4: hint_letter=hint_contrast ? "R" : "H";
            5: hint_letter=hint_contrast ? "A" : "T";
            6: hint_letter=hint_contrast ? "S" : " ";
            7: hint_letter=hint_contrast ? "T" : " ";
            9: hint_letter=hint_value>=100 ? "0"+(hint_value>=200 ? 2 : 1) : " ";
            10: hint_letter=hint_value>=10 ? "0"+hint_tail/10 : " ";
            11: hint_letter="0"+hint_tail%10;
            default: ;
        endcase
    end
    function [34:0] hint_font;
        input [7:0] c;
        begin
            case(c)
                "0": hint_font=35'b01110_10001_10011_10101_11001_10001_01110;
                "1": hint_font=35'b00100_01100_00100_00100_00100_00100_01110;
                "2": hint_font=35'b01110_10001_00001_00010_00100_01000_11111;
                "3": hint_font=35'b11110_00001_00001_01110_00001_00001_11110;
                "4": hint_font=35'b00010_00110_01010_10010_11111_00010_00010;
                "5": hint_font=35'b11111_10000_10000_11110_00001_00001_11110;
                "6": hint_font=35'b01110_10000_10000_11110_10001_10001_01110;
                "7": hint_font=35'b11111_00001_00010_00100_01000_01000_01000;
                "8": hint_font=35'b01110_10001_10001_01110_10001_10001_01110;
                "9": hint_font=35'b01110_10001_10001_01111_00001_00001_01110;
                "B": hint_font=35'b11110_10001_10001_11110_10001_10001_11110;
                "R": hint_font=35'b11110_10001_10001_11110_10100_10010_10001;
                "I": hint_font=35'b01110_00100_00100_00100_00100_00100_01110;
                "G": hint_font=35'b01110_10001_10000_10111_10001_10001_01110;
                "H": hint_font=35'b10001_10001_10001_11111_10001_10001_10001;
                "T": hint_font=35'b11111_00100_00100_00100_00100_00100_00100;
                "C": hint_font=35'b01110_10001_10000_10000_10000_10001_01110;
                "O": hint_font=35'b01110_10001_10001_10001_10001_10001_01110;
                "N": hint_font=35'b10001_11001_11001_10101_10011_10011_10001;
                "A": hint_font=35'b01110_10001_10001_11111_10001_10001_10001;
                "S": hint_font=35'b01111_10000_10000_01110_00001_00001_11110;
                default: hint_font=0;
            endcase
        end
    endfunction
    wire [34:0] hint_bits=hint_font(hint_letter);
    wire hint_hit=hint_box && x>=16 && hint_x<144 && y>=36 && hint_y<14 && hint_bit<5 &&
        hint_bits[(6-hint_y/2)*5+4-hint_bit];
    reg hint_box_1,hint_box_2,hint_hit_1,hint_hit_2;

    reg [1:0] picture;
    wire [10:0] speech_target;
    generate if (SPEECH_SYNC) begin : g_speech
        narration_caption_timeline u_timeline(
            .clk(clk), .rst_n(rst_n), .restart(commit || preview_mode || !display_valid),
            .playing(speech_playing && caption_enabled), .picture(picture),
            .samples(speech_samples), .scroll_target(speech_target));
    end else begin : g_no_speech
        assign speech_target = 0;
    end endgenerate
    reg valid;
    reg [10:0] scroll;
    reg [15:0] frame_count;
    reg [10:0] progress_remainder;
    reg [9:0] progress_pixels;
    reg guide_visible;
    reg text_visible;
    wire [15:0] step_frames = guide_visible ? AUTO_FRAMES_PER_STEP : FRAMES_PER_STEP;
    reg [$clog2(AUTO_HOLD_FRAMES+1)-1:0] auto_frames;
    reg auto_expired;
    localparam integer PROGRESS_BASE = 608 / AUTO_HOLD_FRAMES;
    localparam integer PROGRESS_FRACTION = 608 % AUTO_HOLD_FRAMES;
    wire [11:0] progress_sum = {1'b0, progress_remainder} + PROGRESS_FRACTION;
    wire [6:0] text_length;
    wire [10:0] text_width = {text_length, 4'b0000};
    wire [10:0] cycle_width = text_width + 11'd608;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            picture <= 0; valid <= 0; scroll <= 0; frame_count <= 0;
            reading_done_tgl <= 0; progress_remainder <= 0; progress_pixels <= 0;
            reading_done_index <= 0;
            guide_visible <= 0; auto_frames <= 0; auto_expired <= 0;
            text_visible <= 0;
        end else if (frame_start) begin

            guide_visible <= auto_mode;
            text_visible <= !SWITCHABLE_CAPTION || (caption_enabled && !auto_mode && (!SPEECH_SYNC || speech_playing));

            if (!display_valid || commit || !auto_mode || !guide_visible ||
                preview_mode || !valid) begin
                auto_frames <= 0; auto_expired <= 0;
                progress_remainder <= 0; progress_pixels <= 0;
            end else if (!auto_expired) begin
                auto_frames <= auto_frames + 1'b1;
                if (progress_sum >= AUTO_HOLD_FRAMES) begin
                    progress_pixels <= progress_pixels + PROGRESS_BASE + 1'b1;
                    progress_remainder <= progress_sum - AUTO_HOLD_FRAMES;
                end else begin
                    progress_pixels <= progress_pixels + PROGRESS_BASE;
                    progress_remainder <= progress_sum;
                end
                if (auto_frames == AUTO_HOLD_FRAMES - 1) begin
                    auto_expired <= 1;
                    reading_done_tgl <= ~reading_done_tgl;
                    reading_done_index <= picture;
                end
            end
            if (!display_valid) begin
                valid <= 0; scroll <= 0; frame_count <= 0;
                progress_remainder <= 0; progress_pixels <= 0;
            end else if (commit) begin
                picture <= commit_index; valid <= 1; scroll <= 0; frame_count <= 0;
                progress_remainder <= 0; progress_pixels <= 0;
            end else if (SWITCHABLE_CAPTION && caption_enabled && !auto_mode && !text_visible) begin
                scroll <= 0; frame_count <= 0;
            end else if (!preview_mode && valid && (!SWITCHABLE_CAPTION || text_visible)) begin

                if (SPEECH_SYNC) begin
                    frame_count <= 0;
                    if (speech_target > scroll)
                        scroll <= (speech_target - scroll > 4) ? scroll + 4 : speech_target;
                    else if (speech_target < scroll)
                        scroll <= (scroll - speech_target > 4) ? scroll - 4 : speech_target;
                end else if (frame_count >= step_frames - 1) begin
                    frame_count <= 0;
                    scroll <= (scroll == cycle_width - 1'b1) ? 11'd0 : scroll + 1'b1;
                end else frame_count <= frame_count + 1'b1;
            end
        end
    end

    reg label_pending;
    reg [$clog2(LABEL_FRAMES+1)-1:0] label_frames;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            label_pending <= 0; label_frames <= 0;
        end else if (frame_start) begin
            if (!display_valid) begin
                label_pending <= 0; label_frames <= 0;
            end else if (commit || preview_mode) begin
                label_pending <= 1; label_frames <= 0;
            end else if (ARTWORK_LABEL && valid && artwork_ready) begin
                if (label_pending) begin
                    label_frames <= LABEL_FRAMES; label_pending <= 0;
                end else if (label_frames != 0) label_frames <= label_frames - 1'b1;
            end
        end
    end

    wire [10:0] viewport_x = {1'b0, x} - 11'd16;
    wire [11:0] position_sum = {1'b0, viewport_x} + {1'b0, scroll};
    wire [11:0] position = (position_sum >= {1'b0, cycle_width}) ?
                          position_sum - cycle_width : position_sum;
    wire overlay_valid = valid && display_valid && !preview_mode && de_in;
    wire band = overlay_valid && (!SWITCHABLE_CAPTION || text_visible) &&
                x < 640 && y >= 432 && y < 480;
    wire glyph_enable = band && x >= 16 && x < 624 && y >= 448 && y < 464 &&
                        position < text_width;
    wire label_box = ARTWORK_LABEL && label_frames != 0 && artwork_ready &&
                     overlay_valid && x >= 352 && x < 624 && y >= 16 && y < 64;
    wire label_second = y >= 40;
    wire [9:0] label_x = x - 360;
    wire [9:0] label_y = label_second ? y - 40 : y - 20;
    wire label_glyph = label_box && x >= 360 && x < 616 && label_y < 16;
    wire [6:0] label_pos = {2'b11, label_second, label_x[7:4]};
    wire [8:0] text_addr = label_glyph ? {picture, label_pos} : {picture, position[10:4]};
    wire card_box = INTRO_CARD && preview_mode && display_valid && de_in &&
        x>=48 && x<592 && y>=352 && y<456;
    wire [9:0] card_x=x-64;
    wire [9:0] card_y=y-364;
    wire [1:0] card_row=card_y>=48 ? 2'd2 : card_y>=24 ? 2'd1 : 2'd0;
    wire [9:0] card_line_y=card_y - (card_row==2 ? 48 : card_row==1 ? 24 : 0);
    wire card_glyph=card_box && x>=64 && x<576 && y>=364 && card_line_y<16 &&
        (card_row==2 || card_x<256);
    wire [5:0] card_cell=card_row==2 ? {1'b1,card_x[8:4]} : {1'b0,card_row[0],card_x[7:4]};
    reg card_box_1,card_box_2,card_glyph_1,card_glyph_2;
    reg [1:0] card_row_1,card_row_2;
    reg label_box_1, label_box_2, label_glyph_1, label_glyph_2;
    reg label_second_1, label_second_2;
    wire [7:0] text_id;
    wire [15:0] glyph_row;
    reg [3:0] glyph_y_1, bit_x_1, bit_x_2;
    reg band_1, band_2, glyph_1, glyph_2;
    reg guide_1, guide_2, fill_1, fill_2;
    wire guide = READING_GUIDE && guide_visible && overlay_valid && x >= 16 && x < 624 && y >= 474 && y < 478;
    reg [23:0] rgb_1, rgb_2;
    reg wave_1,wave_2;
    reg [2:0] sync_1, sync_2;
    exhibit_caption_roms u_rom (
        .clk(clk), .card_mode(card_glyph), .card_addr({preview_focus,card_cell}),
        .text_addr(text_addr), .text_id(text_id),
        .glyph_addr({text_id, glyph_y_1}), .glyph_row(glyph_row),
        .picture(picture), .text_length(text_length)
    );
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wave_1<=0;wave_2<=0;
            hint_box_1<=0;hint_box_2<=0;hint_hit_1<=0;hint_hit_2<=0;
            card_box_1<=0;card_box_2<=0;card_glyph_1<=0;card_glyph_2<=0;card_row_1<=0;card_row_2<=0;
            label_box_1 <= 0; label_box_2 <= 0; label_glyph_1 <= 0; label_glyph_2 <= 0;
            label_second_1 <= 0; label_second_2 <= 0;
            glyph_y_1 <= 0; bit_x_1 <= 0; bit_x_2 <= 0;
            band_1 <= 0; band_2 <= 0; glyph_1 <= 0; glyph_2 <= 0;
            guide_1 <= 0; guide_2 <= 0; fill_1 <= 0; fill_2 <= 0;
            rgb_1 <= 0; rgb_2 <= 0; sync_1 <= 3'b110; sync_2 <= 3'b110;
        end else begin
            wave_1<=GUIDE_WAVE_FEEDBACK && waveform_hit;wave_2<=wave_1;
            hint_box_1<=hint_box;hint_box_2<=hint_box_1;
            hint_hit_1<=hint_hit;hint_hit_2<=hint_hit_1;
            card_box_1<=card_box;card_box_2<=card_box_1;
            card_glyph_1<=card_glyph;card_glyph_2<=card_glyph_1;
            card_row_1<=card_row;card_row_2<=card_row_1;
            glyph_y_1 <= card_glyph ? card_line_y[3:0] : label_glyph ? label_y[3:0] : y[3:0];
            bit_x_1 <= card_glyph ? card_x[3:0] : label_glyph ? label_x[3:0] : position[3:0]; bit_x_2 <= bit_x_1;
            label_box_1 <= label_box; label_box_2 <= label_box_1;
            label_glyph_1 <= label_glyph; label_glyph_2 <= label_glyph_1;
            label_second_1 <= label_second; label_second_2 <= label_second_1;
            band_1 <= band; band_2 <= band_1;
            guide_1 <= guide; guide_2 <= guide_1;
            fill_1 <= (viewport_x < progress_pixels); fill_2 <= fill_1;
            glyph_1 <= glyph_enable; glyph_2 <= glyph_1;
            rgb_1 <= rgb_in; rgb_2 <= rgb_1;
            sync_1 <= {hs_in, vs_in, de_in}; sync_2 <= sync_1;
        end
    end
    assign {hs_out, vs_out, de_out} = sync_2;
    assign caption_hit = glyph_2 && glyph_row[15 - bit_x_2];
    wire [23:0] dark_rgb = {2'b00, rgb_2[23:18], 2'b00, rgb_2[15:10], 2'b00, rgb_2[7:2]};
    wire label_hit = label_glyph_2 && glyph_row[15 - bit_x_2];
    wire [23:0] label_background = {1'b0, rgb_2[23:17], 1'b0, rgb_2[15:9], 1'b0, rgb_2[7:1]};
    wire card_hit=card_glyph_2 && glyph_row[15-bit_x_2];
    assign rgb_out = hint_box_2 ? (hint_hit_2 ? 24'hf0e4c8 : 24'h1c2a38) : card_box_2 ? (card_hit ? (card_row_2==0 ? 24'hf0e4c8 : card_row_2==1 ? 24'hb8c8d8 : 24'hf0f4f8) : 24'h1c2a38) : label_box_2 ? (label_hit ? (label_second_2 ? 24'he0e4e8 : 24'hf0e4c8) : label_background) :
                     guide_2 ? (fill_2 ? 24'h20d8c0 : 24'h384048) :
                     caption_hit ? 24'hf0f4f8 : (band_2 && !wave_2) ? dark_rgb : rgb_2;
endmodule
