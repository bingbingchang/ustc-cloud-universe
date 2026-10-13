param([switch]$Visual)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\tools\find_apps.ps1"
$sportsCheckArgs=@('--path',"$PSScriptRoot\godot",'--resolution','1600x900','--script','res://../tools/validate_sports_district.gd')
if ($Visual) {$sportsCheckArgs+=@('--','--visual-only')}
& $GodotExe @sportsCheckArgs
if ($LASTEXITCODE -ne 0) {throw 'Sports district validation failed; inspect renders/sports_district.'}
