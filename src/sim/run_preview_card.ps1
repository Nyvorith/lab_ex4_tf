param([string]$IverilogBin='D:\iverilog\bin',
      [string[]]$Tests=@('tb_preview_card','tb_card_thumbnail','tb_card_top'))
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$output=Join-Path $env:TEMP ('card_'+[guid]::NewGuid()+'.vvp')
Push-Location $root
try {
    $hdl=Join-Path $root 'src\user_source\hdl_source'
    $sources=@(Get-ChildItem -LiteralPath $hdl -Filter '*.v' | ForEach-Object FullName)
    $sources+=@(Get-ChildItem -LiteralPath (Join-Path $hdl 'SD') -Filter '*.v' | Where-Object Name -ne 'sdram.v' | ForEach-Object FullName)
    $sources+=Join-Path $hdl 'IP\afifo_16_32_256.v'
    $sources+=Join-Path $hdl 'IP\afifo_32_16_256.v'
    foreach($test in $Tests) {
        & (Join-Path $IverilogBin 'iverilog.exe') -g2012 -s $test -o $output `
            -I (Join-Path $hdl 'SD') -I (Join-Path $hdl 'include') `
            (Join-Path $PSScriptRoot ($test+'.sv')) `
            (Join-Path $PSScriptRoot 'waveform_top_ip_stubs.v') @sources
        if($LASTEXITCODE -ne 0){throw "$test compilation failed"}
        & (Join-Path $IverilogBin 'vvp.exe') $output
        if($LASTEXITCODE -ne 0){throw "$test simulation failed"}
    }
} finally {
    Pop-Location
    if(Test-Path -LiteralPath $output){Remove-Item -LiteralPath $output}
}
