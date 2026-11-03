module sd_card_bmp #(
    parameter integer FULL_FRAME_CACHE = 0,
    parameter integer AUTO_FROM_CAPTION = 0,
    parameter integer AUTO_PREFETCH = 0,
    parameter integer MANUAL_PREFETCH = 0,
    parameter integer MANUAL_READY_GATE = 0,
    parameter integer PREVIEW_WARMUP = 0,
    parameter integer PREVIEW_FOCUS_PREFETCH = 0,
    parameter integer CLK_FREQ_HZ       = 100_000_000,
    parameter [31:0]  SCAN_START_SECTOR = 32'd0,
    parameter [31:0]  SCAN_MAX_SECTOR   = 32'd131071,
    parameter [2:0]   SCAN_TARGET_COUNT = 3'd4,

    parameter integer LONG_PRESS_MS     = 1000,
    parameter integer AUTO_PLAY_MS      = 1000,

    parameter integer LOAD_TIMEOUT_MS   = 5000,

    parameter [1:0]   MAX_RETRIES       = 2'd1,

    parameter integer SD_READ_TIMEOUT_MS = 500,

    parameter integer SD_INIT_TIMEOUT_MS = 3000
)(
    input                       clk,
    input                       rst,
    input                       key_next,
    input                       key_auto,
    input                       key_mode,
    input                       auto_advance_event,
    output reg                  preview_mode,
    output reg [1:0]            preview_focus,
    output reg [3:0]            preview_loaded,
    output [3:0]                preview_available,
    output                      preview_capture_start,
    output [1:0]                preview_capture_index,
    input  [15:0]               bmp_width,
    input  [15:0]               bmp_height,

    input                       sdr_init_done,
    output reg                  display_valid,
    output                      image_loading,
    output reg [31:0]           committed_source_size,
    output reg [19:0]           committed_fitted_size,
    output reg  [3:0]           state_code,

    output                      auto_play_out,

    output                      key_next_req,
    input                       manual_transition_busy,
    input                       next_req_gated,
    output reg                  index_commit_tgl,
    output reg                  load_failed_tgl,

    input                       wav_sd_req,
    input  [31:0]               wav_sd_lba,
    output                      wav_sd_busy,
    output                      wav_sd_valid,
    output [7:0]                wav_sd_byte,
    output [8:0]                wav_sd_byte_index,
    output                      wav_sd_done,
    output [7:0]                wav_sd_error,

    output [3:0]                narration_valid,
    output [127:0]              narration_clusters,
    output [127:0]              narration_sizes,
    output                      narration_toggle,
    output                      audio_valid,
    output [31:0]               audio_start_lba,
    output [31:0]               audio_total_sectors,
    output [31:0]               audio_first_cluster,
    output [31:0]               audio_file_size,
    output [7:0]                audio_sectors_per_cluster,
    output [31:0]               audio_fat_start_lba,
    output [31:0]               audio_data_start_lba,
    output [31:0]               audio_max_cluster,

    output [3:0]                error_code,

    input                       write_finish_toggle,
    output reg [1:0]            write_buf_idx,
    output reg [1:0]            disp_buf_idx,

    output                      write_req,
    input                       write_req_ack,
    input                       write_ready,
    output                      write_en,
    output [31:0]               write_data,
    output                      SD_nCS,
    output                      SD_DCLK,
    output                      SD_MOSI,
    input                       SD_MISO
);

wire key_next_press;
wire key_auto_press;
wire key_mode_press;
reg [3:0] preview_attempted;
reg load_preview_only, preview_open_pending;
reg [3:0] preview_focus_attempted;
reg [1:0] preview_return_index;
reg preview_select_pending;
reg [1:0] preview_select_index;
reg preview_exit_loading;
wire [3:0] preview_missing;
wire [1:0] preview_load_index;

wire             sd_sec_read;
wire [31:0]      sd_sec_read_addr;
wire [7:0]       sd_sec_read_data;
wire             sd_sec_read_data_valid;
wire             sd_sec_read_end;
wire             sd_init_done;

reg              bmp_data_wr_en;
reg  [23:0]      bmp_data;

wire             scanner_scan_busy;
wire             scanner_scan_done;
wire [7:0]       scanner_fs_error;
wire [7:0]       scanner_spc;
wire [31:0]      scanner_fat_start;
wire [31:0]      scanner_data_start;
wire [31:0]      scanner_max_cluster;
wire [3:0]       scan_resource_valid;
wire [31:0]      img_cluster0, img_cluster1, img_cluster2, img_cluster3;
wire [31:0]      img_size0, img_size1, img_size2, img_size3;
wire             scanner_sector_req;
wire [31:0]      scanner_sector_lba;
wire             scanner_sector_busy;
wire             scanner_sector_valid;
wire [7:0]       scanner_sector_byte;
wire [8:0]       scanner_sector_byte_index;
wire             scanner_sector_done;
wire [7:0]       scanner_sector_error;

wire             streamer_file_busy;
wire             streamer_file_done;
wire             streamer_byte_valid;
wire [7:0]       streamer_byte;
wire [7:0]       streamer_fs_error;
wire             streamer_sector_req;
wire [31:0]      streamer_sector_lba;
wire             streamer_sector_busy;
wire             streamer_sector_valid;
wire [7:0]       streamer_sector_byte;
wire [8:0]       streamer_sector_byte_index;
wire             streamer_sector_done;
wire [7:0]       streamer_sector_error;

wire             scanner_audio_valid;
wire [31:0]      scanner_audio_start_lba;
wire [31:0]      scanner_audio_total_sectors;
wire [31:0]      scanner_audio_first_cluster;
wire [31:0]      scanner_audio_file_size;

reg              wav_req_d;
reg              wav_req_hold;
reg  [31:0]      wav_lba_q;
reg              audio_params_valid;
reg  [31:0]      audio_start_lba_q;
reg  [31:0]      audio_total_sectors_q;
reg  [31:0]      audio_first_cluster_q;
reg  [31:0]      audio_file_size_q;

wire             arb_sector_req;
wire [31:0]      arb_sector_lba;
wire             arb_sector_busy;
wire             arb_sector_valid;
wire [7:0]       arb_sector_byte;
wire [8:0]       arb_sector_byte_index;
wire             arb_sector_done;
wire [7:0]       arb_sector_error;

reg  [1:0]       arb_owner;

reg              scanner_req_pending;
reg  [31:0]      scanner_lba_pending;
reg              streamer_req_pending;
reg  [31:0]      streamer_lba_pending;

reg              use_streamer;

reg              scan_success;

wire scaler_busy, scaler_done, scaler_pause;
wire             bmp_ready = ~streamer_file_busy && !scaler_busy;

reg              scan_done;

wire [2:0]       bmp_error;
wire             load_error;

reg  [1:0]       byte_state;
reg  [31:0]      bmp_byte_cnt;
reg  [31:0]      data_offset;
reg  [2:0]       rgb_byte_cnt;
reg  [23:0]      rgb_pixel;
reg  [15:0]      hdr_width;
reg  [15:0]      hdr_height;
reg              header_bad;
reg              write_req_r;
reg              load_active;

reg              scan_start_pulse;
reg              load_start_pulse;

reg [31:0]       load_cluster;
reg [31:0]       load_file_size;
reg              scan_kicked;
reg              first_image_committed;
reg              auto_play_en;
reg [31:0]       auto_cnt;

