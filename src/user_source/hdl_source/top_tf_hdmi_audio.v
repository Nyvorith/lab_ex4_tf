module top(
    input                       clk,
    input                       rst_n,
    input                       key2,
    input                       key3,
    input                       key4,

	output [5:0]                seg_sel,
	output [7:0]                seg_data,

    output                      HDMI_CLK_P,
    output                      HDMI_D2_P,
    output                      HDMI_D1_P,
    output                      HDMI_D0_P,

    output                      HDMI_DDC_SCL,
    inout                       HDMI_DDC_SDA,

    output                      sd_ncs,
    output                      sd_dclk,
    output                      sd_mosi,
    input                       sd_miso
);

parameter MEM_DATA_BITS = 32;
parameter ADDR_BITS     = 21;
parameter BUSRT_BITS    = 10;
parameter FRAME_PIXELS  = 24'd307200;
parameter BUF0_ADDR     = 24'd0;
parameter BUF1_ADDR     = FRAME_PIXELS;

parameter THUMBNAIL_MODE = 1'b0;

parameter AUDIO_ENABLE = 1'b0;
parameter CAPTION_ENABLE = 1'b1;
parameter GUIDE_WAVE_ENABLE = 1'b1;

localparam [1:0] DIAG_MODE = 2'd0;

