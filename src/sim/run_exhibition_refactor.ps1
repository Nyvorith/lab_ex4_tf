param([string]$IverilogBin = 'D:\iverilog\bin')
$ErrorActionPreference = 'Stop'
$hdl = Join-Path $PSScriptRoot '..\user_source\hdl_source\SD'
$output = Join-Path ([System.IO.Path]::GetTempPath()) ('exhibition_refactor_' + [guid]::NewGuid() + '.vvp')
try {
    foreach ($test in @('transition', 'waveform', 'status_osd')) {
        $reference = switch ($test) {
            'transition' { 'video_fade_reference_4k.v' }
            'waveform' { 'audio_waveform_reference_4k.v' }
            'status_osd' { 'status_osd_reference_4m.v' }
        }
        $source = switch ($test) {
            'transition' { 'video_fade_transition.v' }
            'waveform' { 'promax_audio_waveform.v' }
            'status_osd' { 'status_osd_overlay.v' }
        }
        & (Join-Path $IverilogBin 'iverilog.exe') -g2012 -s "tb_${test}_refactor" -o $output `
            (Join-Path $PSScriptRoot "tb_${test}_refactor.sv") `
            (Join-Path $PSScriptRoot $reference) (Join-Path $hdl $source)
        if ($LASTEXITCODE -ne 0) { throw "$test comparison compilation failed" }
        & (Join-Path $IverilogBin 'vvp.exe') $output
        if ($LASTEXITCODE -ne 0) { throw "$test comparison failed" }
    }
} finally {
    if (Test-Path -LiteralPath $output) { Remove-Item -LiteralPath $output }
}
