                           
`timescale 1ns/1ps

module status_osd_reference_4m #(
    parameter integer OSD_X = 8,
    parameter integer OSD_Y = 8,
    parameter integer EXHIBITION_UI = 0
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        frame_start,
    input  wire [1:0]  active_index,
    input  wire        auto_enabled,
    input  wire [7:0]  error_code,
    input  wire [2:0]  audio_status,
    input  wire        image_loading,
    input  wire        display_ready,
    input  wire        preview_active,
    input  wire        in_de,
    input  wire [11:0] in_rgb,
    input  wire [11:0] pixel_x,
    input  wire [11:0] pixel_y,
    output reg  [11:0] out_rgb,
    output reg         out_de,
    output wire        osd_pixel
);
    reg [1:0] index_q;
    reg auto_q;
    reg [7:0] error_q;
    reg [2:0] audio_q;
    reg osd_hit;
    reg [3:0] char_value;
    reg [2:0] char_row;
    reg [2:0] char_col;
    reg [4:0] glyph_row;
    reg loading_q, ready_q, preview_q;
    reg [31:0] state_text;
    reg [7:0] letter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            index_q <= 2'd0;
            auto_q <= 1'b0;
            error_q <= 8'd0;
            audio_q <= 3'd0;
            loading_q <= 0; ready_q <= 0; preview_q <= 0;
        end else if (frame_start) begin
            index_q <= active_index;
            auto_q <= auto_enabled;
            error_q <= error_code;
            audio_q <= audio_status;
            loading_q <= image_loading;
            ready_q <= display_ready;
            preview_q <= preview_active;
        end
    end

    function [4:0] font_row;
        input [3:0] value;
        input [2:0] row;
        begin
            case (value)
                4'h0: case(row) 0:font_row=5'b11111;1:font_row=5'b10001;2:font_row=5'b10001;3:font_row=5'b10001;4:font_row=5'b10001;5:font_row=5'b10001;default:font_row=5'b11111; endcase
                4'h1: case(row) 0:font_row=5'b00100;1:font_row=5'b01100;2:font_row=5'b00100;3:font_row=5'b00100;4:font_row=5'b00100;5:font_row=5'b00100;default:font_row=5'b11111; endcase
                4'h2: case(row) 0:font_row=5'b11111;1:font_row=5'b00001;2:font_row=5'b00001;3:font_row=5'b11111;4:font_row=5'b10000;5:font_row=5'b10000;default:font_row=5'b11111; endcase
                4'h3: case(row) 0:font_row=5'b11111;1:font_row=5'b00001;2:font_row=5'b00001;3:font_row=5'b11111;4:font_row=5'b00001;5:font_row=5'b00001;default:font_row=5'b11111; endcase
                4'h4: case(row) 0:font_row=5'b10001;1:font_row=5'b10001;2:font_row=5'b10001;3:font_row=5'b11111;4:font_row=5'b00001;5:font_row=5'b00001;default:font_row=5'b00001; endcase
                4'h5: case(row) 0:font_row=5'b11111;1:font_row=5'b10000;2:font_row=5'b10000;3:font_row=5'b11111;4:font_row=5'b00001;5:font_row=5'b00001;default:font_row=5'b11111; endcase
                4'h6: case(row) 0:font_row=5'b11111;1:font_row=5'b10000;2:font_row=5'b10000;3:font_row=5'b11111;4:font_row=5'b10001;5:font_row=5'b10001;default:font_row=5'b11111; endcase
                4'h7: case(row) 0:font_row=5'b11111;1:font_row=5'b00001;2:font_row=5'b00010;3:font_row=5'b00100;4:font_row=5'b01000;5:font_row=5'b01000;default:font_row=5'b01000; endcase
                4'h8: case(row) 0:font_row=5'b11111;1:font_row=5'b10001;2:font_row=5'b10001;3:font_row=5'b11111;4:font_row=5'b10001;5:font_row=5'b10001;default:font_row=5'b11111; endcase
                4'h9: case(row) 0:font_row=5'b11111;1:font_row=5'b10001;2:font_row=5'b10001;3:font_row=5'b11111;4:font_row=5'b00001;5:font_row=5'b00001;default:font_row=5'b11111; endcase
                4'ha: case(row) 0:font_row=5'b01110;1:font_row=5'b10001;2:font_row=5'b10001;3:font_row=5'b11111;4:font_row=5'b10001;5:font_row=5'b10001;default:font_row=5'b10001; endcase
                4'he: case(row) 0:font_row=5'b11111;1:font_row=5'b10000;2:font_row=5'b10000;3:font_row=5'b11110;4:font_row=5'b10000;5:font_row=5'b10000;default:font_row=5'b11111; endcase
                4'hf: case(row) 0:font_row=5'b11111;1:font_row=5'b10000;2:font_row=5'b10000;3:font_row=5'b11110;4:font_row=5'b10000;5:font_row=5'b10000;default:font_row=5'b10000; endcase
                default: font_row = 5'b00000;
            endcase
        end
    endfunction

                                                                     
    function [4:0] letter_row;
        input [7:0] ch;
        input [2:0] row;
        reg [34:0] bits;
        begin
            case (ch)
                "P": bits=35'b11110_10001_10001_11110_10000_10000_10000;
                "M": bits=35'b10001_11011_10101_10101_10001_10001_10001;
                "I": bits=35'b11111_00100_00100_00100_00100_00100_11111;
                "N": bits=35'b10001_11001_11001_10101_10011_10011_10001;
                "T": bits=35'b11111_00100_00100_00100_00100_00100_00100;
                "L": bits=35'b10000_10000_10000_10000_10000_10000_11111;
                "O": bits=35'b01110_10001_10001_10001_10001_10001_01110;
                "A": bits=35'b01110_10001_10001_11111_10001_10001_10001;
                "D": bits=35'b11110_10001_10001_10001_10001_10001_11110;
                "S": bits=35'b01111_10000_10000_01110_00001_00001_11110;
                "H": bits=35'b10001_10001_10001_11111_10001_10001_10001;
                "W": bits=35'b10001_10001_10001_10101_10101_11011_10001;
                "E": bits=35'b11111_10000_10000_11110_10000_10000_11111;
                "R": bits=35'b11110_10001_10001_11110_10100_10010_10001;
                "V": bits=35'b10001_10001_10001_10001_10001_01010_00100;
                "-": bits=35'b00000_00000_00000_11111_00000_00000_00000;
                default: bits=35'd0;
            endcase
            letter_row = row < 7 ? (bits >> ((6-row)*5)) : 5'd0;
        end
    endfunction

    always @* begin
        osd_hit = 1'b0;
        char_value = 4'h0;
        char_row = pixel_y - OSD_Y;
        char_col = pixel_x - OSD_X;
        glyph_row = 5'b00000;
        letter = " ";
                                                                              
                                                                              
        state_text = loading_q ? "LOAD" : (error_q != 0) ? "ERR " :
                     preview_q ? "PREV" : ready_q ? "SHOW" : "INIT";
        if (pixel_x >= OSD_X && pixel_x < OSD_X + 48 &&
            pixel_y >= OSD_Y && pixel_y < OSD_Y + 8) begin
            case ((pixel_x - OSD_X) / 8)
                0: char_value = {2'b00, index_q} + 1'b1;
                1: char_value = auto_q ? 4'ha : 4'he;
                2: char_value = error_q[7:4];
                3: char_value = error_q[3:0];
                4: char_value = 4'ha;
                5: char_value = {1'b0, audio_q};
                default: char_value = 4'h0;
            endcase
            glyph_row = font_row(char_value, char_row);
            if ((pixel_x - OSD_X) % 8 < 5 && char_row < 7)
                osd_hit = glyph_row[4 - ((pixel_x - OSD_X) % 8)];
        end
        if (EXHIBITION_UI) begin
            osd_hit = 0;
            glyph_row = 0;
            if (pixel_x >= OSD_X && pixel_x < OSD_X + 128 &&
                pixel_y >= OSD_Y && pixel_y < OSD_Y + 8) begin
                case ((pixel_x - OSD_X) / 8)
                    0: letter = "P";
                    1: letter = ready_q || preview_q ? ("1" + index_q) : "-";
                    3: letter = auto_q ? "A" : "M";
                    5: letter = state_text[31:24];
                    6: letter = state_text[23:16];
                    7: letter = state_text[15:8];
                    8: letter = state_text[7:0];
                    10: letter = "E";
                    14: letter = "S";
                    15: letter = audio_q == 0 ? "0" : "1";
                    default: letter = " ";
                endcase
                glyph_row = letter >= "0" && letter <= "9" ?
                            font_row(letter - "0", char_row) : letter_row(letter, char_row);
                if ((pixel_x - OSD_X) / 8 == 11)
                    glyph_row = font_row(error_q[7:4], char_row);
                if ((pixel_x - OSD_X) / 8 == 12)
                    glyph_row = font_row(error_q[3:0], char_row);
                if ((pixel_x - OSD_X) % 8 < 5 && char_row < 7)
                    osd_hit = glyph_row[4 - ((pixel_x - OSD_X) % 8)];
            end
        end
                                                                         
                                                                        
        if (EXHIBITION_UI == 2) begin
            osd_hit = 0;
            glyph_row = font_row({2'b00, index_q} + 1'b1, char_row);
            if ((ready_q || preview_q) &&
                pixel_x >= OSD_X && pixel_x < OSD_X + 5 &&
                pixel_y >= OSD_Y && pixel_y < OSD_Y + 7)
                osd_hit = glyph_row[4 - char_col];
        end
        out_de = in_de;
        out_rgb = in_rgb;
        if (in_de && osd_hit)
            out_rgb = (EXHIBITION_UI == 2 || error_q == 0) ? 12'hff0 : 12'hf44;
    end

    assign osd_pixel = osd_hit && in_de;
endmodule
