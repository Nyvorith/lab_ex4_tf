`timescale 1ns/1ps
module narration_caption_timeline(
    input wire clk, rst_n, restart, playing,
    input wire [1:0] picture,
    input wire [31:0] samples,
    output reg [10:0] scroll_target
);
    reg [5:0] cursor;
    reg [1:0] current_picture;
    reg [31:0] previous_samples;
    reg [77:0] segment;
    wire [19:0] first_sample = segment[77:58];
    wire [19:0] last_sample = segment[57:38];
    wire [10:0] first_scroll = segment[37:27];
    wire [10:0] last_scroll = segment[26:16];
    wire [19:0] offset = samples <= first_sample ? 20'd0 :
        samples >= last_sample ? last_sample - first_sample : samples[19:0] - first_sample;
    wire [35:0] fraction = offset * segment[15:0];
    wire [16:0] position_sum = {6'd0,first_scroll} + {1'b0,fraction[35:20]};
    wire [10:0] interpolated = position_sum > {6'd0,last_scroll} ? last_scroll : position_sum[10:0];
    always @* begin
        case ({picture,cursor})
            8'd0: segment = 78'h00000003c54000000000;
            8'd1: segment = 78'h003c5419bcc000000000;
            8'd2: segment = 78'h019bcc2cbf8000000000;
            8'd3: segment = 78'h02cbf836a38000000000;
            8'd4: segment = 78'h036a383d29c000000000;
            8'd5: segment = 78'h03d29c462f0000000000;
            8'd6: segment = 78'h0462f04e1a4000000000;
            8'd7: segment = 78'h04e1a4617a0000000000;
            8'd8: segment = 78'h0617a068e74000000000;
            8'd9: segment = 78'h068e7499e70000000000;
            8'd10: segment = 78'h099e70a7ef8000000000;
            8'd11: segment = 78'h0a7ef8c510c000000000;
            8'd12: segment = 78'h0c510cceb2c000000000;
            8'd13: segment = 78'h0ceb2cd6e300001007d1;
            8'd14: segment = 78'h0d6e30fde600804004ec;
            8'd15: segment = 78'h0fde61124b8200600647;
            8'd16: segment = 78'h1124b91a7383007007d9;
            8'd17: segment = 78'h11a739218f0380800901;
            8'd18: segment = 78'h1218f1265dc400900d50;
            8'd19: segment = 78'h1265dd2fb34480a006db;
            8'd20: segment = 78'h12fb353acf4500b005c3;
            8'd21: segment = 78'h13acf542b6c580c00819;
            8'd22: segment = 78'h142b6d4ba40600d0072b;
            8'd23: segment = 78'h14ba41540bc680e0079d;
            8'd24: segment = 78'h1540bd5db6c700f0069f;
            8'd25: segment = 78'h15db6d97154781200359;
            8'd26: segment = 78'h197155a163c901300636;
            8'd27: segment = 78'h1a163db2ec898150074d;
            8'd28: segment = 78'h1b2ec9bc9fca81600699;
            8'd29: segment = 78'h1bc9fdc503cb017007a1;
            8'd30: segment = 78'h1c503dccc68b8180083f;
            8'd31: segment = 78'h1ccc69e0420c01a00692;
            8'd32: segment = 78'h1e042205914d01d00525;
            8'd33: segment = 78'h205916182b0e81f006e2;
            8'd34: segment = 78'h2182b22a850f821006fa;
            8'd35: segment = 78'h22a852336b9082200731;
            8'd36: segment = 78'h2336ba3d42d102300681;
            8'd37: segment = 78'h23d42e4e029182300000;
            8'd38: segment = 78'h24e02a52d8d182300000;
            8'd39: segment = 78'h252d8e7bde5182300000;
            8'd40: segment = 78'h27bde68d749182300000;
            8'd41: segment = 78'h28d74aa0d15182300000;
            8'd42: segment = 78'h2a0d16b23a9182300000;
            8'd43: segment = 78'h2b23aabce85182300000;
            8'd44: segment = 78'h2bce86d2f95182300000;
            8'd45: segment = 78'h2d2f96e6279182300000;
            8'd46: segment = 78'h2e627bffffd182300000;
            8'd64: segment = 78'h00000003900000000000;
            8'd65: segment = 78'h003900129f0000000000;
            8'd66: segment = 78'h0129f030144000000000;
            8'd67: segment = 78'h030144440d0000000000;
            8'd68: segment = 78'h0440d04b528000000000;
            8'd69: segment = 78'h04b528670bc000000000;
            8'd70: segment = 78'h0670bc7efcc000000000;
            8'd71: segment = 78'h07efcc87618000000000;
            8'd72: segment = 78'h0876188eef0000000000;
            8'd73: segment = 78'h08eef096edc000000000;
            8'd74: segment = 78'h096edca1754000000000;
            8'd75: segment = 78'h0a1754a90a4000000000;
            8'd76: segment = 78'h0a90a4b61c0000000000;
            8'd77: segment = 78'h0b61c0c94e0000100356;
            8'd78: segment = 78'h0c94e0f97b00803002a8;
            8'd79: segment = 78'h0f97b10a5e0180500794;
            8'd80: segment = 78'h10a5e1141e0280600690;
            8'd81: segment = 78'h1141e130fbc30080046f;
            8'd82: segment = 78'h130fbd49928400a00535;
            8'd83: segment = 78'h14992954140500b00618;
            8'd84: segment = 78'h1541415dca4580c00697;
            8'd85: segment = 78'h15dca566410600d00790;
            8'd86: segment = 78'h166411a4804681000316;
            8'd87: segment = 78'h1a4805aefc880110061b;
            8'd88: segment = 78'h1aefc9c1448881300700;
            8'd89: segment = 78'h1c1449d34cc981500719;
            8'd90: segment = 78'h1d34cde51a8a81700731;
            8'd91: segment = 78'h1e51a9ed26cb818007f4;
            8'd92: segment = 78'h1ed26e01b28c01a0063b;
            8'd93: segment = 78'h201b2a12c58d01c0077f;
            8'd94: segment = 78'h212c5a32014e01e00419;
            8'd95: segment = 78'h23201645928f0200068b;
            8'd96: segment = 78'h24592a56e55002000000;
            8'd97: segment = 78'h256e565edf9002000000;
            8'd98: segment = 78'h25edfa71171002000000;
            8'd99: segment = 78'h2711729bb55002000000;
            8'd100: segment = 78'h29bb56ae221002000000;
            8'd101: segment = 78'h2ae222c0965002000000;
            8'd102: segment = 78'h2c0966c9101002000000;
            8'd103: segment = 78'h2c9102d0e11002000000;
            8'd104: segment = 78'h2d0e12e41a9002000000;
            8'd105: segment = 78'h2e41aaecf8d002000000;
            8'd106: segment = 78'h2ecf8fffffd002000000;
            8'd128: segment = 78'h00000003900000000000;
            8'd129: segment = 78'h00390014cc4000000000;
            8'd130: segment = 78'h014cc431b78000000000;
            8'd131: segment = 78'h031b7844ec8000000000;
            8'd132: segment = 78'h044ec86c33c000000000;
            8'd133: segment = 78'h06c33c804c0000000000;
            8'd134: segment = 78'h0804c092a54000000000;
            8'd135: segment = 78'h092a549a0e0000000000;
            8'd136: segment = 78'h09a0e0b00a0000000000;
            8'd137: segment = 78'h0b00a0b86c8000000000;
            8'd138: segment = 78'h0b86c8f1554000200240;
            8'd139: segment = 78'h0f1555040401004006da;
            8'd140: segment = 78'h1040412b5c82007004e1;
            8'd141: segment = 78'h12b5c93dd783809006ed;
            8'd142: segment = 78'h13dd7951c14480b0066e;
            8'd143: segment = 78'h151c155a7dc580c00753;
            8'd144: segment = 78'h15a7dd6bb10600e00771;
            8'd145: segment = 78'h16bb11944c07011004ba;
            8'd146: segment = 78'h1944c19d8b08812006ec;
            8'd147: segment = 78'h19d8b1b0b289014006af;
            8'd148: segment = 78'h1b0b29b5d30a01500c7c;
            8'd149: segment = 78'h1b5d31c5870a81700827;
            8'd150: segment = 78'h1c5871d0274b81800606;
            8'd151: segment = 78'h1d0276085ccc01b0036a;
            8'd152: segment = 78'h2085ce129b8d81c0063f;
            8'd153: segment = 78'h2129ba209d4e01e00923;
            8'd154: segment = 78'h2209d633c94f020006ad;
            8'd155: segment = 78'h233c963c1850021007b4;
            8'd156: segment = 78'h23c1864ce6508230079e;
            8'd157: segment = 78'h24ce6654e8d182300000;
            8'd158: segment = 78'h254e8e6631d182300000;
            8'd159: segment = 78'h26631e90629182300000;
            8'd160: segment = 78'h29062aa3049182300000;
            8'd161: segment = 78'h2a304ab6645182300000;
            8'd162: segment = 78'h2b6646c6869182300000;
            8'd163: segment = 78'h2c686ad09cd182300000;
            8'd164: segment = 78'h2d09cee6285182300000;
            8'd165: segment = 78'h2e6286f7571182300000;
            8'd166: segment = 78'h2f7573ffffd182300000;
            8'd192: segment = 78'h00000003d2c000000000;
            8'd193: segment = 78'h003d2c15840000000000;
            8'd194: segment = 78'h0158401c6e0000000000;
            8'd195: segment = 78'h01c6e039624000000000;
            8'd196: segment = 78'h0396244bf84000000000;
            8'd197: segment = 78'h04bf8474238000000000;
            8'd198: segment = 78'h074238895bc000000000;
            8'd199: segment = 78'h0895bc993a8000000000;
            8'd200: segment = 78'h0993a8a13e8000000000;
            8'd201: segment = 78'h0a13e8c156c0001001fe;
            8'd202: segment = 78'h0c156cc8c6408020089b;
            8'd203: segment = 78'h0c8c64fc41410040027d;
            8'd204: segment = 78'h0fc415065cc200500655;
            8'd205: segment = 78'h1065cd119842806005b3;
            8'd206: segment = 78'h11198521e003008007dd;
            8'd207: segment = 78'h121e0126af8400900d4e;
            8'd208: segment = 78'h126af94d27c480c004fe;
            8'd209: segment = 78'h14d27d61634600e00654;
            8'd210: segment = 78'h16163569488700f0081b;
            8'd211: segment = 78'h16948976160781000500;
            8'd212: segment = 78'h176161810bc8011005d7;
            8'd213: segment = 78'h1810bda65b0881400525;
            8'd214: segment = 78'h1a65b1b80e8a0160073b;
            8'd215: segment = 78'h1b80e9c7d6cb0180081c;
            8'd216: segment = 78'h1c7d6dd3d60c01900556;
            8'd217: segment = 78'h1d3d61e3570c81b00842;
            8'd218: segment = 78'h1e3571e85e0d81c00cbb;
            8'd219: segment = 78'h1e85e1f3b78e01d005a4;
            8'd220: segment = 78'h1f3b79fb528e81e0086a;
            8'd221: segment = 78'h1fb52a05e30f01f0060f;
            8'd222: segment = 78'h205e321a3e0f8210064a;
            8'd223: segment = 78'h21a3e2229a90822007a7;
            8'd224: segment = 78'h2229aa26fed102300e93;
            8'd225: segment = 78'h226fee63335182600330;
            8'd226: segment = 78'h2633366e5613027005bf;
            8'd227: segment = 78'h26e56282fd9382900632;
            8'd228: segment = 78'h282fdaa4ff9482900000;
            8'd229: segment = 78'h2a4ffab53d9482900000;
            8'd230: segment = 78'h2b53dab9e19482900000;
            8'd231: segment = 78'h2b9e1ad82bd482900000;
            8'd232: segment = 78'h2d82beea839482900000;
            8'd233: segment = 78'h2ea83afce2d482900000;
            8'd234: segment = 78'h2fce2f055c9482900000;
            8'd235: segment = 78'h3055cb17959482900000;
            8'd236: segment = 78'h31795b1c711482900000;
            8'd237: segment = 78'h31c713ffffd482900000;
            default: segment = {20'd0,20'hfffff,11'd0,11'd0,16'd0};
        endcase
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cursor <= 0; current_picture <= 0;
            scroll_target <= 0; previous_samples <= 0;
        end else begin
            current_picture <= picture; previous_samples <= samples;
            if (restart || !playing || current_picture != picture || samples < previous_samples) begin
                cursor <= 0; scroll_target <= 0;
            end else begin
                scroll_target <= interpolated;
                if (samples >= last_sample && cursor != 63 && last_sample != 20'hfffff)
                    cursor <= cursor + 1'b1;
            end
        end
    end
endmodule
