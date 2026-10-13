param([switch]$Visual,[switch]$Repair)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\tools\find_apps.ps1"
$fullCheckArgs=@('--path',"$PSScriptRoot\godot",'--resolution','1600x900','--script','res://../tools/validate_full_districts.gd')
if ($Visual) {$fullCheckArgs+=@('--','--visual-only')}
if ($Repair) {$fullCheckArgs+=@('--','--repair')}
& $GodotExe @fullCheckArgs
if ($LASTEXITCODE -ne 0) {throw 'Full campus validation failed; inspect renders/full_campus.'}
