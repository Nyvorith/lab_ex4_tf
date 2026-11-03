`timescale 1ns/1ps

module tb_wav_stream_regression;
    reg wr_clk = 0, rd_clk = 0, rst_n = 0, play = 0;
    always #5 wr_clk = ~wr_clk;
    always #13 rd_clk = ~rd_clk;
    reg [31:0] sectors = 24;
    wire req, ended;
    wire [31:0] lba, counter;
    reg busy = 0, byte_valid = 0, sector_done = 0;
    reg [7:0] byte_data = 0;
    reg [8:0] byte_index = 0;
    reg tick = 0, ready = 0;
    wire signed [15:0] sample;
    wire valid;
    integer tick_count = 0, consumed = 0, requests = 0, run_id = 0;
    integer r, s, b, k;
    reg [15:0] word_value;

    function [15:0] expected(input integer index);
        expected = index % 2 ? -1000 - index % 251 : 1000 + index % 251;
    endfunction

    wav_stream_player #(.ADDR_WIDTH(9)) dut (
        .wr_clk(wr_clk), .wr_rst_n(rst_n), .play_enable(play),
        .start_lba(32'd100), .total_sectors(sectors), .sd_req(req), .sd_lba(lba),
        .sd_busy(busy), .sd_valid(byte_valid), .sd_byte(byte_data),
        .sd_byte_index(byte_index), .sd_done(sector_done), .sd_error(8'd0),
        .rd_clk(rd_clk), .rd_rst_n(rst_n), .sample_tick(tick),
        .sample_out(sample), .sample_valid(valid), .sample_ready(ready),
        .sample_counter(counter), .stream_active(), .stream_end(ended), .buffer_low()
    );

    always @(negedge rd_clk) begin
        tick_count = tick_count + 1;
        tick = (tick_count % 32 == 0);
        if (valid && sample == 0 && consumed > 0 && consumed < sectors * 256)
            $fatal(1, "Unexpected wrap underflow at sample %0d", consumed);
        if (valid && sample != 0) begin
            if (sample !== expected(consumed))
                $fatal(1, "run %0d sample %0d got %h expected %h", run_id,
                       consumed, sample, expected(consumed));
            consumed = consumed + 1;
        end
        if (ended && consumed != sectors * 256)
            $fatal(1, "Premature end: consumed %0d of %0d", consumed, sectors * 256);
    end

    initial begin : responder
        for (r = 0; r < 3; r = r + 1) begin
            wait(play);
            for (s = 0; s < sectors; s = s + 1) begin
                wait(req);
                wait(!req);
                @(negedge wr_clk);
                if (lba !== 100 + s) $fatal(1, "LBA %0d expected %0d", lba, 100+s);
                requests = requests + 1;
                busy = 1;
                                                                                   
                repeat (s == 0 ? 200 : 7) @(negedge wr_clk);
                for (b = 0; b < 512; b = b + 1) begin
                    word_value = expected(s*256 + b/2);
                    byte_index = b;
                    byte_data = b % 2 ? word_value[15:8] : word_value[7:0];
                    byte_valid = 1;
                    @(negedge wr_clk); byte_valid = 0;
                    @(negedge wr_clk);
                end
                sector_done = 1;
                @(negedge wr_clk); sector_done = 0; busy = 0;
            end
            wait(!play);
        end
    end

    initial begin
        repeat (8) @(negedge wr_clk);
        rst_n = 1;
        for (k = 0; k < 3; k = k + 1) begin
            run_id = k;
            sectors = k == 2 ? 1 : 24;
            consumed = 0; requests = 0; ready = 0;
            @(negedge wr_clk); play = 1;
            repeat (20000) @(negedge wr_clk);
            if (requests > 1)
                $fatal(1, "No buffer backpressure: %0d sectors requested with consumer stopped", requests);
            @(negedge rd_clk); ready = 1;
            wait(ended);
            @(negedge rd_clk);
            if (counter != sectors*256 || consumed != sectors*256)
                $fatal(1, "Sample count mismatch %0d/%0d", counter, consumed);
            repeat (100) @(negedge rd_clk);
            if (sample !== 0) $fatal(1, "Drained stream did not become silent");
            play = 0;
            repeat (20) @(negedge wr_clk);
            if (counter != 0) $fatal(1, "Restart did not clear sample count");
        end
        $display("PASS WAV: backpressure, byte order, 12 FIFO wraps, unrelated clocks, full drain, replay, one-sector clip");
        $finish;
    end
    initial begin
        #30000000;
        $fatal(1, "WAV regression timed out");
    end
endmodule
