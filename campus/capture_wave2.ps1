param([switch]$Verify,[switch]$Motion,[switch]$EncodeOnly)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\tools\find_apps.ps1"
$waveOutput=Join-Path $PSScriptRoot 'renders\wave2'
New-Item -ItemType Directory -Force -Path $waveOutput | Out-Null
function Invoke-WaveEncode {
    $waveEncoder=Start-Process -FilePath $BlenderExe -ArgumentList @('--background','--factory-startup','--python-exit-code','1','--python',('"'+"$PSScriptRoot\tools\encode_life_video.py"+'"'),'--',('"'+$waveOutput+'"')) -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput "$waveOutput\encode.log" -RedirectStandardError "$waveOutput\encode_stderr.log"
    if ($waveEncoder.ExitCode -ne 0) { throw 'Wave2 encoding failed' }
}
if ($EncodeOnly) { Invoke-WaveEncode; return }
$waveArgs=@('--path',"$PSScriptRoot\godot",'res://scenes/diorama.tscn')
if ($Verify) { $waveArgs+=@('--headless','--log-file',"$waveOutput\qa.log",'--','--lookdev','--wave2-qa') }
elseif ($Motion) { $waveArgs+=@('--log-file',"$waveOutput\motion.log",'--','--lookdev','--ultra','--wave2-motion') }
else { $waveArgs+=@('--log-file',"$waveOutput\capture.log",'--','--lookdev','--ultra','--capture','--wave2-capture') }
& $GodotExe @waveArgs
if ($LASTEXITCODE -ne 0) { throw 'Wave2 render/validation failed' }
if ($Motion) { Invoke-WaveEncode }
