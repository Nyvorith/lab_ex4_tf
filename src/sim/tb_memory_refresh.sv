`timescale 1ns/1ps
`include "../user_source/hdl_source/include/global_def.v"
                                                                              
                                                                            
module tb_memory_refresh;
  reg clk=0,rst=1;
  always #12.5 clk=~clk;
  wire request,initialized;
  wire ack=request;
  integer cycles=0, previous=0, requests=0;
  sdr_init_ref dut(.Sdr_clk(clk),.Rst(rst),.Sdr_init_req(1'b0),
    .Sdr_init_mode(4'b0011),.Sdr_init_done(initialized),.App_ref_req(1'b0),
    .Sdr_ref_req(request),.Sdr_ref_ack(ack),.Sdr_rw_vld(1'b0));
  initial begin
    if(`SDR_CLK_PERIOD!=25 || `SELF_REFRESH_INTERVAL!=1250)
      $fatal(1,"incorrect refresh macro: period=%0d interval=%0d",`SDR_CLK_PERIOD,`SELF_REFRESH_INTERVAL);
    repeat(5) @(negedge clk); rst=0;
    wait(initialized);
    while(requests<5) begin
      @(negedge clk); cycles=cycles+1;
      if(request) begin
        if(previous!=0 && cycles-previous!=1251)
          $fatal(1,"refresh gap is %0d, expected 1251",cycles-previous);
        previous=cycles; requests=requests+1;
      end
    end
    $display("PASS real SDRAM refresh control: 25ns, interval macro 1250, actual request gap 1251 clocks (31.275us)");
    $finish;
  end
  initial begin #5000000; $fatal(1,"refresh timeout"); end
endmodule
