param([switch]$Diorama,[switch]$Sample,[switch]$Ultra)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\tools\find_apps.ps1"
$sakuraScene=if ($Diorama) {'res://scenes/diorama.tscn'} else {'res://scenes/lookdev_live.tscn'}
$sakuraArgs=@('--path',"$PSScriptRoot\godot",$sakuraScene,'--log-file',"$PSScriptRoot\renders\sakura_avenue\runtime.log",'--','--lookdev','--sakura-focus')
if ($Sample) { $sakuraArgs+='--sakura-sample' }
if ($Ultra) { $sakuraArgs+='--ultra' }
& $GodotExe @sakuraArgs
if ($LASTEXITCODE -ne 0) { throw 'Sakura scene failed; inspect renders/sakura_avenue/runtime.log' }
