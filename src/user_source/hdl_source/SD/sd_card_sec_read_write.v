module sd_card_sec_read_write
#(
	parameter  SPI_LOW_SPEED_DIV = 248,
	parameter  SPI_HIGH_SPEED_DIV = 0,

	parameter  integer CLK_FREQ_HZ = 100_000_000,
	parameter  integer WATCHDOG_MS = 1000,

	parameter  integer INIT_TIMEOUT_MS = 3000
)
(
	input            clk,
	input            rst,
	output reg       sd_init_done,
	output reg       wdt_recover,
	input            sd_sec_read,
	input[31:0]      sd_sec_read_addr,
	output[7:0]      sd_sec_read_data,
	output           sd_sec_read_data_valid,
	output           sd_sec_read_end,
	input            sd_sec_write,
	input[31:0]      sd_sec_write_addr,
	input[7:0]       sd_sec_write_data,
	output           sd_sec_write_data_req,
	output           sd_sec_write_end,

	output reg[15:0] spi_clk_div,
	output reg       cmd_req,
	input            cmd_req_ack,
	input            cmd_req_error,
	output reg[47:0] cmd,
	output reg[7:0]  cmd_r1,
	output reg[15:0] cmd_data_len,
	output reg       block_read_req,
	input            block_read_valid,
	input[7:0]       block_read_data,
	input            block_read_req_ack,
	output reg       block_write_req,
	output[7:0]      block_write_data,
	input            block_write_data_rd,
	input            block_write_req_ack
);
reg[7:0] read_data;
reg[31:0] timer;
reg[4:0]  state_d0;
reg[31:0] wdt_cnt;
reg[31:0] init_cnt;

localparam S_IDLE               = 0;
localparam S_CMD0               = 1;
localparam S_CMD8               = 2;
localparam S_CMD55              = 3;
localparam S_CMD41              = 4;
localparam S_CMD17              = 5;
localparam S_READ               = 6;
localparam S_CMD24              = 7;
localparam S_WRITE              = 8;
localparam S_ERR                = 14;
localparam S_WRITE_END          = 15;
localparam S_READ_END           = 16;
localparam S_WAIT_READ_WRITE    = 17;
localparam S_CMD16              = 18;

reg[4:0]                       state;
reg[31:0]                      sec_addr;

wire[31:0]                     wdt_limit = (CLK_FREQ_HZ / 1000) * WATCHDOG_MS;

wire                           wdt_armed = (state == S_CMD17) || (state == S_READ)  ||
                                           (state == S_CMD24) || (state == S_WRITE) ||
                                           (state == S_READ_END) || (state == S_WRITE_END);

wire                           wdt_stalled = (state == state_d0) && wdt_armed && (wdt_cnt >= wdt_limit);

wire                           in_init_seq = (state == S_IDLE) || (state == S_CMD0) ||
                                              (state == S_CMD8)  || (state == S_CMD55) ||
                                              (state == S_CMD41) || (state == S_CMD16);
wire[31:0]                     init_limit  = (CLK_FREQ_HZ / 1000) * INIT_TIMEOUT_MS;
wire                           init_timeout = in_init_seq && (init_cnt >= init_limit);
assign sd_sec_read_data_valid = (state == S_READ) && block_read_valid;
assign sd_sec_read_data = block_read_data;
assign sd_sec_read_end = (state == S_READ_END);
assign sd_sec_write_data_req = (state == S_WRITE) && block_write_data_rd;
assign block_write_data = sd_sec_write_data;
assign sd_sec_write_end = (state == S_WRITE_END);

