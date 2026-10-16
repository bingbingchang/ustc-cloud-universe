param([switch]$EncodeOnly)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\tools\find_apps.ps1"
$ustcFilmDir=Join-Path $PSScriptRoot 'renders\ustc1958\video'
New-Item -ItemType Directory -Force -Path $ustcFilmDir | Out-Null
if(-not $EncodeOnly) {
    & $GodotExe --path "$PSScriptRoot\godot" res://samples/ustc1958/showcase.tscn --resolution 1920x1080 --log-file "$ustcFilmDir\capture.log" *> "$ustcFilmDir\capture_console.log"
    if($LASTEXITCODE -ne 0){throw 'USTC1958 film capture failed'}
    if(-not (Select-String -LiteralPath "$ustcFilmDir\capture.log" -Pattern 'USTC1958_FILM_CAPTURE_OK 1800' -Quiet)){throw 'USTC1958 film frames incomplete'}
    if(Select-String -LiteralPath "$ustcFilmDir\capture.log" -Pattern '^SCRIPT ERROR:|^ERROR:' -Quiet){throw 'Inspect USTC1958 film capture.log'}
}
& $BlenderExe --background --factory-startup --python-exit-code 1 --python "$PSScriptRoot\tools\encode_life_video.py" -- "$ustcFilmDir" *> "$ustcFilmDir\encode.log"
if($LASTEXITCODE -ne 0){throw 'USTC1958 film encoding failed'}
$ustcShowcase=Join-Path $PSScriptRoot '..\展示\视频'
New-Item -ItemType Directory -Force -Path $ustcShowcase | Out-Null
Copy-Item -LiteralPath "$ustcFilmDir\campus_life_demo.mp4" -Destination (Join-Path $ustcShowcase '01_USTC1958咖啡厅.mp4') -Force
Write-Output (Join-Path $ustcShowcase '01_USTC1958咖啡厅.mp4')
