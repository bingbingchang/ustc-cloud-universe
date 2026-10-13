param([switch]$Verify,[switch]$Motion,[switch]$EncodeOnly)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\tools\find_apps.ps1"
$axisOutput=Join-Path $PSScriptRoot 'renders\north_axis'
New-Item -ItemType Directory -Force -Path $axisOutput | Out-Null
function Invoke-AxisEncode {
    $axisEncode=Start-Process -FilePath $BlenderExe -ArgumentList @('--background','--factory-startup','--python-exit-code','1','--python',('"'+"$PSScriptRoot\tools\encode_life_video.py"+'"'),'--',('"'+$axisOutput+'"')) -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput "$axisOutput\encode.log" -RedirectStandardError "$axisOutput\encode_stderr.log"
    if ($axisEncode.ExitCode -ne 0) { throw 'North axis video encoding failed' }
}
if ($EncodeOnly) { Invoke-AxisEncode; return }
$axisArgs=@('--path',"$PSScriptRoot\godot",'res://scenes/diorama.tscn')
if ($Verify) { $axisArgs+=@('--headless','--log-file',"$axisOutput\qa.log",'--','--lookdev','--north-qa') }
elseif ($Motion) { $axisArgs+=@('--log-file',"$axisOutput\motion.log",'--','--lookdev','--ultra','--north-motion') }
else { $axisArgs+=@('--log-file',"$axisOutput\capture.log",'--','--lookdev','--ultra','--capture','--north-capture') }
& $GodotExe @axisArgs
if ($LASTEXITCODE -ne 0) { throw 'North axis capture or verification failed' }
$axisLog=if($Verify){'qa.log'}elseif($Motion){'motion.log'}else{'capture.log'}
if (Select-String -LiteralPath (Join-Path $axisOutput $axisLog) -Pattern '^SCRIPT ERROR:|^ERROR:' -Quiet) { throw "Inspect north_axis/$axisLog" }
if ($Motion) { Invoke-AxisEncode }
