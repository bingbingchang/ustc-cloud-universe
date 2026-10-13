param([switch]$Diorama,[switch]$Sample,[switch]$Ultra)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\tools\find_apps.ps1"
$lakeScene=if ($Diorama) {'res://scenes/diorama.tscn'} else {'res://scenes/lookdev_live.tscn'}
$lakeArgs=@('--path',"$PSScriptRoot\godot",$lakeScene,'--log-file',"$PSScriptRoot\renders\yijian_garden\runtime.log",'--','--lookdev','--lake-focus')
if ($Sample) { $lakeArgs+='--lake-sample' }
if ($Ultra) { $lakeArgs+='--ultra' }
& $GodotExe @lakeArgs
if ($LASTEXITCODE -ne 0) { throw 'Lake scene failed; inspect renders/yijian_garden/runtime.log' }
