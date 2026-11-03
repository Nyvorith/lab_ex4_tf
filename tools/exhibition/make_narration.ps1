$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Speech
$root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out = Join-Path $root 'assets/exhibition/narration/tf_card'
New-Item -ItemType Directory -Force -Path $out | Out-Null
                                                                             
$texts = @(1..4 | ForEach-Object {
    [System.IO.File]::ReadAllText((Join-Path (Split-Path $out) ('AUDIO{0}.txt' -f $_)), [System.Text.Encoding]::UTF8).Trim()
})
$speaker = New-Object System.Speech.Synthesis.SpeechSynthesizer
try {
    $speaker.SelectVoice('Microsoft Huihui Desktop')
    $speaker.Rate = 1
    $speaker.Volume = 80
    $format = New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo(48000, [System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen, [System.Speech.AudioFormat.AudioChannel]::Mono)
    for ($i=0; $i -lt $texts.Count; $i++) {
        $path = Join-Path $out ('AUDIO{0}.PCM' -f ($i+1))
        $stream = [System.IO.File]::Create($path)
        try {
            $speaker.SetOutputToAudioStream($stream, $format)
            $speaker.Speak($texts[$i])
            $speaker.SetOutputToNull()
        } finally { $stream.Dispose() }
        [System.IO.File]::WriteAllText((Join-Path (Split-Path $out) ('AUDIO{0}.txt' -f ($i+1))), $texts[$i], [System.Text.UTF8Encoding]::new($false))
        Write-Output $path
    }
} finally { $speaker.Dispose() }
