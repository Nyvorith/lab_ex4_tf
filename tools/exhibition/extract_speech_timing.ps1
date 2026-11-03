$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Speech
Add-Type -ReferencedAssemblies System.Speech -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.IO;
using System.Speech.Synthesis;
using System.Speech.AudioFormat;
public class ExhibitionSpeechTiming {
    public static string[] Extract(string text, string output, int rate) {
        var rows = new List<string>();
        using (var speaker = new SpeechSynthesizer()) {
            speaker.SelectVoice("Microsoft Huihui Desktop");
            speaker.Rate = 1; speaker.Volume = 80;
            speaker.SpeakProgress += (sender, e) => rows.Add(e.CharacterPosition + "," + e.CharacterCount + "," + (long)Math.Round(e.AudioPosition.TotalSeconds * rate));
            using (var stream = File.Create(output)) {
                speaker.SetOutputToAudioStream(stream, new SpeechAudioFormatInfo(rate, AudioBitsPerSample.Sixteen, AudioChannel.Mono));
                speaker.Speak(text);
                speaker.SetOutputToNull();
            }
        }
        return rows.ToArray();
    }
}
'@
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$output = Join-Path $root 'assets/exhibition/narration/timing'
New-Item -ItemType Directory -Force -Path $output | Out-Null
foreach ($i in 1..4) {
    $text = [IO.File]::ReadAllText((Join-Path $root "assets/exhibition/narration/AUDIO$i.txt"), [Text.Encoding]::UTF8).Trim()
    $tempPcm = Join-Path $env:TEMP ('speech_timing_' + [guid]::NewGuid() + '.pcm')
    try {
        $rows = [ExhibitionSpeechTiming]::Extract($text, $tempPcm, 48000)
        $actual = (Get-FileHash -LiteralPath $tempPcm -Algorithm SHA256).Hash
        $original = (Get-FileHash -LiteralPath (Join-Path $root "assets/exhibition/narration/tf_card/AUDIO$i.PCM") -Algorithm SHA256).Hash
        if ($actual -ne $original) { throw "AUDIO$i synthesis differs from existing PCM; cannot reuse timings." }
        $nativePcm = Join-Path $env:TEMP ('native_timing_' + [guid]::NewGuid() + '.pcm')
        try {
            $nativeRows = [ExhibitionSpeechTiming]::Extract($text, $nativePcm, 16000)
            if ($nativeRows.Count -ne $rows.Count) { throw 'Speech event count differs across formats.' }
            $durationDifference = [Math]::Abs((Get-Item $nativePcm).Length * 3 - (Get-Item $tempPcm).Length)
            if ($durationDifference -gt 192) { throw 'Native/output durations do not match.' }
            $corrected = @()
            for ($j = 0; $j -lt $rows.Count; $j++) {
                $parts = $rows[$j].Split(',')
                $native = $nativeRows[$j].Split(',')
                $sample = [long][Math]::Round([long]$parts[2] / 3.0)
                if ($parts[0] -ne $native[0] -or $parts[1] -ne $native[1] -or [Math]::Abs($sample - [long]$native[2] * 3) -gt 96) {
                    throw 'Native and converted word positions differ by more than 2ms.'
                }
                if ($sample -ge (Get-Item $tempPcm).Length / 2) { throw 'Speech event beyond file.' }
                $corrected += ($parts[0] + ',' + $parts[1] + ',' + $sample)
            }
            $rows = $corrected
        } finally { if (Test-Path -LiteralPath $nativePcm) { Remove-Item -LiteralPath $nativePcm } }
        [IO.File]::WriteAllLines((Join-Path $output "AUDIO$i.csv"), @('character_start,character_count,sample_start') + $rows, [Text.UTF8Encoding]::new($false))
        Write-Output "AUDIO$i exact PCM SHA256 match; $($rows.Count) speech events."
    } finally {
        if (Test-Path -LiteralPath $tempPcm) { Remove-Item -LiteralPath $tempPcm }
    }
}
