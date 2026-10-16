param([switch]$Capture)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\tools\find_apps.ps1"
$cafeArgs=@('--path',"$PSScriptRoot\godot",'res://samples/cafe_courtyard/review.tscn','--resolution','1600x1000','--log-file',"$PSScriptRoot\renders\cafe_courtyard\runtime.log",'--')
if ($Capture) {$cafeArgs+='--capture-cafe'}
& $GodotExe @cafeArgs
if ($LASTEXITCODE -ne 0) {throw 'Cafe scene failed; see runtime.log'}
