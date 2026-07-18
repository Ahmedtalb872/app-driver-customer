# Generates a short (~2.4s), professional two-tone "chime" alert as a
# 16-bit PCM mono WAV, since no audio-editing tool is available in this
# environment to produce a real MP3. audioplayers plays WAV assets exactly
# as well as MP3, so lib/core/services/ride_alert_service.dart references
# this file directly - see that file and the final implementation report
# for why the shipped asset is .wav instead of the originally suggested
# .mp3 extension.
$ErrorActionPreference = 'Stop'

$sampleRate = 44100
$amplitude = 0.55 * 32767

# List[Int16] is a reference type, so functions append directly into the
# caller's list instead of returning a collection (PowerShell mangles
# returned generic collections into Object[] on the pipeline).
function Add-Tone {
    param(
        [System.Collections.Generic.List[Int16]]$Target,
        [double]$FrequencyHz,
        [double]$DurationSeconds,
        [double]$FadeSeconds = 0.012
    )
    $count = [int]($sampleRate * $DurationSeconds)
    $fadeCount = [int]($sampleRate * $FadeSeconds)
    for ($i = 0; $i -lt $count; $i++) {
        $t = $i / $sampleRate
        $env = 1.0
        if ($i -lt $fadeCount) { $env = $i / [double]$fadeCount }
        elseif ($i -gt ($count - $fadeCount)) { $env = ($count - $i) / [double]$fadeCount }
        $value = [Math]::Sin(2 * [Math]::PI * $FrequencyHz * $t) * $amplitude * $env
        [void]$Target.Add([Int16][Math]::Round($value))
    }
}

function Add-Silence {
    param(
        [System.Collections.Generic.List[Int16]]$Target,
        [double]$DurationSeconds
    )
    $count = [int]($sampleRate * $DurationSeconds)
    for ($i = 0; $i -lt $count; $i++) { [void]$Target.Add([Int16]0) }
}

$all = New-Object 'System.Collections.Generic.List[Int16]'
# Two-tone "ding-dong" chime, played twice (professional, short, clear).
foreach ($rep in 1..2) {
    Add-Tone -Target $all -FrequencyHz 880 -DurationSeconds 0.18
    Add-Silence -Target $all -DurationSeconds 0.05
    Add-Tone -Target $all -FrequencyHz 1318.5 -DurationSeconds 0.22
    Add-Silence -Target $all -DurationSeconds 0.45
}

$dataBytes = New-Object byte[] ($all.Count * 2)
for ($i = 0; $i -lt $all.Count; $i++) {
    $bytes = [BitConverter]::GetBytes($all[$i])
    $dataBytes[$i * 2] = $bytes[0]
    $dataBytes[$i * 2 + 1] = $bytes[1]
}

$byteRate = $sampleRate * 2
$blockAlign = 2
$dataSize = $dataBytes.Length
$riffSize = 36 + $dataSize

$outPath = Join-Path $PSScriptRoot '..\assets\audio\hudhud_ride_request.wav'
$stream = [System.IO.File]::Create($outPath)
$writer = New-Object System.IO.BinaryWriter($stream)

$writer.Write([char[]]'RIFF')
$writer.Write([Int32]$riffSize)
$writer.Write([char[]]'WAVE')
$writer.Write([char[]]'fmt ')
$writer.Write([Int32]16)
$writer.Write([Int16]1)       # PCM
$writer.Write([Int16]1)       # mono
$writer.Write([Int32]$sampleRate)
$writer.Write([Int32]$byteRate)
$writer.Write([Int16]$blockAlign)
$writer.Write([Int16]16)      # bits per sample
$writer.Write([char[]]'data')
$writer.Write([Int32]$dataSize)
$writer.Write($dataBytes)

$writer.Flush()
$writer.Close()
$stream.Close()

Write-Output "Wrote $outPath ($dataSize bytes of audio data)"