localparam DIAG_BAR  = (DIAG_MODE == 2'd1);
localparam DIAG_LOOP = (DIAG_MODE == 2'd2);

wire Sdr_init_done;
wire Sdr_init_ref_vld;
wire Sdr_busy;

wire sd_card_clk;
wire ext_mem_clk;
wire ext_mem_clk_sft;
wire video_clk;
wire hdmi_5x_clk;

wire hs;
wire vs;
wire de;

wire [23:0] vout_data_raw;
wire [23:0] vout_data;
wire        display_valid;
wire        load_failed_tgl;
wire        reading_done_tgl;
reg reading_sd1, reading_sd2, reading_sd3;
wire [1:0] reading_done_index;
reg [1:0] reading_index_sd1, reading_index_sd2;
wire reading_event_sd;
wire        image_loading_sd;
reg         image_loading_v1, image_loading_v2;
wire [31:0] committed_source_size;
wire [19:0] committed_fitted_size;

wire [3:0]  state_code;
wire [6:0]  seg_data_0;

wire        auto_play_en_sd;

wire [7:0] brightness_cfg;
wire [7:0] contrast_cfg;
wire preview_mode_sd;
wire [1:0] preview_focus_sd;
wire [3:0] preview_loaded_sd, preview_available_sd;
wire preview_capture_start;
wire [1:0] preview_capture_index;
reg [1:0] preview_mode_sync;
reg [1:0] preview_focus_v1, preview_focus_v2, preview_focus_q;
reg [3:0] preview_ready_v1, preview_ready_v2, preview_ready_q;
reg [3:0] preview_avail_v1, preview_avail_v2, preview_avail_q;
reg preview_mode_q;
reg [1:0] preview_enable_sync;
wire [23:0] preview_rgb;
reg  [7:0] brightness_v1, brightness_v2;
reg  [7:0] contrast_v1, contrast_v2;
reg  [7:0] brightness_q, contrast_q;

wire        key_next_req;
wire        fade_next_event;
wire        index_commit_tgl;
wire        fade_busy;
wire [7:0]  fade_alpha;
wire        fade_active;
wire        wipe_active;
wire [4:0]  wipe_ramp;
wire [1:0]  transition_kind;

wire [3:0]  err_code_sd;
wire [3:0]  err_code;
wire [6:0]  seg_data_err;

wire        sd_card_write_en;
wire [31:0] sd_card_write_data;
wire        sd_card_write_req;
wire        sd_card_write_req_ack;
reg         frame_write_toggle_mem;

wire [1:0]  write_buf_idx;
wire [1:0]  disp_buf_idx;

wire        pix_fifo_rst;
wire        pix_fifo_valid;
wire [31:0] pix_fifo_dout;
wire        pix_fifo_full;
reg  [3:0]  pix_fifo_flush;

reg         loader_load_start;
wire        loader_load_done;
wire        loader_pixel_ready;
wire        loader_load_busy;
wire        loader_app_wr_en;
wire [ADDR_BITS-1:0]     loader_app_wr_addr;
wire [MEM_DATA_BITS-1:0] loader_app_wr_data;
wire [3:0]  loader_app_wr_mask;
wire [7:0]  loader_memory_error;
wire [3:0]  loader_image_complete;

reg         sd_wreq_d;
reg         load_req_tgl_sd;
reg         load_req_tgl_m1, load_req_tgl_m2, load_req_tgl_m3;
reg  [1:0]  write_idx_m1, write_idx_m2, loader_img_idx;
reg  [1:0]  disp_idx_v1, disp_idx_v2;

wire Sdr_rd_en;
wire [MEM_DATA_BITS-1:0] Sdr_rd_dout;

wire loader_wr_burst_active;
wire loader_wr_start_intent;
wire reader_rd_burst_active;
wire reader_rd_start_intent;
wire reader_writer_window_safe;
wire bus_grant_wr;
wire bus_grant_rd;

assign bus_grant_wr = loader_wr_start_intent && !reader_rd_burst_active &&
                      !reader_rd_start_intent && reader_writer_window_safe;
assign bus_grant_rd = reader_rd_start_intent && !loader_wr_burst_active;

wire        reader_app_rd_en;
wire [ADDR_BITS-1:0] reader_app_rd_addr;
wire [MEM_DATA_BITS-1:0] reader_sdram_rd_data;
wire        reader_sdram_rd_valid;
wire        reader_pixel_valid;
wire [23:0] reader_pixel_rgb;
wire        reader_underflow;
wire [7:0]  reader_error;

wire [11:0] raw_x;
wire [11:0] raw_y;
wire        raw_hs;
wire        raw_vs;
wire        raw_de;
reg         raw_vs_q;
wire        reader_frame_start;
wire        reader_pixel_consume;
wire [11:0] display_x = raw_x - 12'd160;
wire [11:0] display_y = raw_y - 12'd45;
wire [1:0]  osd_index;
wire        thumb_slot_de = raw_de && (display_x < 12'd320) &&
                            (display_y < 12'd240);
wire        thumb_de;
wire [1:0]  thumb_source_index;
wire [9:0]  thumb_source_x;
wire [9:0]  thumb_source_y;
wire        thumb_focus_border;

wire        axis_s_user;
wire        axis_s_valid;
wire        axis_s_last;
wire [23:0] axis_s_data;
wire        axis_s_ready;

wire        edid_trig;
wire        edid_valid;
wire [7:0]  edid_data;

wire [9:0]  tmds_ch0_data;
wire [9:0]  tmds_ch1_data;
wire [9:0]  tmds_ch2_data;
wire [9:0]  tmds_clk_data;

wire        audio_valid;
wire [23:0] audio_left_data;
wire [23:0] audio_right_data;
wire        acr_valid;
wire [19:0] acr_cts;
wire [19:0] acr_n;
wire signed [15:0] audio_left_16;
wire signed [15:0] audio_right_16;

wire signed [15:0] tone_left_16;
wire signed [15:0] tone_right_16;
wire               arp_valid;
wire               arp_ready;

wire           wav_sd_req;
wire [31:0]    wav_sd_lba;
wire           wav_sd_busy;
wire           wav_sd_valid;
wire [7:0]     wav_sd_byte;
wire [8:0]     wav_sd_byte_index;
wire           wav_sd_done;
wire [7:0]     wav_sd_error;
wire [3:0] narration_valid;
wire [127:0] narration_clusters, narration_sizes;
wire narration_toggle;
reg narration_enabled;
wire audio_enabled = narration_enabled;
reg [1:0] narration_image_pix;
reg narration_commit_pix;
reg narration_has_picture;
reg [1:0] narration_picture_sd;
reg [1:0] narration_commit_sd, narration_image_s1, narration_image_s2;
reg narration_seen;
reg [1:0] narration_selected;
reg [1:0] narration_state;
reg [10:0] narration_settle;
reg narration_finished;
reg [31:0] narration_offset;
reg [2:0] narration_shift;
reg [31:0] narration_lba, narration_cluster, narration_size, narration_sectors;
wire narration_stopped;
reg [1:0] narration_end_sd;
wire narration_track_valid = narration_valid[narration_selected];
wire           audio_file_valid;
wire [31:0]    audio_start_lba;
wire [31:0]    audio_total_sectors;
wire [31:0]    audio_first_cluster;
wire [31:0]    audio_file_size;
wire [7:0]     audio_sectors_per_cluster;
wire [31:0]    audio_fat_start_lba;
wire [31:0]    audio_data_start_lba;
wire [31:0]    audio_max_cluster;

reg            sample_tick;
wire signed [15:0] wav_mono_16;
wire           wav_sample_valid;
wire           wav_ready;
wire           wav_stream_end;

wire signed [15:0] mux_left_16;
wire signed [15:0] mux_right_16;
wire           mux_valid;
wire [7:0]     audio_gain_aud;
wire signed [15:0] pcm_mono_16;
wire signed [15:0] arp_l_16;
wire signed [15:0] arp_r_16;

reg            wav_active_s1, wav_active_s2;
wire           wav_active_v;
wire           wav_buffer_empty;
wire [31:0]    wav_samples_consumed;
wire [2:0] audio_status = !audio_enabled ? 3'd0 :
                         !wav_active_v ? 3'd1 :
                         (wav_samples_consumed == 0) ? 3'd2 :
                         wav_buffer_empty ? 3'd4 : 3'd3;
reg            wav_play_en;
reg [15:0]     wav_restart_wait;
reg [9:0]      sample_div_cnt;

wire sys_pll_lock;
wire video_pll_lock;

wire pll_locked = sys_pll_lock & video_pll_lock;

reg [19:0] por_cnt  = 20'd0;
reg        por_done = 1'b0;

always @(posedge clk) begin
    if (!rst_n || !pll_locked) begin
        por_cnt  <= 20'd0;
        por_done <= 1'b0;
    end else if (por_cnt < 20'd1_000_000) begin
        por_cnt <= por_cnt + 1'b1;
    end else begin
        por_done <= 1'b1;
    end
end

wire ext_rst_n = rst_n & pll_locked & por_done;

wire sdcard_rst_n;
wire mem_rst_n;
wire video_rst_n;
wire serial_rst_n;
wire clk_rst_n;

reset_sync u_sdcard_reset (
    .clk        (sd_card_clk),
    .ext_rst_n  (ext_rst_n),
    .rst_n_sync (sdcard_rst_n)
);

reset_sync u_mem_reset (
    .clk        (ext_mem_clk),
    .ext_rst_n  (ext_rst_n),
    .rst_n_sync (mem_rst_n)
);

reset_sync u_video_reset (
    .clk        (video_clk),
    .ext_rst_n  (ext_rst_n),
    .rst_n_sync (video_rst_n)
);

reset_sync u_serial_reset (
    .clk        (hdmi_5x_clk),
    .ext_rst_n  (ext_rst_n),
    .rst_n_sync (serial_rst_n)
);

reset_sync u_clk_reset (
    .clk        (clk),
    .ext_rst_n  (ext_rst_n),
    .rst_n_sync (clk_rst_n)
);

image_hold_adjust u_image_hold_adjust (
    .clk        (clk),
    .rst_n      (clk_rst_n),
    .enable     (!preview_enable_sync[1]),
    .key1_n     (key2),
    .key2_n     (key4),
    .brightness (brightness_cfg),
    .contrast   (contrast_cfg)
);

always @(posedge clk or negedge clk_rst_n) begin
    if (!clk_rst_n)
        preview_enable_sync <= 2'b00;
    else
        preview_enable_sync <= {preview_enable_sync[0], preview_mode_sd};
end

always @(posedge video_clk or negedge video_rst_n) begin
    if (!video_rst_n) begin
        preview_mode_sync <= 0;
        preview_focus_v1 <= 0; preview_focus_v2 <= 0; preview_focus_q <= 0;
        preview_ready_v1 <= 0; preview_ready_v2 <= 0; preview_ready_q <= 0;
        preview_avail_v1 <= 0; preview_avail_v2 <= 0; preview_avail_q <= 0;
        preview_mode_q <= 0;
    end else begin
        preview_mode_sync <= {preview_mode_sync[0], preview_mode_sd};
        preview_focus_v1 <= preview_focus_sd;
        preview_focus_v2 <= preview_focus_v1;
        preview_ready_v1 <= preview_loaded_sd;
        preview_ready_v2 <= preview_ready_v1;
        preview_avail_v1 <= preview_available_sd;
        preview_avail_v2 <= preview_avail_v1;
        if (reader_frame_start) begin
            preview_mode_q <= preview_mode_sync[1];
            preview_focus_q <= preview_focus_v2;
            preview_ready_q <= preview_ready_v2;
            preview_avail_q <= preview_avail_v2;
        end
    end
end

thumbnail_wall_cache #(.INTRO_CARD(1)) u_thumbnail_wall_cache (
    .capture_clk (sd_card_clk),
    .capture_rst_n (sdcard_rst_n),
    .capture_start (preview_capture_start),
    .capture_index (preview_capture_index),
    .pixel_valid (sd_card_write_en),
    .pixel_rgb (sd_card_write_data[31:8]),
    .pix_clk (video_clk),
    .in_de (raw_de),
    .pixel_x (display_x),
    .pixel_y (display_y),
    .focus_index (preview_focus_q),
    .image_ready (preview_ready_q),
    .image_available (preview_avail_q),
    .rgb_out (preview_rgb)
);

always @(posedge video_clk or negedge video_rst_n) begin
    if (!video_rst_n) begin
        brightness_v1 <= 8'd220;
        brightness_v2 <= 8'd220;
        contrast_v1   <= 8'd128;
        contrast_v2   <= 8'd128;
        brightness_q  <= 8'd220;
        contrast_q    <= 8'd128;
    end else begin
        brightness_v1 <= brightness_cfg;
        brightness_v2 <= brightness_v1;
        contrast_v1   <= contrast_cfg;
        contrast_v2   <= contrast_v1;
        if (reader_frame_start) begin
            brightness_q <= brightness_v2;
            contrast_q   <= contrast_v2;
        end
    end
end

reg [3:0] state_code_s1, state_code_s2;
reg [3:0] err_code_s1,   err_code_s2;

always @(posedge clk or negedge clk_rst_n) begin
    if (!clk_rst_n) begin
        state_code_s1 <= 4'd0;
        state_code_s2 <= 4'd0;
        err_code_s1   <= 4'd0;
        err_code_s2   <= 4'd0;
    end else begin
        state_code_s1 <= state_code;
        state_code_s2 <= state_code_s1;
        err_code_s1   <= err_code;
        err_code_s2   <= err_code_s1;
    end
end

wire Sdr_init_done_sd;
sync_2ff u_sdram_init_sync (
    .clk        (sd_card_clk),
    .rst_n      (sdcard_rst_n),
    .async_in   (Sdr_init_done),
    .sync_out   (Sdr_init_done_sd)
);

sys_pll sys_pll_m0(
    .refclk     (clk),
    .reset      (~rst_n),
    .extlock    (sys_pll_lock),
    .clk0_out   (sd_card_clk),
    .clk1_out   (ext_mem_clk),
    .clk2_out   (ext_mem_clk_sft)
);

video_pll video_pll_m0(
    .refclk     (clk),
    .reset      (~rst_n),
    .extlock    (video_pll_lock),
    .clk0_out   (video_clk),
    .clk1_out   (hdmi_5x_clk)
);

always @(posedge ext_mem_clk or negedge mem_rst_n) begin
    if (!mem_rst_n)
        frame_write_toggle_mem <= 1'b0;
    else if (loader_load_done)
        frame_write_toggle_mem <= ~frame_write_toggle_mem;
end

assign reading_event_sd = (reading_sd2 ^ reading_sd3) &&
                          (reading_index_sd2 == (state_code[1:0] - 2'd1));
sd_card_bmp #(
    .FULL_FRAME_CACHE  (1),
    .AUTO_FROM_CAPTION (1),
    .AUTO_PREFETCH     (1),
    .MANUAL_PREFETCH   (1),
    .MANUAL_READY_GATE (1),
    .PREVIEW_WARMUP    (1),
    .PREVIEW_FOCUS_PREFETCH (1),
    .CLK_FREQ_HZ       (100_000_000),
    .SCAN_START_SECTOR (32'd0),
    .SCAN_MAX_SECTOR   (32'd131071),
    .SCAN_TARGET_COUNT (3'd4),
    .LOAD_TIMEOUT_MS   (15000),

    .LONG_PRESS_MS     (30_000)
) sd_card_bmp_m0(
    .clk               (sd_card_clk),
    .rst               (~sdcard_rst_n),
    .key_next          (key2),
    .key_auto          (key4),
    .key_mode          (key3),
    .auto_advance_event (reading_event_sd),
    .preview_mode      (preview_mode_sd),
    .preview_focus     (preview_focus_sd),
    .preview_loaded    (preview_loaded_sd),
    .preview_available (preview_available_sd),
    .preview_capture_start (preview_capture_start),
    .preview_capture_index (preview_capture_index),
    .state_code        (state_code),
    .error_code        (err_code_sd),

    .auto_play_out     (auto_play_en_sd),

    .key_next_req      (key_next_req),
    .manual_transition_busy (fade_busy),
    .next_req_gated    (fade_next_event),
    .index_commit_tgl  (index_commit_tgl),
    .load_failed_tgl   (load_failed_tgl),
    .bmp_width         (16'd640),
    .bmp_height        (16'd480),
    .display_valid     (display_valid),
    .image_loading     (image_loading_sd),
    .committed_source_size(committed_source_size),
    .committed_fitted_size(committed_fitted_size),

    .sdr_init_done     (Sdr_init_done_sd),

    .write_finish_toggle(frame_write_toggle_mem),
    .write_buf_idx     (write_buf_idx),
    .disp_buf_idx      (disp_buf_idx),

    .write_req         (sd_card_write_req),
    .write_req_ack     (sd_card_write_req_ack),
    .write_ready       (~pix_fifo_full),
    .write_en          (sd_card_write_en),
    .write_data        (sd_card_write_data),

    .wav_sd_req        (wav_sd_req),
    .wav_sd_lba        (wav_sd_lba),
    .wav_sd_busy       (wav_sd_busy),
    .wav_sd_valid      (wav_sd_valid),
    .wav_sd_byte       (wav_sd_byte),
    .wav_sd_byte_index (wav_sd_byte_index),
    .wav_sd_done       (wav_sd_done),
    .wav_sd_error      (wav_sd_error),
    .narration_valid (narration_valid),
    .narration_clusters (narration_clusters),
    .narration_sizes (narration_sizes),
    .narration_toggle (narration_toggle),
    .audio_valid       (audio_file_valid),
    .audio_start_lba   (audio_start_lba),
    .audio_total_sectors(audio_total_sectors),
    .audio_first_cluster(audio_first_cluster),
    .audio_file_size(audio_file_size),
    .audio_sectors_per_cluster(audio_sectors_per_cluster),
    .audio_fat_start_lba(audio_fat_start_lba),
    .audio_data_start_lba(audio_data_start_lba),
    .audio_max_cluster(audio_max_cluster),
    .SD_nCS            (sd_ncs),
    .SD_DCLK           (sd_dclk),
    .SD_MOSI           (sd_mosi),
    .SD_MISO           (sd_miso)
);

reg  [7:0]  frame_err_mem;
reg  [7:0]  frame_err_sd1, frame_err_sd2;

always @(posedge ext_mem_clk or negedge mem_rst_n) begin
    if (!mem_rst_n)
        frame_err_mem <= 8'd0;
    else begin
        if (loader_memory_error != 8'd0)
            frame_err_mem[0] <= 1'b1;
        if (reader_error != 8'd0 || reader_underflow)
            frame_err_mem[1] <= 1'b1;
    end
end

always @(posedge sd_card_clk or negedge sdcard_rst_n) begin
    if (!sdcard_rst_n) begin
        frame_err_sd1 <= 8'd0;
        frame_err_sd2 <= 8'd0;
    end else begin
        frame_err_sd1 <= frame_err_mem;
        frame_err_sd2 <= frame_err_sd1;
    end
end

assign err_code = frame_err_sd2[1] ? 4'd5 :
                  frame_err_sd2[0] ? 4'd4 : err_code_sd;

function [23:0] diag_pattern;
    input [8:0]  r;
    input [9:0]  c;
    begin
        diag_pattern = {5'b0, r, c};
    end
endfunction

reg  [8:0]  gen_row;
reg  [9:0]  gen_col;
reg         gen_done;
reg         loop_armed;
reg         loop_load_start;

wire        gen_push  = loop_armed && !gen_done && loader_pixel_ready;
wire [23:0] gen_pixel = diag_pattern(9'd479 - gen_row, gen_col);

always @(posedge ext_mem_clk or negedge mem_rst_n) begin
    if (!mem_rst_n) begin
        gen_row         <= 9'd0;
        gen_col         <= 10'd0;
        gen_done        <= 1'b0;
        loop_armed      <= 1'b0;
        loop_load_start <= 1'b0;
    end else begin
        loop_load_start <= 1'b0;

        if (DIAG_LOOP && !loop_armed && !gen_done && !loader_load_busy && Sdr_init_done) begin
            loop_load_start <= 1'b1;
            loop_armed      <= 1'b1;
        end
        if (gen_push) begin
            if (gen_col == 10'd639) begin
                gen_col <= 10'd0;
                if (gen_row == 9'd479)
                    gen_done <= 1'b1;
                else
                    gen_row <= gen_row + 9'd1;
            end else begin
                gen_col <= gen_col + 10'd1;
            end
        end
    end
end

reg  [8:0]  chk_row;
reg  [9:0]  chk_col;
reg  [15:0] chk_frame_cnt;
wire [23:0] chk_exp = diag_pattern(chk_row, chk_col);
wire        chk_ready = DIAG_LOOP && (chk_frame_cnt >= 16'd12);
wire        chk_bad   = chk_ready && raw_de &&
                        (!reader_pixel_valid || (reader_pixel_rgb !== chk_exp));

wire diag_blank_zone = (raw_x >= 12'd560);
wire diag_anom = DIAG_BAR  ? (raw_de && (!reader_pixel_valid ||
                                          (!diag_blank_zone && reader_pixel_rgb == 24'd0)))
               : DIAG_LOOP ? chk_bad
               : 1'b0;
reg        anom_seen;
reg [11:0] anom_x;
reg [11:0] anom_y;

always @(posedge video_clk or negedge video_rst_n) begin
    if (!video_rst_n) begin
        anom_seen     <= 1'b0;
        anom_x        <= 12'd0;
        anom_y        <= 12'd0;
        chk_row       <= 9'd0;
        chk_col       <= 10'd0;
        chk_frame_cnt <= 16'd0;
    end else begin

        if (reader_frame_start) begin
            chk_row <= 9'd0;
            chk_col <= 10'd0;
            if (chk_frame_cnt != 16'hffff)
                chk_frame_cnt <= chk_frame_cnt + 16'd1;
        end else if (raw_de) begin
            if (chk_col == 10'd639) begin
                chk_col <= 10'd0;
                if (chk_row != 9'd479)
                    chk_row <= chk_row + 9'd1;
            end else begin
                chk_col <= chk_col + 10'd1;
            end
        end

        if (diag_anom && !anom_seen) begin
            anom_seen <= 1'b1;

            anom_x    <= DIAG_LOOP ? {2'b00, chk_col} : raw_x;
            anom_y    <= DIAG_LOOP ? {3'b000, chk_row} : raw_y;
        end
    end
end

reg [11:0] anom_x_s1, anom_x_s2;
reg [11:0] anom_y_s1, anom_y_s2;
reg        anom_seen_s1, anom_seen_s2;

always @(posedge clk or negedge clk_rst_n) begin
    if (!clk_rst_n) begin
        anom_x_s1 <= 12'd0; anom_x_s2 <= 12'd0;
        anom_y_s1 <= 12'd0; anom_y_s2 <= 12'd0;
        anom_seen_s1 <= 1'b0; anom_seen_s2 <= 1'b0;
    end else begin
        anom_x_s1 <= anom_x;  anom_x_s2 <= anom_x_s1;
        anom_y_s1 <= anom_y;  anom_y_s2 <= anom_y_s1;
        anom_seen_s1 <= anom_seen; anom_seen_s2 <= anom_seen_s1;
    end
end

wire [3:0] dx2 = anom_x_s2[11:8];
wire [3:0] dx1 = anom_x_s2[7:4];
wire [3:0] dx0 = anom_x_s2[3:0];
wire [3:0] dy2 = anom_y_s2[11:8];
wire [3:0] dy1 = anom_y_s2[7:4];
wire [3:0] dy0 = anom_y_s2[3:0];

wire [6:0] sd_dx2, sd_dx1, sd_dx0, sd_dy2, sd_dy1, sd_dy0;

seg_decoder seg_dec_x2 (.bin_data(dx2), .seg_data(sd_dx2));
seg_decoder seg_dec_x1 (.bin_data(dx1), .seg_data(sd_dx1));
seg_decoder seg_dec_x0 (.bin_data(dx0), .seg_data(sd_dx0));
seg_decoder seg_dec_y2 (.bin_data(dy2), .seg_data(sd_dy2));
seg_decoder seg_dec_y1 (.bin_data(dy1), .seg_data(sd_dy1));
seg_decoder seg_dec_y0 (.bin_data(dy0), .seg_data(sd_dy0));

wire [7:0] disp_dx2 = {1'b1, sd_dx2};
wire [7:0] disp_dx1 = {1'b1, sd_dx1};
wire [7:0] disp_dx0 = {1'b0, sd_dx0};
wire [7:0] disp_dy2 = {1'b1, sd_dy2};
wire [7:0] disp_dy1 = {1'b1, sd_dy1};
wire [7:0] disp_dy0 = anom_seen_s2 ? {1'b0, sd_dy0} : {1'b1, sd_dy0};

seg_decoder seg_decoder_m0(
    .bin_data          (state_code_s2),
    .seg_data          (seg_data_0)
);

seg_decoder seg_decoder_err(
    .bin_data          (err_code_s2),
    .seg_data          (seg_data_err)
);

seg_scan seg_scan_m0(
    .clk               (clk),
    .rst_n             (clk_rst_n),
    .seg_sel           (seg_sel),
    .seg_data          (seg_data),
    .seg_data_0        ((DIAG_MODE != 2'd0) ? disp_dy0 : 8'hff),
    .seg_data_1        ((DIAG_MODE != 2'd0) ? disp_dy1 : 8'hff),
    .seg_data_2        ((DIAG_MODE != 2'd0) ? disp_dy2 : 8'hff),
    .seg_data_3        ((DIAG_MODE != 2'd0) ? disp_dx0 : 8'hff),
    .seg_data_4        ((DIAG_MODE != 2'd0) ? disp_dx1 : {1'b1,seg_data_err}),
    .seg_data_5        ((DIAG_MODE != 2'd0) ? disp_dx2 : {1'b1,seg_data_0})
);

video_timing_ctrl #(
    .H_ACT       (640),
    .H_FP        (16),
    .H_SYNC      (96),
    .H_BP        (48),
    .V_ACT       (480),
    .V_FP        (10),
    .V_SYNC      (2),
    .V_BP        (33),
    .ACTIVE_LAST (1)
) u_video_timing_ctrl(
    .pclk              (video_clk),
    .rst_n             (video_rst_n),
    .hsync             (raw_hs),
    .vsync             (raw_vs),
    .de                (raw_de),
    .x                 (raw_x),
    .y                 (raw_y)
);

always @(posedge video_clk or negedge video_rst_n) begin
    if (!video_rst_n)
        raw_vs_q <= 1'b1;
    else
        raw_vs_q <= raw_vs;
end

assign reader_frame_start    = raw_vs_q && !raw_vs;
assign reader_pixel_consume  = THUMBNAIL_MODE ? thumb_slot_de : raw_de;

thumbnail_layout u_thumbnail_layout(
    .in_de          (raw_de),
    .pixel_x        (display_x),
    .pixel_y        (display_y),
    .focus_index    (osd_index),
    .image_complete (loader_image_complete),
    .thumb_de       (thumb_de),
    .source_index   (thumb_source_index),
    .source_x       (thumb_source_x),
    .source_y       (thumb_source_y),
    .focus_border   (thumb_focus_border)
);

always @(posedge video_clk or negedge video_rst_n) begin
    if (!video_rst_n) begin
        disp_idx_v1 <= 2'd0;
        disp_idx_v2 <= 2'd0;
    end else begin
        disp_idx_v1 <= disp_buf_idx;
        disp_idx_v2 <= disp_idx_v1;
    end
end

reg [3:0] osd_state_v1, osd_state_v2;
reg [3:0] osd_err_v1,   osd_err_v2;
reg       osd_auto_v1,  osd_auto_v2;
always @(posedge video_clk or negedge video_rst_n) begin
    if (!video_rst_n) begin
        image_loading_v1 <= 1'b0;
        image_loading_v2 <= 1'b0;
    end else begin
        image_loading_v1 <= image_loading_sd;
        image_loading_v2 <= image_loading_v1;
    end
end

always @(posedge video_clk or negedge video_rst_n) begin
    if (!video_rst_n) begin
        osd_state_v1 <= 4'd0; osd_state_v2 <= 4'd0;
        osd_err_v1   <= 4'd0; osd_err_v2   <= 4'd0;
        osd_auto_v1  <= 1'b0; osd_auto_v2  <= 1'b0;
    end else begin
        osd_state_v1 <= state_code_s2;
        osd_state_v2 <= osd_state_v1;
        osd_err_v1   <= err_code_s2;
        osd_err_v2   <= osd_err_v1;
        osd_auto_v1  <= auto_play_en_sd;
        osd_auto_v2  <= osd_auto_v1;
    end
end

assign osd_index = (osd_state_v2 == 4'd0) ? 2'd0 :
                   (osd_state_v2[1:0] - 2'd1);

reg dv_v1, dv_v2;

reg reader_scan_enabled;
wire reader_request_frame = reader_frame_start &&
                            ((DIAG_MODE != 0) || dv_v2);
always @(posedge video_clk or negedge video_rst_n) begin
    if (!video_rst_n) reader_scan_enabled <= 1'b0;
    else if (reader_frame_start)
        reader_scan_enabled <= (DIAG_MODE != 0) || dv_v2;
end

reg ict_v1, ict_v2, ict_v3;
reg failed_v1, failed_v2, failed_v3, failed_pending;
always @(posedge video_clk or negedge video_rst_n) begin
    if (!video_rst_n) begin
        failed_v1 <= 0; failed_v2 <= 0; failed_v3 <= 0;
        failed_pending <= 0;
    end else begin
        failed_v1 <= load_failed_tgl;
        failed_v2 <= failed_v1;
        failed_v3 <= failed_v2;
        if (failed_v2 != failed_v3) failed_pending <= 1;
        else if (reader_frame_start) failed_pending <= 0;
    end
end
wire load_failed_pix = failed_pending && reader_frame_start;
always @(posedge sd_card_clk or negedge sdcard_rst_n) begin
    if (!sdcard_rst_n) begin
        reading_sd1 <= 0; reading_sd2 <= 0; reading_sd3 <= 0;
        reading_index_sd1 <= 0; reading_index_sd2 <= 0;
    end else begin
        reading_sd1 <= reading_done_tgl;
        reading_sd2 <= reading_sd1;
        reading_sd3 <= reading_sd2;
        reading_index_sd1 <= reading_done_index;
        reading_index_sd2 <= reading_index_sd1;
    end
end

always @(posedge video_clk or negedge video_rst_n) begin
    if (!video_rst_n) begin
        dv_v1 <= 1'b0; dv_v2 <= 1'b0;
        ict_v1 <= 1'b0; ict_v2 <= 1'b0; ict_v3 <= 1'b0;
    end else begin
        dv_v1  <= display_valid;
        dv_v2  <= dv_v1;
        ict_v1 <= index_commit_tgl;
        ict_v2 <= ict_v1;
        ict_v3 <= ict_v2;
    end
end
wire ict_pulse = ict_v3 ^ ict_v2;

reg commit_pending;

reg [5:0] exhibit_meta_v1, exhibit_meta_v2;
reg [51:0] exhibit_size_v1, exhibit_size_v2, exhibit_pending_size;
reg [1:0] exhibit_pending_bank, exhibit_pending_index;
reg [1:0] exhibit_display_bank;
always @(posedge video_clk or negedge video_rst_n) begin
    if (!video_rst_n) begin
        exhibit_meta_v1 <= 0; exhibit_meta_v2 <= 0;
        exhibit_size_v1 <= 0; exhibit_size_v2 <= 0; exhibit_pending_size <= 0;
        exhibit_pending_bank <= 0; exhibit_pending_index <= 0;
        exhibit_display_bank <= 0;
    end else begin
        exhibit_meta_v1 <= {disp_buf_idx, state_code};
        exhibit_meta_v2 <= exhibit_meta_v1;
        exhibit_size_v1 <= {committed_source_size, committed_fitted_size};
        exhibit_size_v2 <= exhibit_size_v1;
        if (ict_pulse) begin
            exhibit_pending_size <= exhibit_size_v2;
            exhibit_pending_bank <= exhibit_meta_v2[5:4];
            exhibit_pending_index <= exhibit_meta_v2[1:0] - 2'd1;
        end
        if (reader_frame_start && commit_pending)
            exhibit_display_bank <= exhibit_pending_bank;
    end
end
always @(posedge video_clk or negedge video_rst_n) begin
    if (!video_rst_n)            commit_pending <= 1'b0;
    else if (ict_pulse)          commit_pending <= 1'b1;
    else if (reader_frame_start) commit_pending <= 1'b0;
end
wire index_commit_pix = commit_pending && reader_frame_start;

video_fade_transition #(
    .REVEAL_ON_COMMIT (2),
    .FADE_FRAMES (16)
) u_video_fade_transition (

    .ctrl_clk        (sd_card_clk),
    .ctrl_rst_n      (sdcard_rst_n),
    .next_event_in   (key_next_req),
    .next_event_out  (fade_next_event),
    .fade_busy       (fade_busy),

    .pix_clk         (video_clk),
    .pix_rst_n       (video_rst_n),
    .reveal_commit   (osd_auto_v2),
    .player_active   (dv_v2),
    .frame_start     (reader_frame_start),
    .index_commit    (THUMBNAIL_MODE ? 1'b0 : index_commit_pix),
    .load_failed     (load_failed_pix),
    .active_index    (disp_idx_v2),
    .alpha_out       (fade_alpha),
    .fade_active     (fade_active),
    .wipe_active     (wipe_active),
    .ramp_out        (wipe_ramp),
    .transition_kind (transition_kind)
);

wire [9:0]  osd_pixel_x = (raw_x - 12'd160);

wire [15:0] fade_r16 = reader_pixel_rgb[23:16] * fade_alpha;
wire [15:0] fade_g16 = reader_pixel_rgb[15:8]  * fade_alpha;
wire [15:0] fade_b16 = reader_pixel_rgb[7:0]   * fade_alpha;
wire [23:0] faded_rgb = {fade_r16[15:8], fade_g16[15:8], fade_b16[15:8]};

wire [9:0]  wipe_boundary = wipe_ramp * (640 / 16);

wire [23:0] reader_display_rgb = (THUMBNAIL_MODE && !thumb_de) ?
                                 24'h000000 : reader_pixel_rgb;
wire [23:0] transition_rgb = wipe_active ?
    ((osd_pixel_x < wipe_boundary) ? reader_display_rgb : 24'h000000) :
    (THUMBNAIL_MODE ? ((thumb_de && reader_pixel_valid) ?
                       faded_rgb : 24'h000000) : faded_rgb);
wire [23:0] transition_focus_rgb =
    (THUMBNAIL_MODE && thumb_focus_border) ? 24'hffb020 : transition_rgb;

wire [23:0] adjusted_rgb;
wire        adjusted_de;

brightness_contrast_adjust u_brightness_contrast_adjust (
    .clk        (video_clk),
    .rst_n      (video_rst_n),
    .in_de      (raw_de),
    .rgb_in     (transition_focus_rgb),
    .brightness (brightness_q),
    .contrast   (contrast_q),
    .out_de     (adjusted_de),
    .rgb_out    (adjusted_rgb)
);

wire [23:0] osd_rgb_out;
wire        osd_active;

osd_overlay_24 #(
    .OSD_X (8),
    .OSD_Y (8),
    .EXHIBITION_UI (2),
    .HIDE_OVERLAY (1)
) u_osd_overlay_24 (
    .clk          (video_clk),
    .rst_n        (video_rst_n),
    .vsync        (raw_vs),
    .de           (raw_de),
    .rgb_in       (preview_mode_q ? preview_rgb :
                   ((DIAG_MODE == 0 && !dv_v2) ? 24'd0 : adjusted_rgb)),

    .pixel_x      (osd_pixel_x),
    .active_index (preview_mode_q ? preview_focus_q : osd_index),
    .auto_enabled (osd_auto_v2 && !preview_mode_q),
    .audio_status (audio_status),
    .image_loading (image_loading_v2),
    .display_ready (dv_v2),
    .preview_active (preview_mode_q),
    .error_code   ({4'b0000, osd_err_v2}),
    .rgb_out      (osd_rgb_out),
    .de_out       (),
    .osd_active   (osd_active)
);

wire [23:0] waveform_rgb_out;

wire guide_wave_visible;
wire guide_wave_hit;
promax_audio_waveform #(
    .GUIDE_MODE(GUIDE_WAVE_ENABLE),
    .WAVE_X(GUIDE_WAVE_ENABLE ? 528 : 64),
    .WAVE_Y(GUIDE_WAVE_ENABLE ? 434 : 400),
    .WAVE_WIDTH(GUIDE_WAVE_ENABLE ? 96 : 512),
    .WAVE_HEIGHT(GUIDE_WAVE_ENABLE ? 12 : 64)
) u_audio_waveform (
    .clk              (video_clk),
    .rst_n            (video_rst_n),
    .vsync            (raw_vs),
    .de               (raw_de),
    .rgb_in           (osd_rgb_out),
    .pixel_x          (osd_pixel_x),
    .enable           (GUIDE_WAVE_ENABLE ? guide_wave_visible :
                       (AUDIO_ENABLE && wav_active_v && (DIAG_MODE == 2'd0) && !THUMBNAIL_MODE && !preview_mode_q)),
    .pcm_tap_valid    (wav_sample_valid),
    .pcm_tap_left     (wav_mono_16),
    .rgb_out          (waveform_rgb_out),
    .waveform_active  (guide_wave_hit)
);

wire [23:0] metadata_rgb;

assign metadata_rgb = waveform_rgb_out;

wire [23:0] caption_rgb;
reg caption_enable_v1, caption_enable_v2;
always @(posedge video_clk or negedge video_rst_n) begin
    if (!video_rst_n) begin caption_enable_v1 <= 0; caption_enable_v2 <= 0; end
    else begin caption_enable_v1 <= narration_enabled; caption_enable_v2 <= caption_enable_v1; end
end
reg [1:0] speech_play_sync;
reg [1:0] speech_picture_s1, speech_picture_s2;
always @(posedge video_clk or negedge video_rst_n) begin
    if (!video_rst_n) begin
        speech_play_sync <= 0; speech_picture_s1 <= 0; speech_picture_s2 <= 0;
    end else begin
        speech_play_sync <= {speech_play_sync[0], wav_play_en};
        speech_picture_s1 <= narration_selected; speech_picture_s2 <= speech_picture_s1;
    end
end
wire speech_playing_pix = speech_play_sync[1] && wav_samples_consumed != 0 &&
                          speech_picture_s2 == narration_image_pix;
assign guide_wave_visible = CAPTION_ENABLE && caption_enable_v2 && speech_playing_pix &&
                            wav_active_v && dv_v2 && !fade_active && !index_commit_pix &&
                            !osd_auto_v2 && !preview_mode_q && !THUMBNAIL_MODE && DIAG_MODE==0;
wire caption_hs, caption_vs, caption_de;
wire final_raw_de = raw_de && (!dv_v2 || preview_mode_q || THUMBNAIL_MODE || reader_pixel_valid);
generate if (CAPTION_ENABLE) begin : g_exhibit_caption
    exhibit_caption_overlay #(.GUIDE_WAVE_FEEDBACK(GUIDE_WAVE_ENABLE), .ADJUST_HINT(1), .HINT_FRAMES(90), .INTRO_CARD(1), .SPEECH_SYNC(1), .ARTWORK_LABEL(1), .READING_GUIDE(1), .AUTO_HOLD_FRAMES(119), .SWITCHABLE_CAPTION(1)) u_caption (
        .clk(video_clk), .rst_n(video_rst_n), .frame_start(reader_frame_start),
        .commit(index_commit_pix), .commit_index(exhibit_pending_index),
        .display_valid(dv_v2 && (DIAG_MODE == 0)),
        .preview_mode(preview_mode_q), .preview_focus(preview_focus_q),
        .brightness_value(brightness_v2), .contrast_value(contrast_v2),
        .auto_mode(osd_auto_v2),
        .caption_enabled(caption_enable_v2),
        .artwork_ready(!fade_active),
        .speech_playing(speech_playing_pix), .speech_samples(wav_samples_consumed),
        .x(osd_pixel_x), .y(display_y[9:0]),
        .hs_in(raw_hs), .vs_in(raw_vs), .de_in(final_raw_de),
        .rgb_in(metadata_rgb), .waveform_hit(guide_wave_hit), .hs_out(caption_hs), .vs_out(caption_vs),
        .de_out(caption_de), .rgb_out(caption_rgb), .caption_hit(),
        .reading_done_tgl(reading_done_tgl), .reading_done_index(reading_done_index)
    );
end else begin : g_no_exhibit_caption
    assign reading_done_tgl = 1'b0;
    assign reading_done_index = 2'd0;
    assign caption_hs = raw_hs;
    assign caption_vs = raw_vs;
    assign caption_de = final_raw_de;
    assign caption_rgb = metadata_rgb;
end endgenerate

rgb_video_adapter #(
    .HS_IN_ACTIVE_LOW  (1),
    .VS_IN_ACTIVE_LOW  (1),
    .HS_OUT_ACTIVE_LOW (1),
    .VS_OUT_ACTIVE_LOW (1)
) u_rgb_video_adapter(
    .pclk              (video_clk),
    .rst_n             (video_rst_n),
    .hs_in             (caption_hs),
    .vs_in             (caption_vs),
    .de_in             (caption_de),
    .rgb_in            (caption_rgb),
    .video_clk         (),
    .video_hs          (hs),
    .video_vs          (vs),
    .video_de          (de),
    .video_rgb         (vout_data_raw)
);

assign vout_data = vout_data_raw;

reg         pix_fifo_re_r;
reg         pix_stage_valid;
reg  [31:0] pix_stage_data;
wire        pix_stage_taken;

assign pix_fifo_rst   = !sdcard_rst_n || !mem_rst_n || (pix_fifo_flush != 4'd0);

assign pix_fifo_re    = pix_fifo_re_r;
assign pix_stage_taken = pix_stage_valid && loader_pixel_ready;

always @(posedge ext_mem_clk or negedge mem_rst_n) begin
    if (!mem_rst_n) begin
        pix_fifo_re_r  <= 1'b0;
        pix_stage_valid<= 1'b0;
        pix_stage_data <= 32'd0;
    end else begin

        pix_fifo_re_r <= !pix_stage_valid && pix_fifo_valid && !pix_fifo_re_r;
        if (pix_fifo_re_r) begin
            pix_stage_valid <= 1'b1;
            pix_stage_data  <= pix_fifo_dout;
        end else if (pix_stage_taken) begin
            pix_stage_valid <= 1'b0;
        end
    end
end

wfifo_32_32_512 u_pix_fifo(
    .rst               (pix_fifo_rst),
    .clkw              (sd_card_clk),
    .clkr              (ext_mem_clk),
    .we                (sd_card_write_en),
    .di                (sd_card_write_data),
    .re                (pix_fifo_re),
    .dout              (pix_fifo_dout),
    .valid             (pix_fifo_valid),
    .full_flag         (pix_fifo_full),
    .empty_flag        (),
    .afull             (),
    .aempty            (),
    .wrusedw           (),
    .rdusedw           ()
);

always @(posedge ext_mem_clk or negedge mem_rst_n) begin
    if (!mem_rst_n)
        pix_fifo_flush <= 4'd0;
    else if (loader_load_start)
        pix_fifo_flush <= 4'd15;
    else if (pix_fifo_flush != 4'd0)
        pix_fifo_flush <= pix_fifo_flush - 4'd1;
end

reg         sd_card_write_req_ack_r;
reg  [1:0]  write_idx_sd;

always @(posedge sd_card_clk or negedge sdcard_rst_n) begin
    if (!sdcard_rst_n) begin
        sd_wreq_d               <= 1'b0;
        load_req_tgl_sd         <= 1'b0;
        sd_card_write_req_ack_r <= 1'b0;
        write_idx_sd            <= 2'd0;
    end else begin
        sd_wreq_d               <= sd_card_write_req;
        sd_card_write_req_ack_r <= sd_card_write_req & ~sd_wreq_d;
        if (sd_card_write_req & ~sd_wreq_d) begin
            load_req_tgl_sd <= ~load_req_tgl_sd;
            write_idx_sd    <= write_buf_idx;
        end
    end
end
assign sd_card_write_req_ack = sd_card_write_req_ack_r;

always @(posedge ext_mem_clk or negedge mem_rst_n) begin
    if (!mem_rst_n) begin
        load_req_tgl_m1   <= 1'b0;
        load_req_tgl_m2   <= 1'b0;
        load_req_tgl_m3   <= 1'b0;
        write_idx_m1      <= 2'd0;
        write_idx_m2      <= 2'd0;
        loader_img_idx    <= 2'd0;
        loader_load_start <= 1'b0;
    end else begin
        load_req_tgl_m1   <= load_req_tgl_sd;
        load_req_tgl_m2   <= load_req_tgl_m1;
        load_req_tgl_m3   <= load_req_tgl_m2;
        write_idx_m1      <= write_idx_sd;
        write_idx_m2      <= write_idx_m1;
        loader_load_start <= load_req_tgl_m2 ^ load_req_tgl_m3;
        if (load_req_tgl_m2 ^ load_req_tgl_m3)
            loader_img_idx <= write_idx_m2;
    end
end

media_frame_loader #(
    .ADDR_WIDTH    (ADDR_BITS),
    .IMAGE_WORDS   (FRAME_PIXELS),
    .FIFO_DEPTH    (512),
    .BURST_SIZE    (128),
    .STALL_TIMEOUT (65535),
    .IMAGE_COLS    (640),
    .IMAGE_ROWS    (480),
    .FLIP_VERTICAL (1)
) u_media_frame_loader(
    .clk                (ext_mem_clk),
    .rst_n              (mem_rst_n),

    .load_start         (DIAG_LOOP ? loop_load_start : loader_load_start),
    .image_index        (DIAG_LOOP ? 2'd0 : loader_img_idx),

    .pixel_valid        (DIAG_LOOP ? gen_push : (pix_stage_taken && loader_load_busy)),

    .pixel_rgb          (DIAG_LOOP ? gen_pixel : pix_stage_data[31:8]),
    .pixel_ready        (loader_pixel_ready),
    .frame_commit       (1'b0),
    .decode_error       (8'd0),
    .load_busy          (loader_load_busy),
    .load_done          (loader_load_done),
    .image_complete     (loader_image_complete),
    .memory_error       (loader_memory_error),
    .controller_init_done(Sdr_init_done),
    .controller_busy    (Sdr_busy),
    .refresh_active     (Sdr_init_ref_vld),
    .bus_grant          (bus_grant_wr),
    .wr_burst_active    (loader_wr_burst_active),
    .wr_start_intent    (loader_wr_start_intent),
    .app_wr_en          (loader_app_wr_en),
    .app_wr_addr        (loader_app_wr_addr),
    .app_wr_mask        (loader_app_wr_mask),
    .app_wr_data        (loader_app_wr_data)
);

media_frame_reader #(
    .ADDR_WIDTH          (ADDR_BITS),
    .IMAGE_WORDS         (FRAME_PIXELS),
    .FIFO_DEPTH          (512),
    .FIFO_MARGIN         (8),

    .BURST_SIZE          (128),
    .BURST_GAP_CYCLES    (12),
    .MAX_INFLIGHT_BURSTS (2),
    .DIAG_SYNTH_STREAM   (DIAG_BAR),
    .THUMBNAIL_MODE      (THUMBNAIL_MODE)
) u_media_frame_reader(
    .mem_clk              (ext_mem_clk),
    .mem_rst_n            (mem_rst_n),
    .controller_init_done (Sdr_init_done),
    .controller_busy      (Sdr_busy),
    .refresh_active       (Sdr_init_ref_vld),
    .bus_grant            (bus_grant_rd),
    .rd_burst_active      (reader_rd_burst_active),
    .rd_start_intent      (reader_rd_start_intent),
    .writer_window_safe   (reader_writer_window_safe),
    .app_rd_en            (reader_app_rd_en),
    .app_rd_addr          (reader_app_rd_addr),
    .sdram_rd_valid       (reader_sdram_rd_valid),
    .sdram_rd_data        (reader_sdram_rd_data),
    .pix_clk              (video_clk),
    .pix_rst_n            (video_rst_n),
    .frame_start          (reader_request_frame),

    .active_index         (DIAG_LOOP ? 2'd0 : CAPTION_ENABLE ? exhibit_display_bank : disp_idx_v2),
    .pixel_consume        (reader_pixel_consume && reader_scan_enabled),
    .pixel_rgb            (reader_pixel_rgb),
    .pixel_valid          (reader_pixel_valid),
    .underflow            (reader_underflow),
    .reader_busy          (),
    .frame_read_done      (),
    .reader_index         (),
    .reader_error         (reader_error)
);

assign reader_sdram_rd_valid = Sdr_rd_en;
assign reader_sdram_rd_data  = Sdr_rd_dout;

sdram U3(
    .Clk               (ext_mem_clk),
    .Clk_sft           (ext_mem_clk_sft),
    .Rst               (~mem_rst_n),
    .Sdr_init_done     (Sdr_init_done),
    .Sdr_init_ref_vld  (Sdr_init_ref_vld),
    .Sdr_busy          (Sdr_busy),
    .App_wr_en         (loader_app_wr_en),
    .App_wr_addr       (loader_app_wr_addr),
    .App_wr_dm         (loader_app_wr_mask),
    .App_wr_din        (loader_app_wr_data),
    .App_rd_en         (reader_app_rd_en),
    .App_rd_addr       (reader_app_rd_addr),
    .Sdr_rd_en         (Sdr_rd_en),
    .Sdr_rd_dout       (Sdr_rd_dout)
);

localparam MUTE_AUDIO = 1'b1;

always @(posedge video_clk or negedge video_rst_n) begin
    if (!video_rst_n) begin
        sample_div_cnt <= 10'd0;
        sample_tick    <= 1'b0;
    end else if (sample_div_cnt == 10'd520) begin
        sample_div_cnt <= 10'd0;
        sample_tick    <= 1'b1;
    end else begin
        sample_div_cnt <= sample_div_cnt + 1'b1;
        sample_tick    <= 1'b0;
    end
end

pcm_test_tone #(
    .SAMPLE_DIV ( 521 )
) u_pcm_test_tone (
    .clk             ( video_clk ),
    .rst_n           ( video_rst_n ),
    .enable          ( 1'b1 ),
    .sample_valid    ( arp_valid ),
    .sample_ready    ( arp_ready ),
    .sample_left     ( tone_left_16 ),
    .sample_right    ( tone_right_16 ),
    .rom_index       (),
    .sample_accepted ()
);

assign arp_l_16 = MUTE_AUDIO ? 16'sd0 : tone_left_16;
assign arp_r_16 = MUTE_AUDIO ? 16'sd0 : tone_right_16;

always @(posedge video_clk or negedge video_rst_n) begin
    if (!video_rst_n) begin
        wav_active_s1 <= 1'b0;
        wav_active_s2 <= 1'b0;
    end else begin
        wav_active_s1 <= audio_enabled && narration_track_valid && !preview_mode_sd && !auto_play_en_sd;
        wav_active_s2 <= wav_active_s1;
    end
end
assign wav_active_v = wav_active_s2;

always @(posedge video_clk or negedge video_rst_n) begin
    if (!video_rst_n) begin narration_image_pix <= 0; narration_commit_pix <= 0; narration_has_picture <= 0; end
    else if (index_commit_pix) begin
        narration_has_picture <= 1;
        narration_image_pix <= exhibit_pending_index;
        narration_commit_pix <= ~narration_commit_pix;
    end
end
always @(posedge sd_card_clk or negedge sdcard_rst_n) begin
    if (!sdcard_rst_n) begin
        narration_enabled <= AUDIO_ENABLE;
        narration_picture_sd <= 0;
        narration_end_sd <= 0;
        narration_commit_sd <= 0; narration_image_s1 <= 0; narration_image_s2 <= 0;
        narration_seen <= 0; narration_selected <= 0;
        narration_state <= 0; narration_settle <= 0; narration_finished <= 0;
        narration_offset <= 0; narration_shift <= 0;
        narration_lba <= 0; narration_cluster <= 0; narration_size <= 0; narration_sectors <= 0;
        wav_play_en <= 0; wav_restart_wait <= 0;
    end else begin
        narration_picture_sd <= {narration_picture_sd[0], narration_has_picture};
        narration_end_sd <= {narration_end_sd[0], wav_stream_end};
        narration_commit_sd <= {narration_commit_sd[0], narration_commit_pix};
        narration_image_s1 <= narration_image_pix;
        narration_image_s2 <= narration_image_s1;
        if (narration_toggle) narration_enabled <= ~narration_enabled;
        if (!audio_enabled || !narration_picture_sd[1] || preview_mode_sd || auto_play_en_sd || narration_toggle ||
            narration_commit_sd[1] != narration_seen) begin
            wav_play_en <= 0;
            narration_seen <= narration_commit_sd[1];
            narration_selected <= narration_image_s2;
            narration_state <= 0; narration_settle <= 0; narration_finished <= 0;
        end else case (narration_state)
            0: begin
                wav_play_en <= 0;

                if (narration_stopped) begin
                    if (narration_settle == 1023) begin
                        narration_offset <= narration_clusters[narration_selected*32 +: 32] - 2;
                        case (audio_sectors_per_cluster)
                            2: narration_shift <= 1; 4: narration_shift <= 2;
                            8: narration_shift <= 3; 16: narration_shift <= 4;
                            32: narration_shift <= 5; 64: narration_shift <= 6;
                            128: narration_shift <= 7; default: narration_shift <= 0;
                        endcase
                        narration_cluster <= narration_clusters[narration_selected*32 +: 32];
                        narration_size <= narration_sizes[narration_selected*32 +: 32];
                        narration_sectors <= (narration_sizes[narration_selected*32 +: 32] + 511) >> 9;
                        narration_state <= 1;
                    end else narration_settle <= narration_settle + 1'b1;
                end else narration_settle <= 0;
            end
            1: begin
                narration_lba <= audio_data_start_lba +
                    (narration_offset << narration_shift);
                narration_state <= 2;
            end
            2: begin
                if (!narration_finished && narration_track_valid) wav_play_en <= 1;
                if (narration_end_sd[1]) begin
                    wav_play_en <= 0;
                    narration_finished <= 1;
                    narration_state <= 3;
                end
            end
            3: wav_play_en <= 0;
        endcase
    end
end

wav_stream_player #(
    .FAT_ENABLE         ( 1 ),
    .ADDR_WIDTH         ( 10 ),
    .SAMPLES_PER_SECTOR ( 256 )
) u_wav_stream_player (
    .wr_clk          ( sd_card_clk ),
    .wr_rst_n        ( sdcard_rst_n ),
    .play_enable     ( wav_play_en ),
    .start_lba       ( narration_lba ),
    .total_sectors   ( narration_sectors ),
    .first_cluster   ( narration_cluster ),
    .file_size       ( narration_size ),
    .sectors_per_cluster ( audio_sectors_per_cluster ),
    .fat_start_lba   ( audio_fat_start_lba ),
    .data_start_lba  ( audio_data_start_lba ),
    .max_cluster     ( audio_max_cluster ),
    .sd_req          ( wav_sd_req ),
    .sd_lba          ( wav_sd_lba ),
    .sd_busy         ( wav_sd_busy ),
    .sd_valid        ( wav_sd_valid ),
    .sd_byte         ( wav_sd_byte ),
    .sd_byte_index   ( wav_sd_byte_index ),
    .sd_done         ( wav_sd_done ),
    .sd_error        ( wav_sd_error ),

    .rd_clk          ( video_clk ),
    .rd_rst_n        ( video_rst_n ),
    .sample_tick     ( sample_tick ),
    .sample_out      ( wav_mono_16 ),
    .sample_valid    ( wav_sample_valid ),
    .sample_ready    ( wav_ready ),

    .sample_counter  ( wav_samples_consumed ),
    .buffer_empty    ( wav_buffer_empty ),
    .stopped         ( narration_stopped ),
    .stream_active   (),
    .stream_end      ( wav_stream_end ),
    .buffer_low      ()
);

audio_source_mux u_audio_source_mux (
    .clk            ( video_clk ),
    .rst_n          ( video_rst_n ),
    .wav_valid      ( wav_sample_valid ),
    .wav_ready      ( wav_ready ),
    .wav_left       ( wav_mono_16 ),
    .wav_right      ( wav_mono_16 ),
    .wav_active     ( audio_enabled && wav_active_v ),
    .arp_valid      ( arp_valid ),
    .arp_ready      ( arp_ready ),
    .arp_left       ( arp_l_16 ),
    .arp_right      ( arp_r_16 ),
    .force_arpeggio ( 1'b0 ),
    .out_valid      ( mux_valid ),
    .out_ready      ( 1'b1 ),
    .out_left       ( mux_left_16 ),
    .out_right      ( mux_right_16 )
);

sync_fade_gain u_sync_fade_gain (
    .pix_clk     ( video_clk ),
    .pix_rst_n   ( video_rst_n ),
    .frame_start ( reader_frame_start ),
    .alpha_pix   ( fade_alpha ),
    .fade_active ( fade_active ),
    .aud_clk     ( video_clk ),
    .aud_rst_n   ( video_rst_n ),
    .gain_aud    ( audio_gain_aud )
);

pcm_content_mux u_pcm_content_mux (
    .sample0    ( mux_left_16 ),
    .sample1    ( mux_right_16 ),
    .sample2    ( 16'sd0 ),
    .sample3    ( 16'sd0 ),
    .media_id   ( 2'd0 ),
    .volume     ( audio_gain_aud ),
    .sample_out ( pcm_mono_16 )
);

assign audio_left_16  = pcm_mono_16;
assign audio_right_16 = pcm_mono_16;
assign audio_valid    = mux_valid;

assign audio_left_data  = {audio_left_16, 8'd0};
assign audio_right_data = {audio_right_16, 8'd0};

audio_arc_calculate #(
    .ACR_N ( 6144 )
) u_audio_arc_calculate (
    .I_clk         ( video_clk ),
    .I_rst         ( ~video_rst_n ),
    .I_audio_valid ( audio_valid ),
    .O_acr_valid   ( acr_valid ),
    .O_acr_cts     ( acr_cts ),
    .O_acr_n       ( acr_n )
);

video_rgb_to_axis_640x480 u_video_rgb_to_axis_640x480(
    .I_clk         (video_clk),
    .I_rst         (~video_rst_n),
    .I_vs          (vs),
    .I_de          (de),
    .I_rgb         (vout_data),
    .O_video_user  (axis_s_user),
    .O_video_valid (axis_s_valid),
    .O_video_last  (axis_s_last),
    .O_video_data  (axis_s_data)
);

startup_pulse #(
    .CNT_MAX(20'd100000)
) u_startup_pulse (
    .I_clk   (video_clk),
    .I_rst   (~video_rst_n),
    .O_pulse (edid_trig)
);

hdmi_1_4b_transmitter_core_wrapper #(
    .DEVICE                 ( "EG"       ),
    .HTOTAL                 ( 800        ),
    .HSA                    ( 96         ),
    .HFP                    ( 16         ),
    .HBP                    ( 48         ),
    .HACTIVE                ( 640        ),
    .VTOTAL                 ( 525        ),
    .VSA                    ( 2          ),
    .VFP                    ( 10         ),
    .VBP                    ( 33         ),
    .VACTIVE                ( 480        ),
    .VIDEO_VIC              ( 1          ),
    .VIDEO_TPG              ( "Disable"  ),
    .VIDEO_FORMAT           ( "RGB"      ),
    .AUDIO_SAMPLE_RATE      ( "48K"      ),
    .IIC_SCL_DIV            ( 250        )
) u_hdmi_1_4b_transmitter_core_wrapper(
    .I_pixel_clk        (video_clk),
    .I_rst              (~video_rst_n),
    .I_edid_read_trig   (edid_trig),
    .O_edid_read_valid  (edid_valid),
    .O_edid_read_data   (edid_data),

    .I_axis_s_user      (axis_s_user),
    .I_axis_s_valid     (axis_s_valid),
    .I_axis_s_last      (axis_s_last),
    .I_axis_s_data      (axis_s_data),
    .O_axis_s_ready     (axis_s_ready),

    .I_audio_valid      (audio_valid),
    .I_audio_left_data  (audio_left_data),
    .I_audio_right_data (audio_right_data),
    .I_acr_valid        (acr_valid),
    .I_acr_cts          (acr_cts),
    .I_acr_n            (acr_n),

    .O_video_locked     (),
    .O_ddc_scl          (HDMI_DDC_SCL),
    .IO_ddc_sda         (HDMI_DDC_SDA),

    .O_ch0_tmds_data    (tmds_ch0_data),
    .O_ch1_tmds_data    (tmds_ch1_data),
    .O_ch2_tmds_data    (tmds_ch2_data),
    .O_clk_tmds_data    (tmds_clk_data)
);

hdmi_phy_wrapper #(
    .DEVICE ( "EG" )
) u_hdmi2phy_wrapper(
    .I_pixel_clk        (video_clk),
    .I_serial_clk       (hdmi_5x_clk),
    .I_rst              (~serial_rst_n),
    .I_tmds_channel_0   (tmds_ch0_data),
    .I_tmds_channel_1   (tmds_ch1_data),
    .I_tmds_channel_2   (tmds_ch2_data),
    .I_tmds_channel_clk (tmds_clk_data),
    .O_tmds_ch0_p       (HDMI_D0_P),
    .O_tmds_ch1_p       (HDMI_D1_P),
    .O_tmds_ch2_p       (HDMI_D2_P),
    .O_tmds_clk_p       (HDMI_CLK_P)
);

endmodule
