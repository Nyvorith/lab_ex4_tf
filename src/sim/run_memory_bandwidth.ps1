param([string]$IverilogBin = 'D:\iverilog\bin')
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$output=Join-Path $env:TEMP ('bandwidth_'+[guid]::NewGuid()+'.vvp')
Push-Location $root
try {
    $top=Get-Content src/user_source/hdl_source/top_tf_hdmi_audio.v -Raw
    if($top -notmatch 'assign bus_grant_wr = loader_wr_start_intent && !reader_rd_burst_active &&\s*!reader_rd_start_intent && reader_writer_window_safe;' -or
       $top -notmatch 'assign bus_grant_rd = reader_rd_start_intent && !loader_wr_burst_active;') {
        throw 'Bandwidth test arbitration no longer matches top-level RTL'
    }
    & (Join-Path $IverilogBin 'iverilog.exe') -g2012 -s tb_memory_bandwidth -o $output `
      src/sim/tb_memory_bandwidth.sv `
      src/user_source/hdl_source/SD/media_frame_reader.v `
      src/user_source/hdl_source/SD/media_frame_loader.v `
      src/user_source/hdl_source/SD/fifo_prefetch_2.v `
      src/user_source/hdl_source/IP/afifo_32_16_256.v
    if($LASTEXITCODE -ne 0) { throw 'Bandwidth compile failed' }
    & (Join-Path $IverilogBin 'vvp.exe') $output
    if($LASTEXITCODE -ne 0) { throw 'Bandwidth simulation failed' }
} finally {
    Pop-Location
    if(Test-Path -LiteralPath $output) { Remove-Item -LiteralPath $output }
}
