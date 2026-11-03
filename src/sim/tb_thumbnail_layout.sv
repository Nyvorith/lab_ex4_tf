`timescale 1ns/1ps

module tb_thumbnail_layout;
    reg in_de = 1'b1;
    reg [11:0] x = 0, y = 0;
    reg [1:0] focus = 2'd0;
    reg [3:0] complete = 4'b1111;
    wire thumb_de, focus_border;
    wire [1:0] source_index;
    wire [9:0] source_x, source_y;

    thumbnail_layout dut(
        .in_de(in_de), .pixel_x(x), .pixel_y(y), .focus_index(focus),
        .image_complete(complete), .thumb_de(thumb_de),
        .source_index(source_index), .source_x(source_x),
        .source_y(source_y), .focus_border(focus_border)
    );

    task check;
        input integer tx, ty;
        input [1:0] expected_index;
        input integer expected_x, expected_y;
        input expected_de, expected_border;
        begin
            x = 12'hfff; y = 12'hfff; #1;
            x = tx; y = ty; #1;
            if (source_index !== expected_index || source_x !== expected_x ||
                source_y !== expected_y || thumb_de !== expected_de ||
                focus_border !== expected_border)
                $fatal(1, "x=%0d y=%0d got idx=%0d src=(%0d,%0d) de=%b border=%b",
                       tx, ty, source_index, source_x, source_y,
                       thumb_de, focus_border);
        end
    endtask

    initial begin
        check(0, 0, 2'd0, 0, 0, 1'b1, 1'b1);
        check(159, 119, 2'd0, 636, 476, 1'b1, 1'b1);
        check(160, 0, 2'd1, 0, 0, 1'b1, 1'b0);
        check(0, 120, 2'd2, 0, 0, 1'b1, 1'b0);
        check(160, 120, 2'd3, 0, 0, 1'b1, 1'b0);
        check(319, 239, 2'd3, 636, 476, 1'b1, 1'b0);
        check(320, 0, 2'd1, 0, 0, 1'b0, 1'b0);
        complete = 4'b0101;
        check(160, 0, 2'd1, 0, 0, 1'b0, 1'b0);
        $display("PASS thumbnail layout: 2x2 mapping, nearest-neighbour coordinates, completion gating, focus border");
        $finish;
    end
endmodule
