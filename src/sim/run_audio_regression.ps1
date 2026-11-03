param([string]$IverilogBin = 'D:\iverilog\bin')
$ErrorActionPreference = 'Stop'
$hdl = Join-Path $PSScriptRoot '..\user_source\hdl_source'
$output = Join-Path ([System.IO.Path]::GetTempPath()) ('lab_ex4_audio_' + [guid]::NewGuid() + '.vvp')
try {
    & (Join-Path $IverilogBin 'iverilog.exe') -g2012 -s tb_wav_stream_regression -o $output `
        (Join-Path $PSScriptRoot 'tb_wav_stream_regression.sv') `
        (Join-Path $hdl 'SD\wav_stream_player.v') `
        (Join-Path $hdl 'SD\fifo_prefetch_2.v') `
        (Join-Path $hdl 'IP\afifo_32_16_256.v')
    if ($LASTEXITCODE -ne 0) { throw 'WAV regression compilation failed' }
    & (Join-Path $IverilogBin 'vvp.exe') $output
    if ($LASTEXITCODE -ne 0) { throw 'WAV regression failed' }

    $sources = @(Get-ChildItem -LiteralPath (Join-Path $hdl 'SD') -Filter '*.v' |
        Where-Object Name -ne 'sdram.v' | ForEach-Object FullName)
    & (Join-Path $IverilogBin 'iverilog.exe') -g2012 -s tb_sd_audio_arbiter -o $output `
        -I (Join-Path $hdl 'SD') -I (Join-Path $hdl 'include') `
        (Join-Path $PSScriptRoot 'tb_sd_audio_arbiter.sv') @sources
    if ($LASTEXITCODE -ne 0) { throw 'SD arbiter regression compilation failed' }
    & (Join-Path $IverilogBin 'vvp.exe') $output
    if ($LASTEXITCODE -ne 0) { throw 'SD arbiter regression failed' }
} finally {
    if (Test-Path -LiteralPath $output) { Remove-Item -LiteralPath $output }
}
