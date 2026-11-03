param([string]$IverilogBin = 'D:\iverilog\bin')
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$hdl = Join-Path $root 'src\user_source\hdl_source\SD'
$output = Join-Path ([System.IO.Path]::GetTempPath()) ('caption_' + [guid]::NewGuid() + '.vvp')
Push-Location $root
try {
    & (Join-Path $IverilogBin 'iverilog.exe') -g2012 -s tb_exhibit_caption -o $output `
        -I (Join-Path $root 'assets\exhibition\captions\generated') `
        (Join-Path $PSScriptRoot 'tb_exhibit_caption.sv') `
        (Join-Path $hdl 'narration_caption_timeline.v') (Join-Path $hdl 'exhibit_caption_overlay.v') (Join-Path $hdl 'exhibit_caption_roms.v')
    if ($LASTEXITCODE -ne 0) { throw 'Caption compilation failed' }
    & (Join-Path $IverilogBin 'vvp.exe') $output
    if ($LASTEXITCODE -ne 0) { throw 'Caption simulation failed' }
    & (Join-Path $IverilogBin 'iverilog.exe') -g2012 -s tb_artwork_label -o $output `
        (Join-Path $PSScriptRoot 'tb_artwork_label.sv') `
        (Join-Path $hdl 'narration_caption_timeline.v') (Join-Path $hdl 'exhibit_caption_overlay.v') (Join-Path $hdl 'exhibit_caption_roms.v')
    if ($LASTEXITCODE -ne 0) { throw 'Artwork label compilation failed' }
    & (Join-Path $IverilogBin 'vvp.exe') $output
    if ($LASTEXITCODE -ne 0) { throw 'Artwork label simulation failed' }
    $parentHdl = Split-Path $hdl
    $sources = @(Get-ChildItem -LiteralPath $parentHdl -Filter '*.v' | ForEach-Object FullName)
    $sources += @(Get-ChildItem -LiteralPath $hdl -Filter '*.v' | Where-Object Name -ne 'sdram.v' | ForEach-Object FullName)
    $sources += Join-Path $parentHdl 'IP\afifo_16_32_256.v'
    $sources += Join-Path $parentHdl 'IP\afifo_32_16_256.v'
    & (Join-Path $IverilogBin 'iverilog.exe') -g2012 -s tb_top_exhibit_caption -o $output `
        -I $hdl -I (Join-Path $parentHdl 'include') `
        (Join-Path $PSScriptRoot 'tb_top_exhibit_caption.sv') `
        (Join-Path $PSScriptRoot 'waveform_top_ip_stubs.v') @sources
    if ($LASTEXITCODE -ne 0) { throw 'Top caption compilation failed' }
    & (Join-Path $IverilogBin 'vvp.exe') $output
    if ($LASTEXITCODE -ne 0) { throw 'Top caption simulation failed' }
} finally {
    Pop-Location
    if (Test-Path -LiteralPath $output) { Remove-Item -LiteralPath $output }
}
