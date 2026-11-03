`timescale 1ns/1ps

module wav_stream_player #(
    parameter FAT_ENABLE = 0,
    parameter integer ADDR_WIDTH = 12,
    parameter integer SAMPLES_PER_SECTOR = 256
) (

    input  wire        wr_clk,
    input  wire        wr_rst_n,
    input  wire        play_enable,
    input  wire [31:0] start_lba,
    input  wire [31:0] total_sectors,
    input  wire [31:0] first_cluster,
    input  wire [31:0] file_size,
    input  wire [7:0]  sectors_per_cluster,
    input  wire [31:0] fat_start_lba,
    input  wire [31:0] data_start_lba,
    input  wire [31:0] max_cluster,
    output wire        sd_req,
    output reg  [31:0] sd_lba,
    input  wire        sd_busy,
    input  wire        sd_valid,
    input  wire [7:0]  sd_byte,
    input  wire [8:0]  sd_byte_index,
    input  wire        sd_done,
    input  wire [7:0]  sd_error,

    input  wire        rd_clk,
    input  wire        rd_rst_n,
    input  wire        sample_tick,
    output reg  signed [15:0] sample_out,
    output reg         sample_valid,
    input  wire        sample_ready,

    output reg  [31:0] sample_counter,
    output wire        stopped,
    output wire        stream_active,
    output wire        stream_end,
    output wire        buffer_low,
    output wire        buffer_empty
);

    reg [15:0] buffer [0:(1<<ADDR_WIDTH)-1]; /* fehdl ram_style="bram" */

    reg [15:0] buffer_q;
    reg [ADDR_WIDTH-1:0] wr_ptr;
    reg [ADDR_WIDTH-1:0] rd_ptr;

    always @(posedge rd_clk) buffer_q <= buffer[rd_ptr];

    reg [2:0] wstate_sync1, wstate_sync2;

    reg [ADDR_WIDTH-1:0] wr_gray;
    reg [ADDR_WIDTH-1:0] wr_gray_sync1, wr_gray_sync2;

    reg [ADDR_WIDTH-1:0] rd_gray;
    reg [ADDR_WIDTH-1:0] rd_gray_sync1, rd_gray_sync2;

    function [ADDR_WIDTH-1:0] to_gray;
        input [ADDR_WIDTH-1:0] b;
        begin
            to_gray = b ^ (b >> 1);
        end
    endfunction

    function [ADDR_WIDTH-1:0] from_gray;
        input [ADDR_WIDTH-1:0] g;
        reg [ADDR_WIDTH-1:0] b;
        integer i;
        begin
            b[ADDR_WIDTH-1] = g[ADDR_WIDTH-1];
            for (i = ADDR_WIDTH-2; i >= 0; i = i - 1)
                b[i] = b[i+1] ^ g[i];
            from_gray = b;
        end
    endfunction

    function [3:0] cluster_shift;
        input [7:0] value;
        begin
            case (value)
                8'd1:   cluster_shift = 4'd0;
                8'd2:   cluster_shift = 4'd1;
                8'd4:   cluster_shift = 4'd2;
                8'd8:   cluster_shift = 4'd3;
                8'd16:  cluster_shift = 4'd4;
                8'd32:  cluster_shift = 4'd5;
                8'd64:  cluster_shift = 4'd6;
                8'd128: cluster_shift = 4'd7;
                default: cluster_shift = 4'd0;
            endcase
        end
    endfunction

    wire [ADDR_WIDTH-1:0] wr_ptr_in_rd = from_gray(wr_gray_sync2);
    wire [ADDR_WIDTH-1:0] rd_ptr_in_wr = from_gray(rd_gray_sync2);

    wire [ADDR_WIDTH-1:0] used_wr = wr_ptr - rd_ptr_in_wr;
    wire [ADDR_WIDTH:0] level_wr = {1'b0, used_wr};

    wire [ADDR_WIDTH-1:0] used_rd = wr_ptr_in_rd - rd_ptr;
    wire [ADDR_WIDTH:0] level_rd = {1'b0, used_rd};

    localparam [3:0] WS_IDLE      = 4'd0;
    localparam [3:0] WS_REQ       = 4'd1;
    localparam [3:0] WS_FILL      = 4'd2;
    localparam [3:0] WS_FAT_REQ   = 4'd3;
    localparam [3:0] WS_FAT_FILL  = 4'd4;
    localparam [3:0] WS_FAT_PARSE = 4'd5;
    localparam [3:0] WS_END       = 4'd6;
    localparam [3:0] WS_LBA_PREP = 4'd7, WS_LBA = 4'd8;
    reg [31:0] cluster_offset;
    reg [3:0] spc_shift_q;
    reg [3:0]  wstate;
    wire wstate_ended = (wstate == WS_END);
    reg [31:0] cur_lba;
    reg [31:0] sectors_read;
    reg [31:0] current_cluster;
    reg [7:0]  sector_in_cluster;
    reg [31:0] sectors_remaining;
    reg [31:0] fat_entry_offset;
    reg [7:0]  fat_b0, fat_b1, fat_b2, fat_b3;
    reg        fat_mode;
    wire metadata_unknown = ((^first_cluster) === 1'bx) ||
                            ((^sectors_per_cluster) === 1'bx) ||
                            ((^fat_start_lba) === 1'bx) ||
                            ((^data_start_lba) === 1'bx);
    reg [7:0]  lo_byte;
    reg        lo_pending;

    assign stopped = (wstate == WS_IDLE);
    assign sd_req = (wstate == WS_REQ) || (wstate == WS_FAT_REQ);
    assign stream_active = play_enable && (wstate != WS_END);

    assign stream_end = (wstate == WS_END) && (level_rd == 0) && !sample_valid;
    assign buffer_low = (level_rd < (1 << (ADDR_WIDTH-2)));
    assign buffer_empty = (wr_ptr_in_rd == rd_ptr);

    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wstate         <= WS_IDLE;
            cluster_offset <= 0; spc_shift_q <= 0;
            cur_lba        <= 32'd0;
            sectors_read   <= 32'd0;
            current_cluster <= 32'd0;
            sector_in_cluster <= 8'd0;
            sectors_remaining <= 32'd0;
            fat_entry_offset <= 32'd0;
            fat_b0 <= 8'd0;
            fat_b1 <= 8'd0;
            fat_b2 <= 8'd0;
            fat_b3 <= 8'd0;
            fat_mode <= 1'b0;
            wr_ptr         <= {ADDR_WIDTH{1'b0}};
            lo_pending     <= 1'b0;
            lo_byte        <= 8'd0;
            rd_gray_sync1  <= {ADDR_WIDTH{1'b0}};
            rd_gray_sync2  <= {ADDR_WIDTH{1'b0}};
            rd_gray        <= {ADDR_WIDTH{1'b0}};
        end else begin

            rd_gray      <= to_gray(rd_ptr);
            rd_gray_sync1 <= rd_gray;
            rd_gray_sync2 <= rd_gray_sync1;

            case (wstate)
            WS_IDLE: begin
                wr_ptr <= 0;
                lo_pending <= 0;
                if (play_enable && start_lba != 32'd0 && total_sectors != 32'd0) begin
                    cur_lba      <= start_lba;
                    spc_shift_q <= cluster_shift(sectors_per_cluster);
                    sectors_read <= 32'd0;

                    fat_mode <= FAT_ENABLE && !metadata_unknown && first_cluster >= 2 && sectors_per_cluster != 0;
                    current_cluster <= (first_cluster >= 32'd2) ? first_cluster : 32'd0;
                    sector_in_cluster <= 8'd0;
                    sectors_remaining <= total_sectors;
                    wr_ptr       <= {ADDR_WIDTH{1'b0}};
                    lo_pending   <= 1'b0;
                    wstate       <= FAT_ENABLE ? WS_LBA_PREP : WS_REQ;
                end
            end
            WS_LBA_PREP: begin
                cluster_offset <= current_cluster - 2;
                wstate <= WS_LBA;
            end
            WS_LBA: begin
                if (fat_mode) cur_lba <= data_start_lba + (cluster_offset << spc_shift_q) + sector_in_cluster;
                wstate <= WS_REQ;
            end
            WS_REQ: begin

                if (!sd_busy &&
                    (!play_enable || level_wr < ((1 << ADDR_WIDTH) - SAMPLES_PER_SECTOR))) begin

                    sd_lba <= cur_lba;
                    wstate  <= WS_FILL;
                end
            end
            WS_FILL: begin
                if (sd_valid && play_enable &&
                    (!FAT_ENABLE || (sectors_read*512 + sd_byte_index < file_size))) begin
                    if (!lo_pending) begin
                        lo_byte    <= sd_byte;
                        lo_pending <= 1'b1;
                    end else begin
                        buffer[wr_ptr] <= {sd_byte, lo_byte};
                        wr_ptr         <= wr_ptr + 1'b1;
                        lo_pending     <= 1'b0;
                    end
                end
                if (sd_done) begin
                    if (!play_enable) begin
                        wstate <= WS_IDLE;
                    end else if (sd_error != 8'd0) begin
                        wstate <= WS_END;
                    end else begin
                        sectors_read <= sectors_read + 1'b1;
                        cur_lba      <= cur_lba + 1'b1;
                        if (sectors_remaining <= 32'd1) begin
                            sectors_remaining <= 32'd0;
                            wstate <= WS_END;
                        end else if (!fat_mode) begin
                            sectors_remaining <= sectors_remaining - 1'b1;
                            wstate <= WS_REQ;
                        end else begin
                            sectors_remaining <= sectors_remaining - 1'b1;
                            if (sector_in_cluster + 1'b1 < sectors_per_cluster) begin
                                sector_in_cluster <= sector_in_cluster + 1'b1;
                                wstate <= WS_LBA_PREP;
                            end else begin

                                fat_entry_offset <= (current_cluster[6:0] << 2);
                                wstate <= WS_FAT_REQ;
                            end
                        end
                    end
                end
            end
            WS_FAT_REQ: begin
                if (!sd_busy) begin
                    sd_lba <= fat_start_lba + (current_cluster >> 7);
                    fat_b0 <= 8'd0;
                    fat_b1 <= 8'd0;
                    fat_b2 <= 8'd0;
                    fat_b3 <= 8'd0;
                    wstate <= WS_FAT_FILL;
                end
            end
            WS_FAT_FILL: begin
                if (sd_valid) begin
                    if (sd_byte_index == fat_entry_offset[8:0])
                        fat_b0 <= sd_byte;
                    else if (sd_byte_index == fat_entry_offset[8:0] + 1'b1)
                        fat_b1 <= sd_byte;
                    else if (sd_byte_index == fat_entry_offset[8:0] + 2'd2)
                        fat_b2 <= sd_byte;
                    else if (sd_byte_index == fat_entry_offset[8:0] + 2'd3)
                        fat_b3 <= sd_byte;
                end
                if (sd_done) begin
                    if (!play_enable)
                        wstate <= WS_IDLE;
                    else if (sd_error != 8'd0)
                        wstate <= WS_END;
                    else
                        wstate <= WS_FAT_PARSE;
                end
            end
            WS_FAT_PARSE: begin
                if ({fat_b3[3:0], fat_b2, fat_b1, fat_b0} >= 28'hffffff8 ||
                    {fat_b3[3:0], fat_b2, fat_b1, fat_b0} < 28'd2 ||
                    {fat_b3[3:0], fat_b2, fat_b1, fat_b0} > max_cluster) begin
                    wstate <= WS_END;
                end else begin
                    current_cluster <= {fat_b3[3:0], fat_b2, fat_b1, fat_b0};
                    sector_in_cluster <= 8'd0;
                    wstate <= WS_LBA_PREP;
                end
            end
            WS_END: begin

                if (!play_enable)
                    wstate <= WS_IDLE;
            end
            default: wstate <= WS_IDLE;
            endcase

        end
    end

    reg [1:0] play_rd;
    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) play_rd <= 0;
        else play_rd <= {play_rd[0], play_enable};
    end

    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_ptr         <= {ADDR_WIDTH{1'b0}};
            sample_out     <= 16'sd0;
            sample_valid   <= 1'b0;
            sample_counter <= 32'd0;
            wr_gray_sync1  <= {ADDR_WIDTH{1'b0}};
            wr_gray_sync2  <= {ADDR_WIDTH{1'b0}};
            wr_gray        <= {ADDR_WIDTH{1'b0}};
            wstate_sync1   <= 3'd0;
            wstate_sync2   <= 3'd0;
        end else begin

            wr_gray      <= to_gray(wr_ptr);
            wr_gray_sync1 <= wr_gray;
            wr_gray_sync2 <= wr_gray_sync1;
            wstate_sync1 <= wstate;
            wstate_sync2 <= wstate_sync1;

            sample_valid <= 1'b0;

            if (sample_tick && sample_ready) begin
                if (play_rd[1] && level_rd > 0) begin

                    sample_out   <= buffer_q;
                    rd_ptr       <= rd_ptr + 1'b1;
                    sample_valid <= 1'b1;
                    sample_counter <= sample_counter + 1'b1;
                end else begin

                    sample_out   <= 16'sd0;
                    sample_valid <= 1'b1;
                end
            end

            if (!play_rd[1]) begin
                sample_out <= 0;
                rd_ptr         <= {ADDR_WIDTH{1'b0}};
                sample_counter <= 32'd0;
            end
        end
    end
endmodule