reg              auto_req_pending;
reg [2:0]        img_found_count;
reg [1:0]        img_idx;
reg [1:0]        load_idx;
reg [1:0]        pending_buf_idx;
reg              next_req_pending;
reg              load_busy;

reg              load_prefetch, prefetched_valid, prefetch_attempted;
reg [31:0]       prefetched_source_size;
reg [19:0]       prefetched_fitted_size;
reg [31:0]       prefetch_guard;
localparam integer PREFETCH_GUARD_CYCLES = CLK_FREQ_HZ / 20;
wire prefetch_guard_done = prefetch_guard >= PREFETCH_GUARD_CYCLES;
reg [31:0]       load_timeout_cnt;

reg              load_abort;

reg [1:0]        retry_count;
reg [2:0]        last_error_code;

assign preview_missing = scan_resource_valid & ~(preview_loaded | preview_attempted);
assign preview_load_index = preview_missing[0] ? 2'd0 :
                            preview_missing[1] ? 2'd1 :
                            preview_missing[2] ? 2'd2 : 2'd3;
assign preview_available = scan_resource_valid;

assign preview_capture_start = load_start_pulse && !preview_loaded[load_idx];
assign preview_capture_index = load_idx;
assign error_code = {1'b0, last_error_code};
assign image_loading = load_busy && !load_preview_only && !(AUTO_PREFETCH && load_prefetch);

assign auto_play_out = auto_play_en;

reg manual_ready_pending, manual_frame_reserved, manual_failure_seen;
reg [3:0] resident_valid, resident_attempted;
reg [31:0] resident_source [0:3];
reg [19:0] resident_fitted [0:3];
wire [3:0] resident_missing = scan_resource_valid & ~(resident_valid | resident_attempted);
wire [1:0] resident_warm_index = resident_missing[0] ? 0 : resident_missing[1] ? 1 : resident_missing[2] ? 2 : 3;
wire [1:0] next_from_current;
wire resident_preview_request = key_mode_press && !manual_transition_busy && !manual_frame_reserved;
wire resident_target_waiting = manual_ready_pending || (auto_play_en && auto_req_pending);
wire [1:0] resident_target = !first_image_committed ? resident_warm_index :
    (resident_target_waiting && !resident_valid[next_from_current]) ? next_from_current : resident_warm_index;
wire resident_load_needed = (!first_image_committed || resident_target_waiting || resident_missing != 0) &&
    !resident_valid[resident_target] && scan_resource_valid[resident_target] && !resident_attempted[resident_target];
reg resident_offer;
reg [1:0] resident_plan_index;
reg [31:0] resident_plan_cluster, resident_plan_size;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        resident_offer <= 0;
        resident_plan_index <= 0;
        resident_plan_cluster <= 0; resident_plan_size <= 0;
    end else begin
        resident_offer <= FULL_FRAME_CACHE && sd_init_done && scan_done && bmp_ready &&
            !load_busy && !load_start_pulse && !scanner_scan_done && !load_abort &&
            resident_load_needed && (!display_valid || resident_target != disp_buf_idx) &&
            (!first_image_committed || prefetch_guard_done);
        resident_plan_index <= resident_target;
        resident_plan_cluster <= cluster_lut(resident_target);
        resident_plan_size <= size_lut(resident_target);
    end
end
wire use_manual_ready_gate = MANUAL_READY_GATE && AUTO_PREFETCH &&
                             MANUAL_PREFETCH && img_found_count > 1;
wire manual_cache_ready = FULL_FRAME_CACHE ? resident_valid[next_from_current] : prefetched_valid && !load_busy &&
                          load_idx == next_from_current;

assign key_next_req = FULL_FRAME_CACHE ?
    (!preview_mode && !preview_open_pending && display_valid && manual_ready_pending &&
     manual_cache_ready && !manual_transition_busy && !manual_frame_reserved &&
     !key_mode_press && !key_auto_press) :
    !preview_mode && (use_manual_ready_gate ?
    (manual_ready_pending && manual_cache_ready && !manual_transition_busy &&
     !key_mode_press && !key_auto_press) : key_next_press);
always @(posedge clk or posedge rst) begin
    if (rst) begin
        manual_ready_pending <= 0;
        manual_frame_reserved <= 0;
        manual_failure_seen <= 0;
    end else begin
        manual_failure_seen <= load_failed_tgl;
        if (!use_manual_ready_gate || !sd_init_done || !scan_done ||
            !display_valid || preview_mode ||
             (key_mode_press && (!FULL_FRAME_CACHE || resident_preview_request)) ||
             (key_auto_press && !manual_transition_busy && !manual_frame_reserved) ||
            load_abort || manual_failure_seen != load_failed_tgl) begin
            manual_ready_pending <= 0;
            manual_frame_reserved <= 0;
        end else begin
            if (key_next_press && !manual_transition_busy && !manual_frame_reserved)
                manual_ready_pending <= 1;
            if (key_next_req) begin
                manual_ready_pending <= 0;
                manual_frame_reserved <= 1;
            end
            if (next_req_gated) manual_frame_reserved <= 0;
        end
    end
end

wire             key_auto_stable;

reg [31:0]       long_press_cnt;
reg              long_press_marked;
reg              prev_req_pending;

wire [31:0] scaler_source_size;
wire [19:0] scaler_fitted_size;
reg              source_done_seen;
reg              write_done_seen;

reg [2:0]        wrfin_tgl_sync;
wire             write_finish_pulse;

wire auto_tick;
wire [31:0] auto_play_cycles = (CLK_FREQ_HZ / 1000) * AUTO_PLAY_MS;

wire [31:0] load_timeout_cycles = (CLK_FREQ_HZ / 1000) * LOAD_TIMEOUT_MS;

assign write_en   = bmp_data_wr_en;
assign write_data = {bmp_data[23:16], bmp_data[15:8], bmp_data[7:0], 8'b0};
assign auto_tick  = (auto_cnt == (auto_play_cycles - 32'd1));
assign next_from_current = FULL_FRAME_CACHE ? next_valid_index(img_idx, scan_resource_valid) : next_index_limited(img_idx, img_found_count);
assign write_finish_pulse = wrfin_tgl_sync[2] ^ wrfin_tgl_sync[1];


key_press_debounce #(
    .CLK_FREQ_HZ (CLK_FREQ_HZ),
    .DEBOUNCE_MS (50)
) u_key_mode (
    .clk(clk), .rst(rst), .button_in(key_mode),
    .press_pulse(key_mode_press), .button_stable_out() ,
    .long_press_pulse(narration_toggle)
);

key_press_debounce #(
    .CLK_FREQ_HZ (CLK_FREQ_HZ),
    .DEBOUNCE_MS (50),
    .LONG_PRESS_MS (FULL_FRAME_CACHE ? 850 : 1000)
) u_key_next (
    .clk        (clk),
    .rst        (rst),
    .button_in  (key_next),
    .press_pulse(key_next_press)
);

key_press_debounce #(
    .CLK_FREQ_HZ (CLK_FREQ_HZ),
    .DEBOUNCE_MS (50),
    .LONG_PRESS_MS (FULL_FRAME_CACHE ? 850 : 1000)
) u_key_auto (
    .clk        (clk),
    .rst        (rst),
    .button_in  (key_auto),
    .press_pulse(key_auto_press),
    .button_stable_out(key_auto_stable)
);

function [1:0] next_valid_index;
    input [1:0] current_index;
    input [3:0] available;
    reg [1:0] candidate;
    integer n;
    reg found;
    begin
        next_valid_index = current_index; found = 0;
        for (n=1; n<=4; n=n+1) begin
            candidate = current_index + n;
            if (!found && available[candidate]) begin
                next_valid_index = candidate; found = 1;
            end
        end
    end
endfunction

function [1:0] next_index_limited;
    input [1:0] cur;
    input [2:0] count;
    begin
        case (count)
            3'd0: next_index_limited = 2'd0;
            3'd1: next_index_limited = 2'd0;
            3'd2: next_index_limited = (cur == 2'd1) ? 2'd0 : (cur + 2'd1);
            3'd3: next_index_limited = (cur == 2'd2) ? 2'd0 : (cur + 2'd1);
            default: next_index_limited = (cur == 2'd3) ? 2'd0 : (cur + 2'd1);
        endcase
    end
endfunction

function [1:0] prev_index_limited;
    input [1:0] cur;
    input [2:0] count;
    begin
        case (count)
            3'd0: prev_index_limited = 2'd0;
            3'd1: prev_index_limited = 2'd0;
            3'd2: prev_index_limited = (cur == 2'd0) ? 2'd1 : (cur - 2'd1);
            3'd3: prev_index_limited = (cur == 2'd0) ? 2'd2 : (cur - 2'd1);
            default: prev_index_limited = (cur == 2'd0) ? 2'd3 : (cur - 2'd1);
        endcase
    end
endfunction

function [31:0] cluster_lut;
    input [1:0] idx;
    begin
        case (idx)
            2'd0: cluster_lut = img_cluster0;
            2'd1: cluster_lut = img_cluster1;
            2'd2: cluster_lut = img_cluster2;
            default: cluster_lut = img_cluster3;
        endcase
    end
endfunction

function [31:0] size_lut;
    input [1:0] idx;
    begin
        case (idx)
            2'd0: size_lut = img_size0;
            2'd1: size_lut = img_size1;
            2'd2: size_lut = img_size2;
            default: size_lut = img_size3;
        endcase
    end
endfunction

function [1:0] next_buf_lut;
    input [1:0] cur_disp_buf;
    input       valid_now;
    begin
        if (!valid_now)
            next_buf_lut = 2'd0;
        else if (cur_disp_buf == 2'd0)
            next_buf_lut = 2'd1;
        else
            next_buf_lut = 2'd0;
    end
endfunction

always @(posedge clk or posedge rst) begin
    if (rst) begin
        resident_valid <= 0; resident_attempted <= 0;
        wrfin_tgl_sync        <= 3'b000;
        scan_start_pulse      <= 1'b0;
        load_start_pulse      <= 1'b0;
        load_cluster          <= 32'd0;
        load_file_size        <= 32'd0;
        scan_kicked           <= 1'b0;
        first_image_committed <= 1'b0;
        auto_play_en          <= 1'b0;
        load_prefetch <= 0; prefetched_valid <= 0; prefetch_attempted <= 0;
        prefetched_source_size <= 0; prefetched_fitted_size <= 0; prefetch_guard <= 0;
        auto_cnt              <= 32'd0;
        auto_req_pending      <= 1'b0;
        img_found_count       <= 3'd0;
        img_idx               <= 2'd0;
        load_idx              <= 2'd0;
        pending_buf_idx       <= 2'd0;
        write_buf_idx         <= 2'd0;
        disp_buf_idx          <= 2'd0;
        next_req_pending      <= 1'b0;
        index_commit_tgl      <= 1'b0;
        load_failed_tgl       <= 1'b0;
        load_busy             <= 1'b0;
        load_timeout_cnt      <= 32'd0;
        load_abort            <= 1'b0;
        source_done_seen      <= 1'b0;
        write_done_seen       <= 1'b0;
        display_valid         <= 1'b0;
        committed_source_size <= 0;
        committed_fitted_size <= 0;
        long_press_cnt        <= 32'd0;
        long_press_marked     <= 1'b0;
        prev_req_pending      <= 1'b0;
        state_code            <= 4'd0;
        retry_count           <= 2'd0;
        last_error_code       <= 3'd0;

        use_streamer          <= 1'b0;
        scan_success          <= 1'b0;
        scan_done             <= 1'b0;
        preview_mode          <= 1'b0;
        preview_focus         <= 2'd0;
        preview_loaded        <= 4'd0;
        preview_attempted     <= 4'd0;
        load_preview_only <= 0;
        preview_open_pending <= 0;
        preview_focus_attempted <= 0;
        preview_return_index  <= 2'd0;
        preview_select_pending <= 1'b0;
        preview_select_index  <= 2'd0;
        preview_exit_loading  <= 1'b0;
    end else begin
        wrfin_tgl_sync   <= {wrfin_tgl_sync[1:0], write_finish_toggle};
        scan_start_pulse <= 1'b0;
        load_start_pulse <= 1'b0;
        load_abort       <= 1'b0;
        if (!load_busy) load_prefetch <= 0;
        if (!load_busy) load_preview_only <= 0;
        if (!prefetch_guard_done) prefetch_guard <= prefetch_guard + 1'b1;

        if (load_start_pulse) prefetched_valid <= 0;

        if (MANUAL_READY_GATE && key_next_press && !preview_mode &&
            !manual_transition_busy && !manual_frame_reserved)
            prefetch_attempted <= 0;

        if (!sd_init_done) begin
            resident_valid <= 0; resident_attempted <= 0;
            preview_mode          <= 1'b0;
            preview_loaded        <= 4'd0;
            preview_attempted     <= 4'd0;
            load_preview_only <= 0;
            preview_open_pending <= 0;
            preview_focus_attempted <= 0;
            preview_select_pending <= 1'b0;
            preview_exit_loading  <= 1'b0;
            scan_kicked           <= 1'b0;
            first_image_committed <= 1'b0;
            auto_play_en          <= 1'b0;
            load_prefetch <= 0; prefetched_valid <= 0; prefetch_attempted <= 0;
            prefetched_source_size <= 0; prefetched_fitted_size <= 0; prefetch_guard <= 0;
            auto_cnt              <= 32'd0;
            auto_req_pending      <= 1'b0;
            img_found_count       <= 3'd0;
            img_idx               <= 2'd0;
            load_idx              <= 2'd0;
            pending_buf_idx       <= 2'd0;
            write_buf_idx         <= 2'd0;
            disp_buf_idx          <= 2'd0;
            next_req_pending      <= 1'b0;
            load_busy             <= 1'b0;
            load_timeout_cnt      <= 32'd0;
            load_abort            <= 1'b0;
            source_done_seen      <= 1'b0;
            write_done_seen       <= 1'b0;
            display_valid         <= 1'b0;
        committed_source_size <= 0;
        committed_fitted_size <= 0;
            long_press_cnt        <= 32'd0;
            long_press_marked     <= 1'b0;
            prev_req_pending      <= 1'b0;
            state_code            <= 4'd0;

            scan_done             <= 1'b0;
            scan_success          <= 1'b0;
            use_streamer          <= 1'b0;
        end else begin

            if (scanner_scan_done) begin
                resident_valid <= 0; resident_attempted <= 0;
                if (FULL_FRAME_CACHE) begin
                    display_valid <= 0; first_image_committed <= 0;
                end
                preview_loaded    <= 4'd0;
                preview_attempted <= 4'd0;
                preview_focus_attempted <= 0;

                case (scan_resource_valid)
                    4'b0000: img_found_count <= 3'd0;
                    4'b0001: img_found_count <= 3'd1;
                    4'b0010, 4'b0100, 4'b1000: img_found_count <= 3'd1;
                    4'b0011, 4'b0101, 4'b0110,
                    4'b1001, 4'b1010, 4'b1100: img_found_count <= 3'd2;
                    4'b0111, 4'b1011, 4'b1101, 4'b1110: img_found_count <= 3'd3;
                    default: img_found_count <= 3'd4;
                endcase

                scan_done    <= (scan_resource_valid != 4'd0);
                scan_success <= (scan_resource_valid != 4'd0);

                use_streamer <= (scan_resource_valid != 4'd0);

                if (scan_resource_valid == 4'd0) begin
                    last_error_code <= (scanner_fs_error != 8'd0) ? 3'd1 : 3'd0;
                end
            end

            if (load_busy && scaler_done)
                source_done_seen <= 1'b1;

            if (load_busy && write_finish_pulse)
                write_done_seen <= 1'b1;

            if (load_busy && source_done_seen && write_done_seen) begin
                preview_loaded[load_idx] <= 1'b1;
                if (FULL_FRAME_CACHE) begin
                    resident_valid[load_idx] <= 1;
                    resident_source[load_idx] <= scaler_source_size;
                    resident_fitted[load_idx] <= scaler_fitted_size;
                end
                if (preview_exit_loading) begin
                    preview_mode <= 1'b0;
                    preview_exit_loading <= 1'b0;
                end
                load_busy             <= 1'b0;
                load_timeout_cnt      <= 32'd0;
                source_done_seen      <= 1'b0;
                write_done_seen       <= 1'b0;
                retry_count           <= 2'd0;
                last_error_code       <= 3'd0;
                if (load_preview_only) begin

                    prefetch_attempted <= 0;
                    if (AUTO_PREFETCH && PREVIEW_FOCUS_PREFETCH) begin
                        prefetched_valid <= 1;
                        prefetched_source_size <= scaler_source_size;
                        prefetched_fitted_size <= scaler_fitted_size;
                    end
                end else if (AUTO_PREFETCH && load_prefetch) begin
                    prefetched_valid <= 1;
                    prefetched_source_size <= scaler_source_size;
                    prefetched_fitted_size <= scaler_fitted_size;
                end else begin
                    disp_buf_idx          <= pending_buf_idx;
                    img_idx               <= load_idx;
                    display_valid         <= 1'b1;
                    committed_source_size <= scaler_source_size;
                    committed_fitted_size <= scaler_fitted_size;
                    first_image_committed <= 1'b1;
                    state_code            <= {2'b0, load_idx} + 4'd1;

                    index_commit_tgl      <= ~index_commit_tgl;
                    prefetch_guard <= 0;
                    prefetch_attempted <= 0;
                end
            end else if (load_busy) begin

                if (load_timeout_cnt > load_timeout_cycles) begin
                    load_failed_tgl       <= ~load_failed_tgl;
                    last_error_code       <= 3'd2;
                    preview_exit_loading  <= 1'b0;
                    preview_select_pending <= 1'b0;

                    load_busy             <= 1'b0;
                    load_timeout_cnt      <= 32'd0;
                    source_done_seen      <= 1'b0;
                    write_done_seen       <= 1'b0;
                    load_abort            <= 1'b1;
                end else begin
                    load_timeout_cnt <= load_timeout_cnt + 32'd1;
                end
            end else begin
                load_timeout_cnt <= 32'd0;
            end

            if (load_abort)
                scan_kicked <= 1'b0;

            if (!scan_kicked && bmp_ready && sdr_init_done) begin
                scan_start_pulse <= 1'b1;
                scan_kicked      <= 1'b1;

                scan_done        <= 1'b0;
                scan_success     <= 1'b0;
                use_streamer     <= 1'b0;

                prefetched_valid <= 0; prefetch_attempted <= 0; load_prefetch <= 0;
                img_found_count  <= 3'd0;
                next_req_pending <= 1'b0;
                load_busy        <= 1'b0;
                load_timeout_cnt <= 32'd0;
                source_done_seen <= 1'b0;
                write_done_seen  <= 1'b0;
                auto_cnt         <= 32'd0;
                auto_req_pending <= AUTO_PREFETCH && auto_play_en && !preview_mode && auto_req_pending;
            end else if (!load_abort && FULL_FRAME_CACHE) begin
                if (key_next_press && !preview_mode && !manual_transition_busy && !manual_frame_reserved)
                    preview_open_pending <= 0;
                if (resident_preview_request && display_valid && !preview_exit_loading) begin
                    if (preview_mode) begin
                        preview_mode <= 0;
                        preview_select_pending <= 0;
                    end else begin
                        preview_open_pending <= !preview_open_pending;
                        preview_focus <= img_idx;
                    end
                end
                if (preview_open_pending && !key_mode_press && !key_next_press &&
                    !manual_transition_busy && !manual_frame_reserved &&
                    (resident_valid & scan_resource_valid) == scan_resource_valid) begin
                    preview_mode <= 1;
                    preview_open_pending <= 0;
                    preview_focus <= img_idx;
                end
                if (preview_mode && !preview_select_pending) begin
                    if (key_next_press) preview_focus <= next_valid_index(preview_focus, scan_resource_valid);
                    if (key_auto_press && resident_valid[preview_focus]) begin
                        preview_select_pending <= 1;
                        preview_select_index <= preview_focus;
                    end
                end
                if (key_auto_press && !preview_mode && !manual_transition_busy && !manual_frame_reserved && img_found_count > 1) begin
                    auto_play_en <= !auto_play_en;
                    auto_req_pending <= 0;
                    preview_open_pending <= 0;
                end
                if (auto_play_en && !preview_mode && display_valid && auto_advance_event &&
                    !key_auto_press && !manual_transition_busy && !manual_frame_reserved)
                    auto_req_pending <= 1;
                if (key_next_req) auto_req_pending <= 0;
                if (next_req_gated) begin
                    if (resident_valid[next_from_current]) begin
                        disp_buf_idx <= next_from_current;
                        img_idx <= next_from_current;
                        state_code <= {2'b0,next_from_current} + 1'b1;
                        committed_source_size <= resident_source[next_from_current];
                        committed_fitted_size <= resident_fitted[next_from_current];
                        index_commit_tgl <= !index_commit_tgl;
                        auto_req_pending <= 0;
                        last_error_code <= 0;
                    end else load_failed_tgl <= !load_failed_tgl;
                end else if (auto_play_en && auto_req_pending && !preview_mode &&
                    !preview_open_pending && !preview_select_pending && resident_valid[next_from_current] &&
                    !manual_transition_busy && !manual_frame_reserved && !manual_ready_pending &&
                    !key_next_press && !key_mode_press && !key_auto_press) begin
                    disp_buf_idx <= next_from_current;
                    img_idx <= next_from_current;
                    state_code <= {2'b0,next_from_current} + 1'b1;
                    committed_source_size <= resident_source[next_from_current];
                    committed_fitted_size <= resident_fitted[next_from_current];
                    index_commit_tgl <= !index_commit_tgl;
                    auto_req_pending <= 0;
                    last_error_code <= 0;
                end else if (preview_select_pending && !manual_transition_busy) begin
                    if (resident_valid[preview_select_index]) begin
                        if (preview_select_index != img_idx) begin
                            disp_buf_idx <= preview_select_index;
                            img_idx <= preview_select_index;
                            state_code <= {2'b0,preview_select_index} + 1'b1;
                            committed_source_size <= resident_source[preview_select_index];
                            committed_fitted_size <= resident_fitted[preview_select_index];
                            index_commit_tgl <= !index_commit_tgl;
                        end
                        preview_mode <= 0;
                        preview_select_pending <= 0;
                        auto_req_pending <= 0;
                    end
                end
                if (resident_offer && !load_busy && !load_start_pulse && !scanner_scan_done &&
                    (!display_valid || resident_plan_index != disp_buf_idx)) begin
                    load_idx <= resident_plan_index;
                    load_cluster <= resident_plan_cluster;
                    load_file_size <= resident_plan_size;
                    pending_buf_idx <= resident_plan_index;
                    write_buf_idx <= resident_plan_index;
                    resident_attempted[resident_plan_index] <= 1;
                    load_start_pulse <= 1;
                    load_busy <= 1;
                    load_prefetch <= first_image_committed;
                    source_done_seen <= 0; write_done_seen <= 0;
                    retry_count <= 0;
                end
                if (load_error && load_busy) begin
                    last_error_code <= bmp_error;
                    if (retry_count < MAX_RETRIES) begin
                        retry_count <= retry_count + 1'b1;
                        load_start_pulse <= 1;
                        source_done_seen <= 0; write_done_seen <= 0;
                    end else begin
                        load_busy <= 0;
                        load_failed_tgl <= !load_failed_tgl;
                        retry_count <= 0;
                    end
                end
            end else if (!load_abort) begin

                if (next_req_gated && !preview_mode && scan_done && (img_found_count > 3'd0))
                    next_req_pending <= 1'b1;

                if (key_mode_press && display_valid && !preview_exit_loading) begin
                    if (!preview_mode) begin
                        if (PREVIEW_WARMUP && ((preview_loaded & scan_resource_valid) != scan_resource_valid))
                            preview_open_pending <= !preview_open_pending;
                        else
                            preview_mode <= 1'b1;
                        preview_focus <= img_idx;
                        preview_return_index <= img_idx;
                        preview_attempted <= 4'd0;
                        preview_focus_attempted <= 0;
                        next_req_pending <= 1'b0;
                        prev_req_pending <= 1'b0;
                    end else begin
                        preview_select_index <= preview_return_index;
                        preview_select_pending <= 1'b1;
                    end
                end

                if (PREVIEW_WARMUP && preview_open_pending && !key_mode_press &&
                    scan_done && !load_busy &&
                    ((preview_loaded & scan_resource_valid) == scan_resource_valid)) begin
                    preview_mode <= 1;
                    preview_open_pending <= 0;
                    preview_focus <= img_idx;
                    preview_return_index <= img_idx;
                end
                if (preview_mode && !preview_select_pending && !preview_exit_loading) begin
                    if (key_next_press) begin
                        preview_focus <= preview_focus + 2'd1;
                        preview_focus_attempted <= 0;
                    end
                    if (key_auto_press && preview_loaded[preview_focus]) begin
                        preview_select_index <= preview_focus;
                        preview_select_pending <= 1'b1;
                    end
                end

                if (AUTO_PREFETCH && AUTO_FROM_CAPTION && !preview_mode &&
                    auto_play_en && display_valid && auto_advance_event && !key_auto_press)
                    auto_req_pending <= 1;

                if (key_auto_press && !preview_mode && scan_done && (img_found_count > 3'd1)) begin
                    auto_play_en     <= ~auto_play_en;
                    auto_cnt         <= 32'd0;
                    auto_req_pending <= 1'b0;
                end

                if (1'b0) begin
                    if (long_press_cnt < ((CLK_FREQ_HZ / 1000) * LONG_PRESS_MS - 1)) begin
                        long_press_cnt <= long_press_cnt + 32'd1;
                    end else if (!long_press_marked) begin
                        long_press_marked <= 1'b1;
                        if (scan_done && (img_found_count > 3'd1))
                            prev_req_pending <= 1'b1;
                    end
                end else begin
                    long_press_cnt    <= 32'd0;
                    long_press_marked <= 1'b0;
                end

                if (!preview_mode && scan_done && auto_play_en && display_valid && first_image_committed && (img_found_count > 3'd1)) begin
                    if (AUTO_FROM_CAPTION) begin
                        auto_cnt <= 0;
                        if (auto_advance_event && !key_auto_press)
                            auto_req_pending <= 1;
                    end else if (auto_tick) begin
                        auto_cnt         <= 32'd0;
                        auto_req_pending <= 1'b1;
                    end else begin
                        auto_cnt <= auto_cnt + 32'd1;
                    end
                end else begin
                    auto_cnt         <= 32'd0;
                    if (!AUTO_PREFETCH || !auto_play_en || preview_mode || !display_valid)
                        auto_req_pending <= 1'b0;
                end

                if (scan_done && !first_image_committed && bmp_ready && !load_busy && (img_found_count != 3'd0)) begin
                    load_idx         <= 2'd0;
                    load_cluster     <= cluster_lut(2'd0);
                    load_file_size   <= size_lut(2'd0);
                    pending_buf_idx  <= 2'd0;
                    write_buf_idx    <= 2'd0;
                    load_start_pulse <= 1'b1;
                    load_busy        <= 1'b1;
                    source_done_seen <= 1'b0;
                    write_done_seen  <= 1'b0;
                    next_req_pending <= 1'b0;
                    auto_cnt         <= 32'd0;
                    auto_req_pending <= 1'b0;
                end

                else if (preview_select_pending && scan_done && bmp_ready && !load_busy) begin
                    preview_select_pending <= 1'b0;
                    if (preview_select_index == img_idx) begin
                        preview_mode <= 1'b0;
                    end else if (AUTO_PREFETCH && PREVIEW_FOCUS_PREFETCH &&
                                 prefetched_valid && load_idx == preview_select_index) begin

                        disp_buf_idx <= pending_buf_idx;
                        img_idx <= load_idx;
                        committed_source_size <= prefetched_source_size;
                        committed_fitted_size <= prefetched_fitted_size;
                        state_code <= {2'b0, load_idx} + 4'd1;
                        index_commit_tgl <= ~index_commit_tgl;
                        prefetched_valid <= 0;
                        prefetch_attempted <= 0;
                        prefetch_guard <= 0;
                        next_req_pending <= 0;
                        auto_req_pending <= 0;
                        last_error_code <= 0;
                        preview_mode <= 0;
                    end else begin
                        load_idx <= preview_select_index;
                        load_cluster <= cluster_lut(preview_select_index);
                        load_file_size <= size_lut(preview_select_index);
                        pending_buf_idx <= next_buf_lut(disp_buf_idx, display_valid);
                        write_buf_idx <= next_buf_lut(disp_buf_idx, display_valid);
                        load_start_pulse <= 1'b1;
                        load_busy <= 1'b1;
                        source_done_seen <= 1'b0;
                        write_done_seen <= 1'b0;
                        preview_exit_loading <= 1'b1;
                    end
                end

                else if (preview_mode && !preview_exit_loading && (preview_missing != 0) &&
                         scan_done && bmp_ready && display_valid && !load_busy) begin
                    preview_attempted[preview_load_index] <= 1'b1;
                    load_idx <= preview_load_index;
                    load_cluster <= cluster_lut(preview_load_index);
                    load_file_size <= size_lut(preview_load_index);
                    pending_buf_idx <= next_buf_lut(disp_buf_idx, display_valid);
                    write_buf_idx <= next_buf_lut(disp_buf_idx, display_valid);
                    load_start_pulse <= 1'b1;
                    load_busy <= 1'b1;
                    source_done_seen <= 1'b0;
                    write_done_seen <= 1'b0;
                end

                else if (AUTO_PREFETCH && prefetched_valid && !load_busy &&
                         !preview_mode && !key_mode_press && scan_done &&
                         !key_auto_press && !preview_select_pending &&
                         (load_idx == next_from_current) && !prev_req_pending &&
                         (next_req_pending || (auto_play_en && auto_req_pending))) begin
                    disp_buf_idx <= pending_buf_idx;
                    img_idx <= load_idx;
                    committed_source_size <= prefetched_source_size;
                    committed_fitted_size <= prefetched_fitted_size;
                    state_code <= {2'b0, load_idx} + 4'd1;
                    index_commit_tgl <= ~index_commit_tgl;
                    prefetched_valid <= 0; prefetch_attempted <= 0;
                    prefetch_guard <= 0;
                    next_req_pending <= 0; auto_req_pending <= 0;
                    last_error_code <= 0;
                end

                else if (!preview_mode && scan_done && bmp_ready && display_valid && !load_busy && next_req_pending && (img_found_count != 3'd0)) begin
                    load_idx         <= next_from_current;
                    load_cluster     <= cluster_lut(next_from_current);
                    load_file_size   <= size_lut(next_from_current);
                    pending_buf_idx  <= next_buf_lut(disp_buf_idx, display_valid);
                    write_buf_idx    <= next_buf_lut(disp_buf_idx, display_valid);
                    load_start_pulse <= 1'b1;
                    load_busy        <= 1'b1;
                    source_done_seen <= 1'b0;
                    write_done_seen  <= 1'b0;
                    next_req_pending <= 1'b0;
                    auto_cnt         <= 32'd0;
                    auto_req_pending <= 1'b0;
                end

                else if (!preview_mode && scan_done && bmp_ready && display_valid && !load_busy && prev_req_pending && (img_found_count > 3'd1)) begin
                    load_idx         <= prev_index_limited(img_idx, img_found_count);
                    load_cluster     <= cluster_lut(prev_index_limited(img_idx, img_found_count));
                    load_file_size   <= size_lut(prev_index_limited(img_idx, img_found_count));
                    pending_buf_idx  <= next_buf_lut(disp_buf_idx, display_valid);
                    write_buf_idx    <= next_buf_lut(disp_buf_idx, display_valid);
                    load_start_pulse <= 1'b1;
                    load_busy        <= 1'b1;
                    source_done_seen <= 1'b0;
                    write_done_seen  <= 1'b0;
                    prev_req_pending <= 1'b0;
                    auto_cnt         <= 32'd0;
                    auto_req_pending <= 1'b0;
                end

                else if (!preview_mode && scan_done && bmp_ready && display_valid && !load_busy && auto_play_en && !key_auto_press && auto_req_pending && (img_found_count > 3'd1)) begin
                    load_idx         <= next_from_current;
                    load_cluster     <= cluster_lut(next_from_current);
                    load_file_size   <= size_lut(next_from_current);
                    pending_buf_idx  <= next_buf_lut(disp_buf_idx, display_valid);
                    write_buf_idx    <= next_buf_lut(disp_buf_idx, display_valid);
                    load_start_pulse <= 1'b1;
                    load_busy        <= 1'b1;
                    source_done_seen <= 1'b0;
                    write_done_seen  <= 1'b0;
                    auto_cnt         <= 32'd0;
                    auto_req_pending <= 1'b0;
                end

                else if (AUTO_PREFETCH && PREVIEW_FOCUS_PREFETCH && preview_mode &&
                         !preview_select_pending && !preview_exit_loading &&
                         !key_next_press && !key_auto_press && !key_mode_press &&
                         scan_done && bmp_ready && display_valid && !load_busy &&
                         prefetch_guard_done && preview_loaded[preview_focus] &&
                         preview_focus != img_idx && !preview_focus_attempted[preview_focus] &&
                         (!prefetched_valid || load_idx != preview_focus)) begin
                    preview_focus_attempted[preview_focus] <= 1;
                    load_idx <= preview_focus;
                    load_cluster <= cluster_lut(preview_focus);
                    load_file_size <= size_lut(preview_focus);
                    pending_buf_idx <= next_buf_lut(disp_buf_idx, display_valid);
                    write_buf_idx <= next_buf_lut(disp_buf_idx, display_valid);
                    load_start_pulse <= 1;
                    load_busy <= 1;
                    load_prefetch <= 1;
                    source_done_seen <= 0; write_done_seen <= 0;
                    retry_count <= 0;
                end

                else if (PREVIEW_WARMUP && !preview_mode && !key_mode_press &&
                         !(MANUAL_READY_GATE && (key_next_press ||
                           manual_ready_pending || manual_frame_reserved)) &&
                         scan_done && bmp_ready && display_valid && first_image_committed &&
                         !load_busy && prefetch_guard_done && (preview_missing != 0) &&
                         !next_req_pending && !next_req_gated && !prev_req_pending &&
                         !auto_req_pending && !preview_select_pending) begin
                    preview_attempted[preview_load_index] <= 1;
                    load_idx <= preview_load_index;
                    load_cluster <= cluster_lut(preview_load_index);
                    load_file_size <= size_lut(preview_load_index);
                    pending_buf_idx <= next_buf_lut(disp_buf_idx, display_valid);
                    write_buf_idx <= next_buf_lut(disp_buf_idx, display_valid);
                    load_start_pulse <= 1;
                    load_busy <= 1;
                    load_preview_only <= 1;
                    load_prefetch <= 0;
                    source_done_seen <= 0; write_done_seen <= 0;
                    retry_count <= 0;
                end

                else if (AUTO_PREFETCH && AUTO_FROM_CAPTION && (auto_play_en || MANUAL_PREFETCH) &&
                         !preview_mode && !preview_open_pending && !key_mode_press && !key_auto_press &&
                         scan_done && bmp_ready && display_valid &&
                         first_image_committed && !load_busy &&
                         (!prefetched_valid || (PREVIEW_FOCUS_PREFETCH && load_idx != next_from_current)) &&
                         !prefetch_attempted && prefetch_guard_done &&
                         !next_req_pending && !next_req_gated && !prev_req_pending &&
                         !preview_select_pending && (img_found_count > 1)) begin
                    load_idx <= next_from_current;
                    load_cluster <= cluster_lut(next_from_current);
                    load_file_size <= size_lut(next_from_current);
                    pending_buf_idx <= next_buf_lut(disp_buf_idx, display_valid);
                    write_buf_idx <= next_buf_lut(disp_buf_idx, display_valid);
                    load_start_pulse <= 1;
                    load_busy <= 1; load_prefetch <= 1; prefetch_attempted <= 1;
                    source_done_seen <= 0; write_done_seen <= 0;
                    retry_count <= 0;
                end

                if (load_error) begin
                    last_error_code <= bmp_error;
                    if (load_busy) begin
                        if (retry_count < MAX_RETRIES) begin
                            retry_count      <= retry_count + 2'd1;
                            load_start_pulse <= 1'b1;
                            load_busy        <= 1'b1;
                            source_done_seen <= 1'b0;
                            write_done_seen  <= 1'b0;
                        end else begin

                            load_failed_tgl  <= ~load_failed_tgl;
                            load_busy        <= 1'b0;
                            load_timeout_cnt <= 32'd0;
                            retry_count      <= 2'd0;
                            preview_exit_loading <= 1'b0;

                            if (auto_play_en && !load_prefetch && (img_found_count > 3'd1))
                                auto_req_pending <= 1'b1;
                        end
                    end else begin
                        scan_kicked <= 1'b0;
                    end
                end
            end
        end
    end
end

localparam ARB_NONE     = 2'd0;
localparam ARB_SCANNER  = 2'd1;
localparam ARB_STREAMER = 2'd2;
localparam ARB_WAV      = 2'd3;

wire arb_idle = (!arb_sector_busy) && (arb_owner == ARB_NONE);

wire req_scanner  = scanner_sector_req | scanner_req_pending;
wire req_wav      = wav_req_hold;
wire req_streamer = streamer_sector_req | streamer_req_pending;

wire grant_scanner  = arb_idle & req_scanner;
wire grant_wav      = arb_idle & (!req_scanner) & req_wav;
wire grant_streamer = arb_idle & (!req_scanner) & (!req_wav) & req_streamer;

wire [1:0] arb_sel = (arb_owner != ARB_NONE) ? arb_owner :
                     grant_scanner  ? ARB_SCANNER  :
                     grant_wav      ? ARB_WAV      :
                     grant_streamer ? ARB_STREAMER : ARB_NONE;

assign arb_sector_req = (arb_sel != ARB_NONE);
assign arb_sector_lba = (arb_sel == ARB_SCANNER)  ?
                        (scanner_sector_req ? scanner_sector_lba : scanner_lba_pending) :
                        (arb_sel == ARB_STREAMER) ?
                        (streamer_sector_req ? streamer_sector_lba : streamer_lba_pending) :
                        (arb_sel == ARB_WAV)      ? wav_lba_q          : 32'd0;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        arb_owner <= ARB_NONE;
        scanner_req_pending <= 1'b0;
        scanner_lba_pending <= 32'd0;
        streamer_req_pending <= 1'b0;
        streamer_lba_pending <= 32'd0;
    end else begin
        if (scanner_sector_req && !(arb_idle && grant_scanner)) begin
            scanner_req_pending <= 1'b1;
            scanner_lba_pending <= scanner_sector_lba;
        end
        if (streamer_sector_req && !(arb_idle && grant_streamer)) begin
            streamer_req_pending <= 1'b1;
            streamer_lba_pending <= streamer_sector_lba;
        end
        if (arb_idle && grant_scanner && scanner_req_pending)
            scanner_req_pending <= 1'b0;
        if (arb_idle && grant_streamer && streamer_req_pending)
            streamer_req_pending <= 1'b0;

        if (arb_idle) begin
            if (grant_scanner)       arb_owner <= ARB_SCANNER;
            else if (grant_wav)      arb_owner <= ARB_WAV;
            else if (grant_streamer) arb_owner <= ARB_STREAMER;
            else                     arb_owner <= ARB_NONE;
        end else if (arb_sector_done)
            arb_owner <= ARB_NONE;
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        wav_req_d            <= 1'b0;
        wav_req_hold         <= 1'b0;
        wav_lba_q            <= 32'd0;
        audio_params_valid   <= 1'b0;
        audio_start_lba_q    <= 32'd0;
        audio_total_sectors_q<= 32'd0;
        audio_first_cluster_q<= 32'd0;
        audio_file_size_q    <= 32'd0;
    end else begin
        wav_req_d <= wav_sd_req;

        if (wav_req_d && !wav_sd_req) begin
            wav_lba_q    <= wav_sd_lba;
            wav_req_hold <= 1'b1;
        end

        if (grant_wav)
            wav_req_hold <= 1'b0;

        if (scanner_scan_done) begin
            audio_params_valid    <= scanner_audio_valid;
            audio_start_lba_q     <= scanner_audio_valid ? scanner_audio_start_lba     : 32'd0;
            audio_total_sectors_q <= scanner_audio_valid ? scanner_audio_total_sectors : 32'd0;
            audio_first_cluster_q <= scanner_audio_valid ? scanner_audio_first_cluster : 32'd0;
            audio_file_size_q     <= scanner_audio_valid ? scanner_audio_file_size     : 32'd0;
        end
    end
end

fat32_volume_scanner u_fat32_scanner (
    .clk                     (clk),
    .rst_n                   (~rst),
    .scan_start              (scan_start_pulse),
    .scan_busy               (scanner_scan_busy),
    .scan_done               (scanner_scan_done),
    .fs_error                (scanner_fs_error),
    .partition_lba           (),
    .sectors_per_cluster     (scanner_spc),
    .fat_start_lba           (scanner_fat_start),
    .data_start_lba          (scanner_data_start),
    .max_cluster             (scanner_max_cluster),
    .resource_valid          (scan_resource_valid),
    .resource0_cluster       (img_cluster0),
    .resource1_cluster       (img_cluster1),
    .resource2_cluster       (img_cluster2),
    .resource3_cluster       (img_cluster3),
    .resource0_size          (img_size0),
    .resource1_size          (img_size1),
    .resource2_size          (img_size2),
    .resource3_size          (img_size3),
    .narration_valid (narration_valid),
    .narration_clusters (narration_clusters),
    .narration_sizes (narration_sizes),
    .audio_valid             (scanner_audio_valid),
    .audio_start_lba         (scanner_audio_start_lba),
    .audio_total_sectors     (scanner_audio_total_sectors),
    .audio_first_cluster     (scanner_audio_first_cluster),
    .audio_file_size         (scanner_audio_file_size),
    .sector_req              (scanner_sector_req),
    .sector_lba              (scanner_sector_lba),
    .sector_busy             (scanner_sector_busy),
    .sector_valid            (scanner_sector_valid),
    .sector_byte             (scanner_sector_byte),
    .sector_byte_index       (scanner_sector_byte_index),
    .sector_done             (scanner_sector_done),
    .sector_error            (scanner_sector_error)
);

fat32_file_streamer u_fat32_streamer (
    .clk                     (clk),
    .rst_n                   (~rst && !load_abort),
    .file_start              (load_start_pulse),
    .file_pause              (scaler_pause),
    .first_cluster           (load_cluster),
    .file_size               (load_file_size),
    .sectors_per_cluster     (scanner_spc),
    .fat_start_lba           (scanner_fat_start),
    .data_start_lba          (scanner_data_start),
    .max_cluster             (scanner_max_cluster),
    .file_busy               (streamer_file_busy),
    .file_done               (streamer_file_done),
    .file_valid              (streamer_byte_valid),
    .file_byte               (streamer_byte),
    .file_byte_offset        (),
    .fs_error                (streamer_fs_error),
    .sector_req              (streamer_sector_req),
    .sector_lba              (streamer_sector_lba),
    .sector_busy             (streamer_sector_busy),
    .sector_valid            (streamer_sector_valid),
    .sector_byte             (streamer_sector_byte),
    .sector_byte_index       (streamer_sector_byte_index),
    .sector_done             (streamer_sector_done),
    .sector_error            (streamer_sector_error)
);

sd_sector_adapter u_sector_adapter (
    .clk                     (clk),
    .rst                     (rst),
    .sector_req              (arb_sector_req),
    .sector_lba              (arb_sector_lba),
    .sector_busy             (arb_sector_busy),
    .sector_valid            (arb_sector_valid),
    .sector_byte             (arb_sector_byte),
    .sector_byte_index       (arb_sector_byte_index),
    .sector_done             (arb_sector_done),
    .sector_error            (arb_sector_error),
    .sd_sec_read             (sd_sec_read),
    .sd_sec_read_addr        (sd_sec_read_addr),
    .sd_sec_read_data        (sd_sec_read_data),
    .sd_sec_read_data_valid  (sd_sec_read_data_valid),
    .sd_sec_read_end         (sd_sec_read_end)
);

assign scanner_sector_busy      = (arb_sel == ARB_SCANNER) ? arb_sector_busy : 1'b0;
assign scanner_sector_valid     = (arb_sel == ARB_SCANNER) ? arb_sector_valid : 1'b0;
assign scanner_sector_byte      = arb_sector_byte;
assign scanner_sector_byte_index= arb_sector_byte_index;
assign scanner_sector_done      = (arb_sel == ARB_SCANNER) ? arb_sector_done : 1'b0;
assign scanner_sector_error     = arb_sector_error;

assign streamer_sector_busy     = (arb_sel == ARB_STREAMER) ? arb_sector_busy : 1'b0;
assign streamer_sector_valid    = (arb_sel == ARB_STREAMER) ? arb_sector_valid : 1'b0;
assign streamer_sector_byte     = arb_sector_byte;
assign streamer_sector_byte_index = arb_sector_byte_index;
assign streamer_sector_done     = (arb_sel == ARB_STREAMER) ? arb_sector_done : 1'b0;
assign streamer_sector_error    = arb_sector_error;

assign wav_sd_busy              = (arb_sel == ARB_WAV) ? arb_sector_busy : 1'b0;
assign wav_sd_valid             = (arb_sel == ARB_WAV) ? arb_sector_valid : 1'b0;
assign wav_sd_byte              = arb_sector_byte;
assign wav_sd_byte_index        = arb_sector_byte_index;
assign wav_sd_done              = (arb_sel == ARB_WAV) ? arb_sector_done : 1'b0;
assign wav_sd_error             = arb_sector_error;

assign audio_valid              = audio_params_valid;
assign audio_start_lba          = audio_start_lba_q;
assign audio_total_sectors      = audio_total_sectors_q;
assign audio_first_cluster      = audio_first_cluster_q;
assign audio_file_size          = audio_file_size_q;
assign audio_sectors_per_cluster = scanner_spc;
assign audio_fat_start_lba       = scanner_fat_start;
assign audio_data_start_lba       = scanner_data_start;
assign audio_max_cluster          = scanner_max_cluster;

assign write_req = write_req_r;

reg  [2:0] err_code_r;
reg        load_err_r;
assign bmp_error  = err_code_r;
assign load_error = load_err_r;

wire scaler_pixel_valid, scaler_req, scaler_error;
wire [23:0] scaler_pixel;
wire [2:0] scaler_error_code;
bmp_fit_scaler u_bmp_scaler (
    .clk(clk), .rst(rst | load_abort), .start(load_start_pulse),
    .byte_valid(streamer_byte_valid), .byte_data(streamer_byte),
    .file_done(streamer_file_done), .fs_error(streamer_fs_error),
    .pause_file(scaler_pause), .write_req(scaler_req), .write_ack(write_req_ack),
    .pixel_ready(write_ready),
    .pixel_valid(scaler_pixel_valid), .pixel(scaler_pixel),
    .error_pulse(scaler_error), .error_code(scaler_error_code),
    .source_size(scaler_source_size), .fitted_size(scaler_fitted_size),
    .busy(scaler_busy), .done(scaler_done)
);
always @* begin
    bmp_data_wr_en = scaler_pixel_valid;
    bmp_data = scaler_pixel;
    write_req_r = scaler_req;
    load_err_r = scaler_error;
    err_code_r = scaler_error_code;
end

sd_card_top
#(

    .CLK_FREQ_HZ(CLK_FREQ_HZ),
    .WATCHDOG_MS(1000),

    .INIT_TIMEOUT_MS(SD_INIT_TIMEOUT_MS)
)
sd_card_top_m0(
    .clk                    (clk),
    .rst                    (rst),
    .SD_nCS                 (SD_nCS),
    .SD_DCLK                (SD_DCLK),
    .SD_MOSI                (SD_MOSI),
    .SD_MISO                (SD_MISO),
    .sd_init_done           (sd_init_done),
    .sd_sec_read            (sd_sec_read),
    .sd_sec_read_addr       (sd_sec_read_addr),
    .sd_sec_read_data       (sd_sec_read_data),
    .sd_sec_read_data_valid (sd_sec_read_data_valid),
    .sd_sec_read_end        (sd_sec_read_end),
    .sd_sec_write           (1'b0),
    .sd_sec_write_addr      (32'd0),
    .sd_sec_write_data      (),
    .sd_sec_write_data_req  (),
    .sd_sec_write_end       ()
);

endmodule

module key_press_debounce #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer DEBOUNCE_MS = 20,
    parameter integer LONG_PRESS_MS = 1000
)(
    input  wire clk,
    input  wire rst,
    input  wire button_in,
    output reg  long_press_pulse,
    output reg  press_pulse,
    output reg  button_stable_out
);

localparam integer DEBOUNCE_CYCLES = (CLK_FREQ_HZ / 1000) * DEBOUNCE_MS;

reg button_sync0;
reg button_sync1;
reg button_stable;
reg [31:0] cnt;
reg [31:0] hold_cnt;
reg long_seen;
localparam integer LONG_PRESS_CYCLES = (CLK_FREQ_HZ / 1000) * LONG_PRESS_MS;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        button_sync0  <= 1'b1;
        button_sync1  <= 1'b1;
        button_stable <= 1'b1;
        cnt           <= 32'd0;
        hold_cnt      <= 32'd0;
        long_seen     <= 1'b0;
        press_pulse   <= 1'b0;
        long_press_pulse <= 1'b0;
        button_stable_out <= 1'b1;
    end else begin
        button_sync0 <= button_in;
        button_sync1 <= button_sync0;
        press_pulse  <= 1'b0;
        long_press_pulse <= 1'b0;

        if (button_sync1 == button_stable) begin
            cnt <= 32'd0;
        end else begin
            if (cnt >= DEBOUNCE_CYCLES - 1) begin
                if (!button_stable && button_sync1 && !long_seen)
                    press_pulse <= 1'b1;
                button_stable     <= button_sync1;
                button_stable_out <= button_sync1;
                cnt               <= 32'd0;
            end else begin
                cnt <= cnt + 32'd1;
            end
        end

        if (button_stable == 1'b0) begin
            if (hold_cnt < LONG_PRESS_CYCLES)
                hold_cnt <= hold_cnt + 32'd1;
            if (hold_cnt >= LONG_PRESS_CYCLES - 1) begin
                if (!long_seen) long_press_pulse <= 1'b1;
                long_seen <= 1'b1;
            end
        end else if (button_sync1 == 1'b1) begin
            hold_cnt  <= 32'd0;
            long_seen <= 1'b0;
        end
    end
end

endmodule
