`timescale 1ns/1ps
module tb_audio_control;
    reg clk = 0, rst_n = 0;
    always #10 clk = ~clk;
    top stopped (.clk(clk), .rst_n(rst_n), .key2(1'b1),
                 .key3(1'b1), .key4(1'b1), .sd_miso(1'b1));
    top #(.AUDIO_ENABLE(1'b1)) playing (.clk(clk), .rst_n(rst_n),
                 .key2(1'b1), .key3(1'b1), .key4(1'b1), .sd_miso(1'b1));
    integer ticks = 0;
    initial begin
        force stopped.por_done = 1'b1;
        force playing.narration_has_picture = 1'b1;
        force playing.por_done = 1'b1;
        force stopped.audio_file_valid = 1'b1;
        force playing.narration_valid = 4'b1111;
        force playing.narration_clusters = {4{32'd100}};
        force playing.narration_sizes = {4{32'd5120}};
        force stopped.audio_start_lba = 32'd100;
        force playing.audio_start_lba = 32'd100;
        force stopped.audio_total_sectors = 32'd10;
        force playing.audio_total_sectors = 32'd10;
        force playing.audio_data_start_lba = 32'd100;
        force playing.audio_sectors_per_cluster = 8'd1;
        repeat (20) @(negedge clk);
        rst_n = 1;
        repeat (3000) @(negedge clk);
        if (stopped.wav_play_en !== 0 || stopped.wav_sd_req !== 0 ||
            stopped.u_wav_stream_player.wstate !== 0)
            $fatal(1, "Stopped music started TF reads");
        if (playing.wav_play_en !== 1 || playing.u_wav_stream_player.wstate == 0)
            $fatal(1, "Enabled music did not start");
        if (stopped.audio_status !== 0 || playing.audio_status !== 2)
            $fatal(1, "Stopped/prefill status");
        force playing.narration_valid = 0;
        repeat (10) @(negedge clk);
        if (playing.audio_status !== 1) $fatal(1, "Missing file status");
        force playing.narration_valid = 4'b1111;
        force playing.narration_clusters = {4{32'd100}};
        force playing.narration_sizes = {4{32'd5120}};
        force playing.wav_samples_consumed = 32'd100;
        force playing.wav_buffer_empty = 1'b0;
        repeat (10) @(negedge clk);
        if (playing.audio_status !== 3) $fatal(1, "Playing status");
        force playing.wav_buffer_empty = 1'b1;
        #1;
        if (playing.audio_status !== 4) $fatal(1, "Empty buffer status");
        force playing.wav_sample_valid = 1'b1;
        force playing.wav_mono_16 = -16'sd4096;
        #1;
        if (playing.mux_left_16 !== -16'sd4096 || playing.wav_ready !== 1)
            $fatal(1, "Enabled source selection");
        repeat (1200) begin
            @(negedge clk);
            if (stopped.audio_valid) begin
                ticks = ticks + 1;
                if (stopped.audio_left_data !== 0 || stopped.audio_right_data !== 0)
                    $fatal(1, "Stopped HDMI output not silent");
            end
            if (stopped.wav_sd_req !== 0) $fatal(1, "Stopped TF request");
        end
        if (ticks < 2) $fatal(1, "Silent HDMI sample clock stopped");
        $display("PASS audio control: no stopped TF reads, silent HDMI clock, enabled source, status 0..4");
        $finish;
    end
    initial begin #500000; $fatal(1, "Timeout"); end
endmodule
