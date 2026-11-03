param([string]$OutputDirectory = 'artifacts/final_lesson13_scaling_test/test_images')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$outputPath = Join-Path $projectRoot $OutputDirectory
[void][System.IO.Directory]::CreateDirectory($outputPath)
$sourcePaths = @(Get-ChildItem -LiteralPath (Join-Path $projectRoot 'doc/convert/output_bmp') -Filter '*.bmp' | Sort-Object Name)
$sizes = @(@(320,240), @(800,600), @(1024,768), @(1920,1080))
for ($i=0; $i -lt 4; $i++) {
    $source = [System.Drawing.Image]::FromFile($sourcePaths[$i].FullName)
    $bmp = [System.Drawing.Bitmap]::new($sizes[$i][0], $sizes[$i][1], [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bmp)
    try {
        $graphics.DrawImage($source, 0, 0, $bmp.Width, $bmp.Height)
        $path = Join-Path $outputPath ('PIC{0}.BMP' -f ($i+1))
        $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Bmp)
        $reader = [System.IO.BinaryReader]::new([System.IO.File]::OpenRead($path))
        try {
            $reader.BaseStream.Position = 18
            $width = $reader.ReadInt32()
            $height = $reader.ReadInt32()
            $planes = $reader.ReadUInt16()
            $depth = $reader.ReadUInt16()
            $compression = $reader.ReadUInt32()
            if ($width -ne $sizes[$i][0] -or $height -ne $sizes[$i][1] -or $planes -ne 1 -or $depth -ne 24 -or $compression -ne 0) {
                throw "Unexpected BMP format: $path"
            }
            Write-Output ('PIC{0}.BMP: {1}x{2}, 24-bit, bottom-up, uncompressed' -f ($i+1), $width, $height)
        } finally { $reader.Dispose() }
    } finally { $graphics.Dispose(); $bmp.Dispose(); $source.Dispose() }
}
