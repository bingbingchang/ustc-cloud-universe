param([switch]$Verify,[switch]$Motion,[switch]$CompareDiorama,[switch]$EncodeOnly)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\tools\find_apps.ps1"
$liveOutput=Join-Path $PSScriptRoot 'renders\lookdev_live'
New-Item -ItemType Directory -Force -Path $liveOutput | Out-Null
function Invoke-LiveEncode {
    $liveEncode=Start-Process -FilePath $BlenderExe -ArgumentList @('--background','--factory-startup','--python-exit-code','1','--python',('"'+"$PSScriptRoot\tools\encode_life_video.py"+'"'),'--',('"'+$liveOutput+'"')) -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput "$liveOutput\encode.log" -RedirectStandardError "$liveOutput\encode_stderr.log"
    if ($liveEncode.ExitCode -ne 0) { throw 'LookDev movie encoding failed' }
}
if ($EncodeOnly) { Invoke-LiveEncode; return }
$liveArgs=@('--path',"$PSScriptRoot\godot")
$liveLog=if ($Verify) {'qa.log'} elseif($Motion) {'motion.log'} elseif($CompareDiorama) {'compare.log'} else {'capture.log'}
if ($Verify) { $liveArgs+=@('--headless','--script','res://../tools/validate_lookdev_live.gd') }
else { $liveArgs+=@('--script','res://../tools/capture_lookdev_live.gd') }
$liveArgs+=@('--log-file',"$liveOutput\$liveLog",'--','--lookdev')
if (-not $Verify) { $liveArgs+='--ultra' }
if ($Motion) { $liveArgs+='--live-motion' }
if ($CompareDiorama) { $liveArgs+='--compare-diorama' }
& $GodotExe @liveArgs
if ($LASTEXITCODE -ne 0) { throw 'LookDev capture/QA failed' }
if (Select-String -LiteralPath "$liveOutput\$liveLog" -Pattern '^SCRIPT ERROR:|^ERROR:' -Quiet) { throw "Inspect lookdev_live/$liveLog" }
if ($Motion) { Invoke-LiveEncode }
