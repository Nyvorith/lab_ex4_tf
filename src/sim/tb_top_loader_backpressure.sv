`timescale 1ns/1ps
                                                                        
                                                                        
module tb_top_loader_backpressure;
  reg clk=0,rst_n=0;
  always #10 clk=~clk;
  top dut(.clk(clk),.rst_n(rst_n),.key2(1'b1),.key3(1'b1),.key4(1'b1),.sd_miso(1'b1));
  reg start=0, blocked=1, producer=0;
  reg [31:0] data=0;
  integer sent=0,written=0,stalls=0;
  function [23:0] pattern(input integer n);
    pattern=(n*24'h13579b)^24'h5ac389;
  endfunction
  always @(posedge clk) if(rst_n && dut.mem_rst_n) begin
    if(producer && dut.loader_pixel_ready) begin
      sent<=sent+1;
      data<={pattern(sent+1),8'h00};
      if(sent==307199) producer<=0;
    end
    if(producer && !dut.loader_pixel_ready) stalls=stalls+1;
    if(dut.loader_app_wr_en) begin
      if(dut.loader_app_wr_addr !== (479-written/640)*640+written%640 ||
         dut.loader_app_wr_data !== {pattern(written),8'h00})
        $fatal(1,"write mismatch #%0d",written);
      written=written+1;
    end
    if(dut.loader_memory_error!=0)
      $fatal(1,"top handshake caused loader error %h at sent=%0d stalls=%0d",dut.loader_memory_error,sent,stalls);
  end
  initial begin
    force dut.por_done=1;
    force dut.display_valid=0;
    force dut.loader_load_start=start;
    force dut.loader_img_idx=0;
    force dut.Sdr_busy=blocked;
    force dut.pix_stage_valid=producer;
    force dut.pix_stage_data=data;
    repeat(10) @(negedge clk); rst_n=1;
    wait(dut.mem_rst_n); repeat(10) @(negedge clk);
    start=1; @(negedge clk); start=0;
    data={pattern(0),8'h00}; producer=1;
    wait(dut.loader_pixel_ready);
    wait(dut.u_media_frame_loader.fifo_count==512);
    repeat(101) @(negedge clk);
    if(sent!=512 || dut.u_media_frame_loader.fifo_count!=512 || stalls<100)
      $fatal(1,"full-FIFO backpressure not exercised sent=%0d count=%0d stalls=%0d",sent,dut.u_media_frame_loader.fifo_count,stalls);
    blocked=0;
    wait(dut.loader_image_complete==1);
    @(negedge clk);
    if(sent!=307200 || written!=307200 || dut.frame_err_mem!=0)
      $fatal(1,"incomplete frame or latched error sent=%0d written=%0d error=%h",sent,written,dut.frame_err_mem);
    $display("PASS top loader backpressure: held VALID at full FIFO, %0d stalled cycles, 307200 exact writes, no sticky error",stalls);
    $finish;
  end
  initial begin #20000000; $fatal(1,"loader backpressure timeout");end
endmodule
