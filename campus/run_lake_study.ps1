param([switch]$Before)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\tools\find_apps.ps1"
$studyArgs=@('--path',"$PSScriptRoot\godot",'res://scenes/lake_study.tscn','--log-file',"$PSScriptRoot\renders\lake_study\runtime.log",'--','--lookdev')
if ($Before) { $studyArgs+='--study-before' }
& $GodotExe @studyArgs
if ($LASTEXITCODE -ne 0) { throw 'Study failed; inspect renders/lake_study/runtime.log' }
