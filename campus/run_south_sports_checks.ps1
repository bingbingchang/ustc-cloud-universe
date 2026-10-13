param([switch]$Visual,[switch]$RepairRoutes)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\tools\find_apps.ps1"
$southCheckArgs=@('--path',"$PSScriptRoot\godot",'--resolution','1600x900','--script','res://../tools/validate_south_sports.gd')
if ($Visual) {$southCheckArgs+=@('--','--visual-only')}
if ($RepairRoutes) {$southCheckArgs+=@('--','--repair-routes')}
& $GodotExe @southCheckArgs
if ($LASTEXITCODE -ne 0) {throw 'South sports validation failed; inspect renders/south_sports.'}
