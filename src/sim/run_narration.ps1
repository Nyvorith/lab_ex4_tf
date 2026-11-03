param([string]$IverilogBin = 'D:\iverilog\bin')
$ErrorActionPreference='Stop'
$hdl=Join-Path $PSScriptRoot '../user_source/hdl_source'
$output=Join-Path $env:TEMP ('narration_'+[guid]::NewGuid()+'.vvp')
try {
& "$IverilogBin/iverilog.exe" -g2012 -s tb_narration_catalog -o $output "$PSScriptRoot/tb_narration_catalog.sv" "$hdl/SD/fat32_volume_scanner.v"
if($LASTEXITCODE){throw 'catalog compile'}
& "$IverilogBin/vvp.exe" $output
if($LASTEXITCODE){throw 'catalog test'}
& "$IverilogBin/iverilog.exe" -g2012 -s tb_narration_fat -o $output "$PSScriptRoot/tb_narration_fat.sv" "$hdl/SD/wav_stream_player.v"
if($LASTEXITCODE){throw 'FAT compile'}
& "$IverilogBin/vvp.exe" $output
if($LASTEXITCODE){throw 'FAT test'}
$sources=@(Get-ChildItem -LiteralPath $hdl -Filter '*.v' | ForEach-Object FullName)
$sources+=@(Get-ChildItem -LiteralPath "$hdl/SD" -Filter '*.v' | Where-Object Name -ne 'sdram.v' | ForEach-Object FullName)
$sources+="$hdl/IP/afifo_16_32_256.v"; $sources+="$hdl/IP/afifo_32_16_256.v"
& "$IverilogBin/iverilog.exe" -g2012 -s tb_narration_top -o $output -I "$hdl/SD" -I "$hdl/include" "$PSScriptRoot/tb_narration_top.sv" "$PSScriptRoot/waveform_top_ip_stubs.v" @sources
if($LASTEXITCODE){throw 'top compile'}
& "$IverilogBin/vvp.exe" $output
if($LASTEXITCODE){throw 'top test'}
} finally {if(Test-Path $output){Remove-Item -LiteralPath $output}}
