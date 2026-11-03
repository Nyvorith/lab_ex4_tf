param([string]$IverilogBin = 'D:\iverilog\bin')
$ErrorActionPreference = 'Stop'
$hdl = Join-Path $PSScriptRoot '..\user_source\hdl_source'
$output = Join-Path ([System.IO.Path]::GetTempPath()) ('audio_control_' + [guid]::NewGuid() + '.vvp')
try {
    $sources = @(Get-ChildItem -LiteralPath $hdl -Filter '*.v' | ForEach-Object FullName)
    $sources += @(Get-ChildItem -LiteralPath (Join-Path $hdl 'SD') -Filter '*.v' |
        Where-Object Name -ne 'sdram.v' | ForEach-Object FullName)
    $sources += Join-Path $hdl 'IP\afifo_16_32_256.v'
    $sources += Join-Path $hdl 'IP\afifo_32_16_256.v'
    & (Join-Path $IverilogBin 'iverilog.exe') -g2012 -s tb_audio_control -o $output `
        -I (Join-Path $hdl 'SD') -I (Join-Path $hdl 'include') `
        (Join-Path $PSScriptRoot 'tb_audio_control.sv') `
        (Join-Path $PSScriptRoot 'waveform_top_ip_stubs.v') @sources
    if ($LASTEXITCODE -ne 0) { throw 'Audio control compilation failed' }
    & (Join-Path $IverilogBin 'vvp.exe') $output
    if ($LASTEXITCODE -ne 0) { throw 'Audio control simulation failed' }
} finally {
    if (Test-Path -LiteralPath $output) { Remove-Item -LiteralPath $output }
}
