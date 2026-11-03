`timescale 1ns/1ps
                                                                            
                                                                               
module tb_memory_bandwidth;
  reg mem_clk=0, pix_clk=0, rst_n=0;
  always #12.5 mem_clk=~mem_clk;          
  always #20 pix_clk=~pix_clk;            
  reg frame_start=0, consume=0, load_start=0;
  wire ri,ra,wi,wa,rd,wr,ready,valid,underflow,done;
  wire writer_window_safe;
  wire [20:0] raddr,waddr;
  wire [31:0] wdata;
  wire [23:0] rgb;
  wire [7:0] rerror,werror;
  wire [3:0] complete;
  integer sent=0, writes=0, pixels=0, frames=0, refreshes=0;
  reg [31:0] addresses[0:5];
  reg [5:0] vpipe=0;
  integer i, tail=0, refresh_timer=0, refresh_left=0;
  reg refresh_pending=0;
  wire refresh=refresh_left!=0;
  wire busy=refresh || tail!=0 || refresh_pending;
                                                           
  wire gw=wi && !ra && !ri && writer_window_safe;
  wire gr=ri && !wa;
  function [23:0] pattern(input integer n);
    pattern=(n*24'h13579b)^24'h5ac389;
  endfunction
  media_frame_reader reader(
    .mem_clk(mem_clk),.mem_rst_n(rst_n),.controller_init_done(1'b1),
    .controller_busy(busy),.refresh_active(refresh),.bus_grant(gr),
    .rd_burst_active(ra),.rd_start_intent(ri),.app_rd_en(rd),.app_rd_addr(raddr),
    .writer_window_safe(writer_window_safe),
    .sdram_rd_valid(vpipe[5]),.sdram_rd_data({pattern(addresses[5]),8'h00}),
    .pix_clk(pix_clk),.pix_rst_n(rst_n),.frame_start(frame_start),
    .active_index(2'd0),.pixel_consume(consume),.pixel_rgb(rgb),
    .pixel_valid(valid),.underflow(underflow),.reader_error(rerror));
  wire send_pixel=ready && sent<307200;
  media_frame_loader loader(
    .clk(mem_clk),.rst_n(rst_n),.load_start(load_start),.image_index(2'd1),
    .pixel_valid(send_pixel),.pixel_rgb(pattern(sent)),.pixel_ready(ready),
    .frame_commit(1'b0),.decode_error(8'd0),.load_done(done),
    .image_complete(complete),.memory_error(werror),
    .controller_init_done(1'b1),.controller_busy(busy),.refresh_active(refresh),
    .bus_grant(gw),.wr_burst_active(wa),.wr_start_intent(wi),
    .app_wr_en(wr),.app_wr_addr(waddr),.app_wr_data(wdata));
  always @(posedge mem_clk) if(rst_n) begin
    if(send_pixel) sent<=sent+1;
    if(wr) begin
      if(waddr!==307200+(479-writes/640)*640+writes%640 ||
         wdata!=={pattern(writes),8'h00})
        $fatal(1,"write mismatch at %0d addr=%0d data=%h",writes,waddr,wdata);
      writes=writes+1;
    end
    if((rd && wr)||(ra && wa)) $fatal(1,"overlapping read/write burst");
    if(rerror!=0 || werror!=0 || underflow) $fatal(1,"memory error r=%h w=%h underflow=%b",rerror,werror,underflow);
    for(i=5;i>0;i=i-1) begin
      addresses[i]<=addresses[i-1]; vpipe[i]<=vpipe[i-1];
    end
    addresses[0]<=raddr; vpipe[0]<=rd;
                                                                      
                                                                            
    if(rd || wr) tail<=8;
    else if(tail!=0) tail<=tail-1;
    if(refresh_timer==311) begin refresh_timer<=0; refresh_pending<=1; end
    else refresh_timer<=refresh_timer+1;
    if(refresh_left!=0) refresh_left<=refresh_left-1;
    else if(refresh_pending && !ra && !wa && !rd && !wr && tail==0) begin
                                                                           
                                                                              
      refresh_pending<=0; refresh_left<=20; refreshes=refreshes+1;
    end
  end
  integer x,y,f;
  initial begin
    #200; @(negedge mem_clk); rst_n=1;
                                                                        
                                                                            
    fork
      begin
        #1400000; @(negedge mem_clk); load_start=1;
        @(negedge mem_clk); load_start=0;
      end
    join_none
    for(f=0;f<3;f=f+1) begin
      pixels=0;
      for(y=0;y<525;y=y+1) for(x=0;x<800;x=x+1) begin
        @(negedge pix_clk);
        frame_start=(x==0 && y==0);
        consume=(x>=160 && y>=45);
        @(posedge pix_clk);
        if(consume) begin
          if(!valid || rgb!==pattern(pixels))
            $fatal(1,"frame %0d pixel %0d: valid=%b rgb=%h expected=%h",f,pixels,valid,rgb,pattern(pixels));
          pixels=pixels+1;
        end
      end
      if(pixels!=307200) $fatal(1,"short frame");
      frames=frames+1;
    end
    if(sent!=307200 || writes!=307200 || complete!=4'b0010 || refreshes<100)
      $fatal(1,"incomplete load sent=%0d writes=%0d complete=%b refresh=%0d",sent,writes,complete,refreshes);
    $display("PASS memory bandwidth: %0d frames, 921600 exact pixels, %0d writes, %0d refreshes",frames,writes,refreshes);
    $finish;
  end
  initial begin #60000000; $fatal(1,"bandwidth test timeout"); end
endmodule
