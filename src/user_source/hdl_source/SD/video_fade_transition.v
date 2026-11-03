`timescale 1ns/1ps

module video_fade_transition #(
    parameter integer REVEAL_ON_COMMIT = 1,
    parameter integer FADE_FRAMES = 0
) (
    input wire ctrl_clk, ctrl_rst_n,
    input wire next_event_in,
    output wire next_event_out, fade_busy,
    input wire pix_clk, pix_rst_n,
    input wire player_active, frame_start, index_commit, load_failed,
    input wire reveal_commit,
    input wire [1:0] active_index,
    output wire [7:0] alpha_out,
    output wire fade_active, wipe_active,
    output wire [4:0] ramp_out,
    output wire [1:0] transition_kind
);
    generate
        if (FADE_FRAMES == 0) begin : g_bypass
            assign {fade_busy, fade_active, wipe_active} = 3'b000;
            assign next_event_out = next_event_in;
            assign alpha_out = 255;
            assign ramp_out = 0;
            assign transition_kind = 0;
        end else begin : g_fade
            localparam integer COUNT_BITS = $clog2(FADE_FRAMES + 1);
            localparam integer GAIN_STEP = 256 / FADE_FRAMES;
            localparam [1:0] VISIBLE=0, DIMMING=1, BLACK=2, RESTORING=3;
            reg [1:0] state;

            reg [COUNT_BITS-1:0] elapsed;
            reg reveal;
            reg [1:0] picture_effect;
            reg request_epoch, received_epoch, black_epoch;
            reg [1:0] request_pipe;
            reg [1:0] received_pipe, black_pipe, running_pipe;
            reg black_consumed;
            wire running = state != VISIBLE;
            wire incoming = request_pipe[1] != received_epoch;
            wire request_delivered = received_pipe[1] == request_epoch;
            wire can_accept = !running_pipe[1] && request_delivered;

            always @(posedge ctrl_clk or negedge ctrl_rst_n) begin
                if (!ctrl_rst_n) begin
                    request_epoch <= 0;
                    received_pipe <= 0;
                    black_pipe <= 0;
                    running_pipe <= 0;
                    black_consumed <= 0;
                end else begin
                    received_pipe <= {received_pipe[0], received_epoch};
                    black_pipe <= {black_pipe[0], black_epoch};
                    running_pipe <= {running_pipe[0], running};
                    black_consumed <= black_pipe[1];
                    if (next_event_in && can_accept)
                        request_epoch <= !request_epoch;
                end
            end
            assign next_event_out = black_pipe[1] ^ black_consumed;
            assign fade_busy = running_pipe[1];

            always @(posedge pix_clk or negedge pix_rst_n) begin
                if (!pix_rst_n) begin
                    request_pipe <= 0;
                    received_epoch <= 0;
                end else begin
                    request_pipe <= {request_pipe[0], request_epoch};

                    received_epoch <= request_pipe[1];
                end
            end
            always @(posedge pix_clk or negedge pix_rst_n) begin
                if (!pix_rst_n) begin
                    state <= VISIBLE;
                    elapsed <= 0;
                    reveal <= 0;
                    picture_effect <= 0;
                    black_epoch <= 0;
                end else begin
                    case (state)
                        VISIBLE: begin
                            elapsed <= 0;
                            if (incoming) begin
                                if (player_active) state <= DIMMING;
                            end else if (player_active && index_commit) begin
                                reveal <= REVEAL_ON_COMMIT == 1 || (REVEAL_ON_COMMIT == 2 && reveal_commit);
                                picture_effect <= active_index;
                                state <= RESTORING;
                            end
                        end
                        DIMMING: if (frame_start) begin
                            if (elapsed == FADE_FRAMES) begin
                                state <= BLACK;
                                elapsed <= 0;
                                black_epoch <= !black_epoch;
                            end else elapsed <= elapsed + 1'b1;
                        end
                        BLACK: if (index_commit || load_failed) begin
                            elapsed <= 0;
                            reveal <= 0;
                            state <= RESTORING;
                        end
                        RESTORING: if (frame_start) begin
                            if (elapsed == FADE_FRAMES-1) begin
                                state <= VISIBLE;
                                elapsed <= 0;
                            end else elapsed <= elapsed + 1'b1;
                        end
                        default: begin
                            state <= VISIBLE;
                            elapsed <= 0;
                        end
                    endcase
                end
            end
            wire [COUNT_BITS:0] intensity = state == DIMMING ?
                                                   FADE_FRAMES - elapsed : elapsed;
            wire [15:0] scaled_intensity = intensity * GAIN_STEP;
            assign alpha_out = (state == VISIBLE || (state == RESTORING && reveal)) ? 8'hff :
                               state == BLACK ? 8'h00 :
                               intensity == FADE_FRAMES ? 8'hff : scaled_intensity[7:0];
            assign fade_active = running;
            assign wipe_active = state == RESTORING && reveal;
            assign transition_kind = picture_effect;
            assign ramp_out = state == VISIBLE ? FADE_FRAMES-1 :
                              state == BLACK ? 0 : intensity;
        end
    endgenerate
endmodule
