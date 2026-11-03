`timescale 1ns/1ps

module tb_sd_audio_arbiter;
    reg clk = 0, rst = 1;
    always #5 clk = ~clk;
    reg scan_req = 0, image_req = 0, wav_req = 0, physical_done = 0;
    reg [31:0] scan_lba = 200, image_lba = 300;
    wire scan_done, image_done, wav_done;
    integer completions = 0;
    sd_card_bmp dut (
        .clk(clk), .rst(rst), .key_next(1'b1), .key_auto(1'b1),
        .bmp_width(16'd640), .bmp_height(16'd480), .sdr_init_done(1'b1),
        .next_req_gated(1'b0), .wav_sd_req(wav_req), .wav_sd_lba(32'd100),
        .wav_sd_busy(), .wav_sd_valid(), .wav_sd_byte(), .wav_sd_byte_index(),
        .wav_sd_done(wav_done), .wav_sd_error(), .write_finish_toggle(1'b0),
        .write_req_ack(1'b0), .SD_MISO(1'b1)
    );
    assign scan_done = dut.scanner_sector_done;
    assign image_done = dut.streamer_sector_done;

    task serve(input integer expected_lba, input integer owner);
        begin
            wait(dut.sd_sec_read);
            @(negedge clk);
            if (dut.sd_sec_read_addr !== expected_lba)
                $fatal(1, "Granted LBA %0d expected %0d", dut.sd_sec_read_addr, expected_lba);
            repeat (20) @(negedge clk);
            physical_done = 1;
            #1;
            if ({scan_done, image_done, wav_done} !== (owner == 1 ? 3'b100 : owner == 2 ? 3'b010 : 3'b001))
                $fatal(1, "Response routed to wrong client");
            @(negedge clk); physical_done = 0;
            completions = completions + 1;
        end
    endtask

    initial begin
        force dut.scanner_sector_req = scan_req;
        force dut.scanner_sector_lba = scan_lba;
        force dut.streamer_sector_req = image_req;
        force dut.streamer_sector_lba = image_lba;
        force dut.sd_sec_read_end = physical_done;
        force dut.sd_sec_read_data_valid = 1'b0;
        repeat (5) @(negedge clk); rst = 0;
        @(negedge clk); wav_req = 1;
        @(negedge clk); wav_req = 0;
        wait(dut.arb_owner == 3);
                                                                           
        @(negedge clk); scan_req = 1; image_req = 1;
        @(negedge clk); scan_req = 0; image_req = 0;
                                                                                  
        scan_lba = 201; image_lba = 301;
    end

    initial begin
        wait(!rst);
        serve(100, 3);
        serve(200, 1);
        serve(300, 2);
        $display("PASS SD arbiter: simultaneous one-cycle requests queued, LBA latched, responses isolated");
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "SD request lost: completed %0d of 3 transactions", completions);
    end
endmodule
