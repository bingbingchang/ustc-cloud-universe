param([switch]$SkipFrames)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\tools\find_apps.ps1"
$lifeDir="$PSScriptRoot\renders\life"
New-Item -ItemType Directory -Force -Path $lifeDir | Out-Null
if (-not $SkipFrames) {
    & $GodotExe --path "$PSScriptRoot\godot" res://scenes/diorama.tscn -- --lookdev --motion *> "$lifeDir\motion.log"
    if ($LASTEXITCODE -ne 0 -or !(Select-String -LiteralPath "$lifeDir\motion.log" -Pattern 'MOTION_CAPTURE_OK 600' -Quiet)) { throw 'Motion capture failed: renders/life/motion.log' }
    if (Select-String -LiteralPath "$lifeDir\motion.log" -Pattern '^SCRIPT ERROR:|^ERROR:' -Quiet) { throw 'Godot errors: renders/life/motion.log' }
}
& $BlenderExe --background --factory-startup --python-exit-code 1 --python "$PSScriptRoot\tools\encode_life_video.py" *> "$lifeDir\encode.log"
if ($LASTEXITCODE -ne 0 -or !(Select-String -LiteralPath "$lifeDir\encode.log" -Pattern 'LIFE_VIDEO_ENCODE_OK' -Quiet)) { throw 'Video encode failed: renders/life/encode.log' }
Write-Output "$lifeDir\campus_life_demo.mp4"
