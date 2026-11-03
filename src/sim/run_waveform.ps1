param([string]$IverilogBin = 'D:\iverilog\bin')
$ErrorActionPreference = 'Stop'
$hdl = Join-Path $PSScriptRoot '..\user_source\hdl_source'
$output = Join-Path ([System.IO.Path]::GetTempPath()) ('lab_ex4_waveform_' + [guid]::NewGuid() + '.vvp')
try {
    & (Join-Path $IverilogBin 'iverilog.exe') -g2012 -s tb_audio_waveform -o $output `
        (Join-Path $PSScriptRoot 'tb_audio_waveform.sv') `
        (Join-Path $hdl 'SD\promax_audio_waveform.v')
    if ($LASTEXITCODE -ne 0) { throw 'Waveform compilation failed' }
    & (Join-Path $IverilogBin 'vvp.exe') $output
    if ($LASTEXITCODE -ne 0) { throw 'Waveform simulation failed' }

    $sources = @(Get-ChildItem -LiteralPath $hdl -Filter '*.v' | ForEach-Object FullName)
    $sources += @(Get-ChildItem -LiteralPath (Join-Path $hdl 'SD') -Filter '*.v' |
        Where-Object Name -ne 'sdram.v' | ForEach-Object FullName)
    $sources += Join-Path $hdl 'IP\afifo_16_32_256.v'
    $sources += Join-Path $hdl 'IP\afifo_32_16_256.v'
    & (Join-Path $IverilogBin 'iverilog.exe') -g2012 -s tb_top_audio_waveform -o $output `
        -I (Join-Path $hdl 'SD') -I (Join-Path $hdl 'include') `
        (Join-Path $PSScriptRoot 'tb_top_audio_waveform.sv') `
        (Join-Path $PSScriptRoot 'waveform_top_ip_stubs.v') @sources
    if ($LASTEXITCODE -ne 0) { throw 'Top waveform compilation failed' }
    & (Join-Path $IverilogBin 'vvp.exe') $output
    if ($LASTEXITCODE -ne 0) { throw 'Top waveform simulation failed' }
} finally {
    if (Test-Path -LiteralPath $output) { Remove-Item -LiteralPath $output }
}
