param([switch]$EncodeOnly,[string]$FfmpegExe='')
$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\tools\find_apps.ps1"
$movieRoot=Join-Path $PSScriptRoot 'renders\heroes\animation'
if (-not $EncodeOnly) {
  & $GodotExe --path "$PSScriptRoot\godot" --resolution 1280x720 --fixed-fps 24 --script res://tests/npc_animation_showcase.gd
  if ($LASTEXITCODE -ne 0) {throw 'NPC capture failed'}
}
if (-not $FfmpegExe) {
  $installed=Get-Command ffmpeg.exe -ErrorAction SilentlyContinue
  if ($installed) {$FfmpegExe=$installed.Source}
  else {$FfmpegExe='D:\productivity\godot\nailong\tools\media\ffmpeg\ffmpeg-9.0.1-essentials_build\bin\ffmpeg.exe'}
}
& $FfmpegExe -y -hide_banner -loglevel warning -framerate 24 -i "$movieRoot\motion_frames\frame_%05d.jpg" -c:v libx264 -preset medium -crf 20 -pix_fmt yuv420p -movflags +faststart "$movieRoot\campus_life_demo.mp4"
if ($LASTEXITCODE -ne 0) {throw 'NPC encoding failed'}
$showcaseMovie=Join-Path $PSScriptRoot '..\展示\视频\05_校园15位NPC_动作实机.mp4'
Copy-Item -LiteralPath "$movieRoot\campus_life_demo.mp4" -Destination $showcaseMovie -Force
Write-Host "NPC movie ready: $showcaseMovie"
