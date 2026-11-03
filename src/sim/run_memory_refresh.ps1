param([string]$IverilogBin='D:\iverilog\bin')
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$prefix=Join-Path $env:TEMP ('refresh_'+[guid]::NewGuid()+'.v')
$output=$prefix+'.vvp'
                                                                            
                                                                               
$source=Get-Content (Join-Path $root 'src/user_source/hdl_source/include/sdr_init_ref.enc.v') -Raw
$plain=($source -split '`pragma protect begin_protected',2)[0]
[IO.File]::WriteAllText($prefix,$plain+"`nendmodule`n")
Push-Location (Join-Path $root 'src/td_project')
try {
    & (Join-Path $IverilogBin 'iverilog.exe') -g2012 -s tb_memory_refresh -o $output `
      (Join-Path $PSScriptRoot 'tb_memory_refresh.sv') $prefix
    if($LASTEXITCODE -ne 0) {throw 'Refresh compile failed'}
    & (Join-Path $IverilogBin 'vvp.exe') $output
    if($LASTEXITCODE -ne 0) {throw 'Refresh simulation failed'}
} finally {
    Pop-Location
    Remove-Item -LiteralPath $prefix,$output -ErrorAction SilentlyContinue
}
