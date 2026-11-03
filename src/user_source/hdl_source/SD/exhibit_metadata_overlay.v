`timescale 1ns/1ps

module exhibit_metadata_overlay (
    input wire clk, rst_n, commit,
    input wire [31:0] source_size,
    input wire [19:0] fitted_size,
    input wire enable, de,
    input wire [9:0] x, y,
    input wire [23:0] rgb_in,
    output reg [23:0] rgb_out
);
    reg [63:0] binary_q, bcd_q;
    reg [63:0] corrected;
    reg [4:0] steps;
    reg valid;
    integer i;
    always @* begin
        corrected = bcd_q;
        for (i=0;i<16;i=i+1)
            if (bcd_q[i*4 +: 4] >= 5)
                corrected[i*4 +: 4] = bcd_q[i*4 +: 4] + 4'd3;
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            binary_q<=0; bcd_q<=0; steps<=0; valid<=0;
        end else if (commit) begin

            binary_q <= {source_size,6'd0,10'd640,6'd0,10'd480};
            bcd_q<=0; steps<=16; valid<=0;
        end else if (steps!=0) begin
            binary_q <= {binary_q[62:48],1'b0,binary_q[46:32],1'b0,
                         binary_q[30:16],1'b0,binary_q[14:0],1'b0};
            bcd_q <= {corrected[62:48],binary_q[63],corrected[46:32],binary_q[47],
                      corrected[30:16],binary_q[31],corrected[14:0],binary_q[15]};
            steps <= steps-1'b1;
            if (steps==1) valid<=1;
        end
    end

    function [63:0] font8;
        input [5:0] value;
        begin
            case(value)
                0:font8=64'h3c66666e76663c00; 1:font8=64'h1838181818187e00;
                2:font8=64'h3c66060c18307e00; 3:font8=64'h3c66061c06663c00;
                4:font8=64'h0c1c3c6ccc0c1e00; 5:font8=64'h7e607c0666663c00;
                6:font8=64'h1c30607c66663c00; 7:font8=64'h7e060c1830303000;
                8:font8=64'h3c66663c66663c00; 9:font8=64'h3c66663e060c3800;
                10:font8=64'h000018183c3c1800;
                11:font8=64'h3c66603c06663c00;
                12:font8=64'h7c66667c6c666600;
                13:font8=64'h7e60606060607e00;
                14:font8=64'h3c66666666663c00;
                15:font8=64'h6666666666663c00;
                16:font8=64'h7e18181818181800;
                default:font8=64'h0000000000000000;
            endcase
        end
    endfunction

    wire [9:0] dx = x-10'd528;
    wire [9:0] dy = y-10'd8;
    reg [5:0] glyph;
    reg [3:0] nibble;
    reg [3:0] slot;
    reg [2:0] row, col;
    reg [63:0] bitmap;
    always @* begin
        glyph=17; nibble=0; slot=dx[9:3]; row=dy[2:0]; col=dx[2:0];
        if (dy[9:3]==0) begin
            case(slot)
                0:glyph=11; 1:glyph=12; 2:glyph=13; 3:glyph=17;
                4,5,6,7: begin
                    case(slot) 4:nibble=bcd_q[63:60]; 5:nibble=bcd_q[59:56];
                        6:nibble=bcd_q[55:52]; default:nibble=bcd_q[51:48]; endcase
                    glyph=(nibble<=9)?nibble:17;
                    if ((slot==4 && nibble==0) || (slot==5 && bcd_q[63:56]==0 && nibble==0) ||
                        (slot==6 && bcd_q[63:52]==0 && nibble==0)) glyph=17;
                end
                8:glyph=10;
                9,10,11,12: begin
                    case(slot) 9:nibble=bcd_q[47:44]; 10:nibble=bcd_q[43:40];
                        11:nibble=bcd_q[39:36]; default:nibble=bcd_q[35:32]; endcase
                    glyph=(nibble<=9)?nibble:17;
                    if ((slot==9 && nibble==0) || (slot==10 && bcd_q[47:44]==0 && nibble==0) ||
                        (slot==11 && bcd_q[47:40]==0 && nibble==0)) glyph=17;
                end
                default:glyph=17;
            endcase
        end else if (dy[9:3]==1) begin
            case(slot)
                0:glyph=14; 1:glyph=15; 2:glyph=16; 3:glyph=17;
                4:glyph=17; 5:glyph=6; 6:glyph=4; 7:glyph=0; 8:glyph=10;
                9:glyph=17; 10:glyph=4; 11:glyph=8; 12:glyph=0;
                default:glyph=17;
            endcase
        end
        bitmap=font8(glyph);
        rgb_out=rgb_in;
        if (enable && de && valid && x>=528 && x<632 && y>=8 && y<24) begin
            rgb_out={2'b00,rgb_in[23:18],2'b00,rgb_in[15:10],2'b00,rgb_in[7:2]};
            if(bitmap[63-(row*8)-col]) rgb_out=24'hffffff;
        end
    end
endmodule
