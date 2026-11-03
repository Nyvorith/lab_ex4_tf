param([string]$IverilogBin='D:\iverilog\bin', [switch]$Stretch)
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$simOutput=Join-Path $env:TEMP ('aspect_'+[guid]::NewGuid()+'.vvp')
Push-Location $root
try {
    $flags=@('-g2012','-s','tb_lesson13_bmp_scaler','-o',$simOutput)
    if(!$Stretch){$flags+='-DTEST_ASPECT'}
    & (Join-Path $IverilogBin 'iverilog.exe') @flags src/sim/tb_lesson13_bmp_scaler.sv src/user_source/hdl_source/SD/bmp_fit_scaler.v
    if($LASTEXITCODE -ne 0){throw 'Scaler compilation failed'}
    & (Join-Path $IverilogBin 'vvp.exe') $simOutput
    if($LASTEXITCODE -ne 0){throw 'Scaler simulation failed'}
} finally {
    Pop-Location
    if(Test-Path $simOutput){Remove-Item -LiteralPath $simOutput}
}
