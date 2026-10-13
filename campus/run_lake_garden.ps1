param([switch]$Before,[switch]$Unoptimized,[switch]$BasinFocus,[switch]$GroveFocus)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\tools\find_apps.ps1"
$gardenScene=if ($Before) {'res://scenes/lake_garden_expanded.tscn'} else {'res://scenes/campus_performance.tscn'}
$gardenArgs=@('--path',"$PSScriptRoot\godot",$gardenScene,'--log-file',"$PSScriptRoot\renders\lake_garden_expanded\runtime.log",'--','--lookdev')
if ($Before) {$gardenArgs+='--garden-before'}
else {$gardenArgs+='--expand-west'}
if ($Unoptimized -and -not $Before) {$gardenArgs+='--perf-case=baseline'}
if ($BasinFocus) {$gardenArgs+='--basin-focus'}
if ($GroveFocus) {$gardenArgs+='--grove-focus'}
& $GodotExe @gardenArgs
if ($LASTEXITCODE -ne 0) {throw 'Expanded garden failed; inspect runtime.log'}
