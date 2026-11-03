`timescale 1ns/1ps
module tb_lesson13_bmp_scaler;
`ifdef TEST_ASPECT
    localparam ASPECT=1;
`else
    localparam ASPECT=0;
`endif
    reg clk=0, rst=1, start=0, bv=0, fd=0, ack=0, ready=1;
    reg [7:0] data=0, fs=0;
    wire pause_file, req, pv, err;
    wire [23:0] pixel;
    wire [2:0] code;
    wire [31:0] source_size;
    wire [19:0] fitted_size;
    integer w,h,size,limit,n,count,errors,cycle=0,requests,expected_error;
    integer px,py,sx,sy,dw,dh,lpad,bpad;
    reg [23:0] expected;
    reg [7:0] header[0:53];
    bmp_fit_scaler #(.PIXEL_GAP(1),.KEEP_ASPECT(ASPECT)) dut(
        .clk(clk),.rst(rst),.start(start),.byte_valid(bv),.byte_data(data),
        .file_done(fd),.fs_error(fs),.pause_file(pause_file),
        .write_req(req),.write_ack(ack),.pixel_ready(ready),
        .pixel_valid(pv),.pixel(pixel),.error_pulse(err),.error_code(code),
        .source_size(source_size),.fitted_size(fitted_size));
    always #5 clk=~clk;
    function [23:0] color(input integer x,y);
        color={(8'(x)),(8'(y)),(8'(x^y))};
    endfunction
    always @(negedge clk) begin
        cycle=cycle+1;
        ready=(cycle%113<71);                                       
        ack=req && cycle%29==0;
        if(ack) requests=requests+1;
        if(pv) begin
            if(source_size!=={16'(w),16'(h)} || fitted_size!=={10'(dw),10'(dh)})
                $fatal(1,"Decoded metadata does not match emitted picture");
            if(count>=307200) $fatal(1,"extra output pixel");
            px=count%640; py=count/640;
            sx=((px-lpad)*w)/dw;
            sy=h-1-((dh-1-(py-bpad))*h)/dh;
            expected=(px<lpad || px>=lpad+dw || py<bpad || py>=bpad+dh) ? 24'd0 : color(sx,sy);
            if(pixel!==expected) $fatal(1,"%0dx%0d output(%0d,%0d)=%h expected %h source(%0d,%0d)",w,h,px,py,pixel,expected,sx,sy);
            count=count+1;
        end
        if(err) begin
            errors=errors+1;
            if(code!==expected_error) $fatal(1,"error code %0d expected %0d",code,expected_error);
        end
        if(dut.used>1024 || dut.overflow_seen) $fatal(1,"byte FIFO overflow");
    end
    task run_image(input integer wi,hi,truncate,bad);
        integer i,j,rowstride,at,x,y,c;
        reg [23:0] rgb;
        begin
            @(posedge clk); #1;
            w=wi; h=hi; count=0; errors=0; requests=0;
            dw=640;dh=480;
            if(ASPECT) begin
                if(w*480>=h*640) dh=(h*640)/w;
                else dw=(w*480)/h;
                if(dw<1) dw=1;
                if(dh<1) dh=1;
            end
            lpad=(640-dw)/2;bpad=(480-dh)/2;
            expected_error=bad ? 1 : (truncate ? 3 : 0);
            for(i=0;i<54;i=i+1) header[i]=0;
            header[0]=8'h42;header[1]=8'h4d;header[10]=54;header[14]=40;
            header[18]=w;header[19]=w>>8;header[22]=h;header[23]=h>>8;
            header[26]=1;header[28]=bad ? 32 : 24;
            rowstride=(w*3+3)&~3;
            size=54+rowstride*h; limit=truncate ? size-7 : size;
            start=1;
            @(posedge clk);#1;start=0;
            i=0;
            while(i<limit) begin
                                                                            
                                                                         
                wait(!pause_file);
                for(j=0;j<512 && i<limit;j=j+1) begin
                    if(i<54) data=header[i];
                    else begin
                        at=i-54; y=at/rowstride;x=(at%rowstride)/3;c=at%rowstride%3;
                        rgb=color(x,y);
                        data=(x>=w) ? 8'hee : (rgb>>(c*8));
                    end
                    bv=1;
                    @(posedge clk);#1;i=i+1;
                end
                bv=0;
                repeat(8) begin @(posedge clk);#1; end
            end
            fd=1;@(posedge clk);#1;fd=0;
            wait(!dut.active);
            repeat(3) @(posedge clk);
            if(expected_error==0 && (count!=307200 || errors!=0 || requests!=1))
                $fatal(1,"%0dx%0d count=%0d errors=%0d requests=%0d",w,h,count,errors,requests);
            if(expected_error!=0 && errors!=1) $fatal(1,"missing expected error");
            $display("PASS %0dx%0d truncate=%0d bad=%0d pixels=%0d",w,h,truncate,bad,count);
        end
    endtask
    initial begin
        count=0;errors=0;requests=0;expected_error=0;w=640;h=480;
        repeat(5) @(posedge clk);#1;rst=0;
        run_image(640,480,0,0);
        run_image(320,240,0,0);
        run_image(800,600,0,0);
        run_image(1024,768,0,0);
        run_image(1920,1080,0,0);
        run_image(321,239,0,0);
        run_image(480,640,0,0);
        run_image(641,479,0,0);
        run_image(1,1,0,0);
        run_image(2048,1,0,0);
        run_image(1,2048,0,0);
        run_image(32,24,1,0);
        run_image(32,24,0,1);
        run_image(640,480,0,0);                                
        $display("PASS lesson13 scaler KEEP_ASPECT=%0d",ASPECT);$finish;
    end
    initial begin #3000000000; $fatal(1,"watchdog"); end
endmodule
