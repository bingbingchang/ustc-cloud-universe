param([switch]$Quality,[switch]$Plaza,[switch]$NorthCampus,[switch]$Library,[switch]$Sports,[switch]$SouthSports)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\tools\find_apps.ps1"
$gameLogDir=Join-Path $PSScriptRoot 'renders\gameplay'
New-Item -ItemType Directory -Path $gameLogDir -Force | Out-Null
$gameArgs=@('--path',"$PSScriptRoot\godot",'res://scenes/campus_game.tscn','--log-file',"$gameLogDir\runtime.log",'--','--lookdev','--expand-west')
if ($Quality) {$gameArgs+='--game-quality'}
if ($Plaza) {$gameArgs+='--plaza-focus'}
if ($NorthCampus) {$gameArgs+='--north-campus-focus'}
if ($Library) {$gameArgs+='--library-focus'}
if ($Sports) {$gameArgs+='--sports-focus'}
if ($SouthSports) {$gameArgs+='--south-sports-focus'}
& $GodotExe @gameArgs
if ($LASTEXITCODE -ne 0) {throw 'Campus game failed; inspect renders/gameplay/runtime.log'}
