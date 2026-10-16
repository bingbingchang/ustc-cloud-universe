param([switch]$EncodeOnly,[switch]$Preview)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\tools\find_apps.ps1"
$fullFilmDirectory=Join-Path $PSScriptRoot 'renders\full_campus\video'
New-Item -ItemType Directory -Force -Path $fullFilmDirectory | Out-Null
if(-not $EncodeOnly){
    $fullFilmArgs=@('--path',"$PSScriptRoot\godot",'res://scenes/full_campus_showcase.tscn','--resolution','1280x720','--fixed-fps','30','--log-file',"$fullFilmDirectory\capture.log")
    if($Preview){$fullFilmArgs+=@('--','--film-preview')}
    & $GodotExe @fullFilmArgs *> "$fullFilmDirectory\capture_console.log"
    if($LASTEXITCODE -ne 0){throw 'Full East Campus film capture failed; inspect capture.log'}
    if(-not (Select-String -LiteralPath "$fullFilmDirectory\capture.log" -Pattern 'FULL_CAMPUS_FILM_CAPTURE_OK 1290' -Quiet)){throw 'Full East Campus film incomplete'}
    if(Select-String -LiteralPath "$fullFilmDirectory\capture.log" -Pattern '^SCRIPT ERROR:|^ERROR:' -Quiet){throw 'Full East Campus film has engine errors'}
    if($Preview){return}
}
& $BlenderExe --background --factory-startup --python-exit-code 1 --python "$PSScriptRoot\tools\encode_life_video.py" -- "$fullFilmDirectory" *> "$fullFilmDirectory\encode.log"
if($LASTEXITCODE -ne 0){throw 'Full East Campus film encoding failed'}
$fullShowcase=Join-Path $PSScriptRoot '..\展示\视频'
New-Item -ItemType Directory -Force -Path $fullShowcase | Out-Null
Copy-Item -LiteralPath "$fullFilmDirectory\campus_life_demo.mp4" -Destination (Join-Path $fullShowcase '04_完整东区校园漫游_当前版.mp4') -Force
Copy-Item -LiteralPath "$fullFilmDirectory\poster.png" -Destination (Join-Path $PSScriptRoot '..\展示\封面\04_完整东区.png') -Force
Write-Output (Join-Path $fullShowcase '04_完整东区校园漫游_当前版.mp4')
