param([switch]$Capture,[switch]$Validate)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\tools\find_apps.ps1"
$avenueArgs=@('--path',"$PSScriptRoot\godot",'res://samples/plane_avenue/review.tscn','--resolution','1600x1000','--log-file',"$PSScriptRoot\renders\plane_avenue\runtime.log",'--')
if ($Capture -or $Validate) {$avenueArgs+='--capture-avenue'}
if ($Validate) {$avenueArgs+='--validate-avenue'}
& $GodotExe @avenueArgs
if ($LASTEXITCODE -ne 0) {throw 'Avenue scene failed; see runtime.log'}
