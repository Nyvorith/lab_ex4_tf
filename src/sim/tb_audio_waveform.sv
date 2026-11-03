`timescale 1ns/1ps

module tb_audio_waveform;
    reg clk = 0, rst_n = 0;
    always #5 clk = ~clk;
    reg vsync = 1, de = 0, enable = 1, pcm_valid = 0;
    reg [9:0] x = 0;
    reg signed [15:0] pcm = 0;
    wire [23:0] rgb;
    wire active;
    integer i, row;

    promax_audio_waveform dut (
        .clk(clk), .rst_n(rst_n), .vsync(vsync), .de(de),
        .rgb_in(24'h123456), .pixel_x(x), .enable(enable),
        .pcm_tap_valid(pcm_valid), .pcm_tap_left(pcm),
        .rgb_out(rgb), .waveform_active(active)
    );

    task new_frame;
        begin
            @(negedge clk); de = 0; vsync = 0;
            repeat (2) @(negedge clk);
            vsync = 1;
            @(negedge clk);
        end
    endtask

    task audio(input integer sample);
        begin
            @(negedge clk); pcm = sample * 256; pcm_valid = 1;
            @(negedge clk); pcm_valid = 0; pcm = 16'h7fff;
        end
    endtask

    task check(input integer px, input [23:0] expected, input bit expected_active);
        begin
            x = px;
            #1;
            if (rgb !== expected || active !== expected_active)
                $fatal(1, "row=%0d x=%0d got=%h active=%b expected=%h active=%b",
                       row, px, rgb, active, expected, expected_active);
        end
    endtask

    initial begin
        repeat (3) @(negedge clk);
        rst_n = 1;
        new_frame;
        for (i = 0; i < 384; i = i + 1) begin
            if (i % 12 != 0) audio(127);
            else if (i / 12 == 0) audio(64);
            else if (i / 12 == 1) audio(-64);
            else if (i / 12 == 31) audio(-128);
            else audio(32);
        end
        if (dut.capture_count != 32 || dut.display_valid)
            $fatal(1, "Capture/decimation published before frame boundary");
        new_frame;
        if (!dut.display_valid || dut.display_peak != 128)
            $fatal(1, "Full capture did not publish its signed peak");

        for (row = 0; row < 465; row = row + 1) begin
            de = 1;
            check(63, 24'h123456, 0);
            if (row == 416) begin
                check(64, 24'h20ff90, 1);
                check(79, 24'h20ff90, 1);
                check(80, 24'h123456, 0);
            end
            if (row == 432) begin
                check(64, 24'h406060, 1);
                check(575, 24'h406060, 1);
                check(576, 24'h123456, 0);
                check(584, 24'hffb020, 1);
                check(591, 24'hffb020, 1);
                check(592, 24'h123456, 0);
                enable = 0;
                check(584, 24'h123456, 0);
                enable = 1;
            end
            if (row == 448) check(80, 24'h20ff90, 1);
            if (row == 463) check(575, 24'h20ff90, 1);
            if (row == 464) begin
                check(575, 24'h123456, 0);
                check(584, 24'h123456, 0);
            end
            @(negedge clk); de = 0;
            check(64, 24'h123456, 0);
            @(negedge clk);
        end

                                                                             
        audio(127);
        new_frame;
        if (dut.display_peak != 128)
            $fatal(1, "Incomplete capture replaced the displayed frame");
        for (i = 0; i < 384; i = i + 1) audio(16);
        if (dut.display_peak != 128)
            $fatal(1, "Capture changed the displayed peak mid-frame");
        new_frame;
        if (dut.display_peak != 16)
            $fatal(1, "Peak retained data from an incomplete capture");

        for (i = 0; i < 384; i = i + 1) audio(0);
        new_frame;
        if (dut.display_peak != 0)
            $fatal(1, "Silence did not clear peak");
        $display("PASS waveform: decimation, signed PCM, edges, blanking, disable, bank swaps, partial frame, silence");
        $finish;
    end

    initial begin
        #1000000;
        $fatal(1, "Waveform test timed out");
    end
endmodule
