param([switch]$Capture)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\tools\find_apps.ps1"
$ustcArgs=@('--path',"$PSScriptRoot\godot",'res://samples/ustc1958/review.tscn','--resolution','1600x1000','--log-file',"$PSScriptRoot\renders\ustc1958\runtime.log",'--')
if ($Capture) {$ustcArgs+='--capture-ustc1958'}
& $GodotExe @ustcArgs
if ($LASTEXITCODE -ne 0) {throw 'USTC1958 scene failed; see runtime.log'}