always@(posedge clk or posedge rst)
begin
	if(rst == 1'b1)
	begin
		state <= S_IDLE;
		cmd_req <= 1'b0;
		cmd_data_len <= 16'd0;
		cmd_r1 <= 8'd0;
		cmd <= 48'd0;
		spi_clk_div <= SPI_LOW_SPEED_DIV[15:0];
		block_write_req <= 1'b0;
		block_read_req <= 1'b0;
		sec_addr <= 32'd0;
		sd_init_done <= 1'b0;
	end
	else if(wdt_stalled || init_timeout)
	begin

		state           <= S_IDLE;
		cmd_req         <= 1'b0;
		block_read_req  <= 1'b0;
		block_write_req <= 1'b0;
		sd_init_done    <= 1'b0;
	end
	else
		case(state)
			S_IDLE:
			begin
				state <= S_CMD0;
				sd_init_done <= 1'b0;
				spi_clk_div <= SPI_LOW_SPEED_DIV[15:0];
			end
			S_CMD0:
			begin
				if(cmd_req_ack & ~cmd_req_error)
				begin
					state <= S_CMD8;
					cmd_req <= 1'b0;
				end
				else
				begin
					cmd_req <= 1'b1;
					cmd_data_len <= 16'd0;
					cmd_r1 <= 8'h01;
					cmd <= {8'd0,8'h00,8'h00,8'h00,8'h00,8'h95};
				end
			end
			S_CMD8:
			begin
				if(cmd_req_ack & ~cmd_req_error)
				begin
					state <= S_CMD55;
					cmd_req <= 1'b0;
				end
				else if(cmd_req_ack)
				begin

					state <= S_CMD55;
					cmd_req <= 1'b0;
				end
				else
				begin
					cmd_req <= 1'b1;
					cmd_data_len <= 16'd4;
					cmd_r1 <= 8'h01;
					cmd <= {8'd8,8'h00,8'h00,8'h01,8'haa,8'h87};
				end
			end
			S_CMD55:
			begin
				if(cmd_req_ack & ~cmd_req_error)
				begin
					state <= S_CMD41;
					cmd_req <= 1'b0;
				end
				else
				begin
					cmd_req <= 1'b1;
					cmd_data_len <= 16'd0;
					cmd_r1 <= 8'h01;
					cmd <= {8'd55,8'h00,8'h00,8'h00,8'h00,8'hff};
				end
			end
			S_CMD41:
			begin
				if(cmd_req_ack & ~cmd_req_error)
				begin
					state <= S_CMD16;
					cmd_req <= 1'b0;
					sd_init_done <= 1'b1;
					spi_clk_div <= SPI_HIGH_SPEED_DIV[15:0];
				end
				else if(cmd_req_ack)
				begin
					state <= S_CMD55;
				end
				else
				begin
					cmd_req <= 1'b1;
					cmd_data_len <= 16'd0;
					cmd_r1 <= 8'h00;
					cmd <= {8'd41,8'h40,8'h00,8'h00,8'h00,8'hff};
				end
			end
			S_CMD16:
			begin
				if(cmd_req_ack & ~cmd_req_error)
				begin
					state <= S_WAIT_READ_WRITE;
					cmd_req <= 1'b0;
					sd_init_done <= 1'b1;
					spi_clk_div <= SPI_HIGH_SPEED_DIV[15:0];
				end
				else if(cmd_req_ack)
				begin
					state <= S_CMD55;
				end
				else
				begin
					cmd_req <= 1'b1;
					cmd_data_len <= 16'd0;
					cmd_r1 <= 8'h00;
					cmd <= {8'd16,32'd512,8'hff};
				end
			end
			S_WAIT_READ_WRITE:
			begin
				if(sd_sec_write ==  1'b1)
				begin
					state <= S_CMD24;
					sec_addr <= sd_sec_write_addr;
				end
				else if(sd_sec_read == 1'b1)
				begin
					state <= S_CMD17;
					sec_addr <= sd_sec_read_addr;
				end

				spi_clk_div <= 16'd0;
			end
			S_CMD24:
			begin
				if(cmd_req_ack & ~cmd_req_error)
				begin
					state <= S_WRITE;
					cmd_req <= 1'b0;
				end
				else
				begin
					cmd_req <= 1'b1;
					cmd_data_len <= 16'd0;
					cmd_r1 <= 8'h00;
					cmd <= {8'd24,sec_addr,8'hff};

				end
			end
			S_WRITE:
			begin
				if(block_write_req_ack == 1'b1)
				begin
					block_write_req <= 1'b0;
					state <= S_WRITE_END;
				end
				else
					block_write_req <= 1'b1;
			end
			S_CMD17:
			begin
				if(cmd_req_ack & ~cmd_req_error)
				begin
					state <= S_READ;
					cmd_req <= 1'b0;
				end
				else
				begin
					cmd_req <= 1'b1;
					cmd_data_len <= 16'd0;
					cmd_r1 <= 8'h00;
					cmd <= {8'd17,sec_addr,8'hff};
				end
			end
			S_READ:
			begin
				if(block_read_req_ack)
				begin
					state <= S_READ_END;
					block_read_req <= 1'b0;
				end
				else
				begin
					block_read_req <= 1'b1;
				end
			end
			S_WRITE_END:
			begin
				state <= S_WAIT_READ_WRITE;
			end
			S_READ_END:
			begin
				state <= S_WAIT_READ_WRITE;
			end
			default:
				state <= S_IDLE;
		endcase
end

always@(posedge clk or posedge rst)
begin
	if(rst == 1'b1)
	begin
		state_d0    <= S_IDLE;
		wdt_cnt     <= 32'd0;
		init_cnt    <= 32'd0;
		wdt_recover <= 1'b0;
	end
	else
	begin
		state_d0 <= state;

		if(state != state_d0)
			wdt_cnt <= 32'd0;
		else if(wdt_armed && (wdt_cnt < wdt_limit))
			wdt_cnt <= wdt_cnt + 32'd1;

		if(!in_init_seq || init_timeout)
			init_cnt <= 32'd0;
		else if(init_cnt < init_limit)
			init_cnt <= init_cnt + 32'd1;

		wdt_recover <= wdt_stalled | init_timeout;
	end
end
endmodule
