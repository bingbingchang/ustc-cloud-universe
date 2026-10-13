param([switch]$SkipFrames)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\tools\find_apps.ps1"
$out="$PSScriptRoot\renders\tiku_identity"
New-Item -ItemType Directory -Force $out | Out-Null
if (!$SkipFrames) {
    & $GodotExe --path "$PSScriptRoot\godot" res://scenes/tiku_proof.tscn -- --lookdev --ultra --tiku-motion *> "$out\capture.log"
    if ($LASTEXITCODE -ne 0 -or !(Select-String -LiteralPath "$out\capture.log" -Pattern 'TIKU_MOTION_OK 640' -Quiet)) { throw 'Character capture failed' }
    if (!(Select-String -LiteralPath "$out\capture.log" -Pattern 'TIKU_ROADSIDE_MOTION_OK 640' -Quiet)) { throw 'Roadside character capture failed' }
    if (Select-String -LiteralPath "$out\capture.log" -Pattern '^SCRIPT ERROR:|^ERROR:' -Quiet) { throw 'Character script error' }
}
& $BlenderExe --background --factory-startup --python-exit-code 1 --python "$PSScriptRoot\tools\encode_life_video.py" -- $out *> "$out\encode.log"
if ($LASTEXITCODE -ne 0) { throw 'Character video failed' }
Write-Output "$out\campus_life_demo.mp4"
& $BlenderExe --background --factory-startup --python-exit-code 1 --python "$PSScriptRoot\tools\encode_life_video.py" -- "$out\roadside" *> "$out\roadside\encode.log"
if ($LASTEXITCODE -ne 0) { throw 'Roadside character video failed' }
Write-Output "$out\roadside\campus_life_demo.mp4"
