`timescale 1ns/1ps

module tb_top_audio_waveform;
    reg clk = 0, rst_n = 0;
    always #10 clk = ~clk;
                                                                              
    top #(.THUMBNAIL_MODE(1'b0), .AUDIO_ENABLE(1'b1), .CAPTION_ENABLE(1'b0), .GUIDE_WAVE_ENABLE(0)) dut (
        .clk(clk), .rst_n(rst_n), .key2(1'b1), .key3(1'b1), .key4(1'b1), .sd_miso(1'b1)
    );
    reg [11:0] scan_x = 224;
    reg scan_de = 0, scan_vs = 1, audio_enable = 1, audio_valid = 0;
    reg signed [15:0] audio_sample = 16'h4000;
    integer i, row;

    task cycle;
        begin
            @(posedge clk); #1;
            @(negedge clk);
        end
    endtask

    task new_frame;
        begin
            scan_de = 0; scan_vs = 0;
            cycle; cycle;
            scan_vs = 1;
            cycle;
        end
    endtask

    task check_pixel(input integer px, input [23:0] expected);
        begin
            scan_x = px;
            @(posedge clk); #1;
            if (dut.vout_data !== expected || dut.de !== scan_de)
                $fatal(1, "Top row=%0d raw_x=%0d rgb=%h expected=%h de=%b",
                       row, px, dut.vout_data, expected, dut.de);
            @(negedge clk);
        end
    endtask

    initial begin
        force dut.por_done = 1'b1;
        force dut.raw_x = scan_x;
        force dut.raw_de = scan_de;
        force dut.raw_vs = scan_vs;
        force dut.reader_pixel_rgb = 24'h808080;
        force dut.adjusted_rgb = 24'h7f7f7f;
        force dut.preview_mode_q = 1'b0;
        force dut.reader_pixel_valid = 1'b1;
        force dut.display_valid = 1'b1;
        force dut.fade_alpha = 8'd255;
        force dut.wipe_active = 1'b0;
        force dut.wav_active_v = audio_enable;
        force dut.wav_sample_valid = audio_valid;
        force dut.wav_mono_16 = audio_sample;
        repeat (20) cycle;
        rst_n = 1;
        repeat (20) cycle;
        if (dut.DIAG_MODE != 0) $fatal(1, "Top still in diagnostic mode");
        new_frame;
        for (i = 0; i < 384; i = i + 1) begin
            audio_valid = 1; cycle;
            audio_valid = 0; cycle;
        end
        new_frame;
        for (row = 0; row < 465; row = row + 1) begin
            scan_de = 1;
            if (row == 416) begin
                                                                          
                check_pixel(223, 24'h7f7f7f);
                check_pixel(224, 24'h20ff90);
                check_pixel(735, 24'h20ff90);
                check_pixel(736, 24'h7f7f7f);
                audio_enable = 0;
                check_pixel(224, 24'h7f7f7f);
                audio_enable = 1;
            end else if (row == 432) begin
                check_pixel(224, 24'h406060);
            end else if (row == 448) begin
                check_pixel(744, 24'hffb020);
            end else if (row == 464) begin
                check_pixel(744, 24'h7f7f7f);
            end else cycle;
            scan_de = 0;
            check_pixel(224, 24'h000000);
        end
        $display("PASS top waveform: WAV tap, x-origin, OSD-to-waveform-to-adapter, enable, one-cycle RGB/DE alignment");
        $finish;
    end

    initial begin
        #1000000;
        $fatal(1, "Top waveform test timed out");
    end
endmodule
