param([switch]$Verify,[switch]$Capture,[switch]$Motion,[switch]$NewMotion,[switch]$Performance)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\tools\find_apps.ps1"
$animalOutput=Join-Path $PSScriptRoot 'renders\wildlife'
New-Item -ItemType Directory -Force -Path $animalOutput | Out-Null
$animalArgs=@('--path',"$PSScriptRoot\godot",'res://wildlife/animal_lab.tscn','--log-file',"$animalOutput\run.log")
if ($Verify) { $animalArgs+=@('--headless','--','--wildlife-qa') }
elseif ($NewMotion) { $animalArgs+=@('--','--wildlife-new-motion') }
elseif ($Motion) { $animalArgs+=@('--','--wildlife-motion') }
elseif ($Performance) { $animalArgs+=@('--','--wildlife-performance') }
elseif ($Capture) { $animalArgs+=@('--','--wildlife-capture') }
& $GodotExe @animalArgs
if ($LASTEXITCODE -ne 0) { throw 'Wildlife run failed; inspect renders/wildlife/run.log' }
if (Select-String -LiteralPath "$animalOutput\run.log" -Pattern '^SCRIPT ERROR:|^ERROR:' -Quiet) { throw 'Wildlife runtime reported errors' }
if ($Motion -or $NewMotion) {
    $animalEncodeArgs=@('--background','--factory-startup','--python-exit-code','1','--python',('"'+"$PSScriptRoot\blender\wildlife\encode_video.py"+'"'))
    if ($NewMotion) { $animalEncodeArgs+=@('--','--new-batch') }
    $animalEncode=Start-Process -FilePath $BlenderExe -ArgumentList $animalEncodeArgs -WindowStyle Hidden -PassThru -Wait -RedirectStandardOutput "$animalOutput\encode.log" -RedirectStandardError "$animalOutput\encode_stderr.log"
    if ($animalEncode.ExitCode -ne 0) { throw 'Wildlife video encoding failed' }
}
