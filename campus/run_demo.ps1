param([switch]$Verify,[switch]$Capture,[switch]$Headless,[switch]$Editor,[switch]$Bake,[switch]$LookDev,[switch]$Ultra)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\tools\find_apps.ps1"
$campusArgs=@('--path',"$PSScriptRoot\godot",'res://scenes/main.tscn','--log-file',"$PSScriptRoot\renders\runtime.log")
if ($Headless) { $campusArgs+='--headless' }
if ($Editor) { $campusArgs+='--editor' }
$userArgs=@()
if ($Verify) { $userArgs+='--verify' }
elseif ($Capture) { $userArgs+='--capture' }
if ($Bake) { $userArgs+='--bake' }
if ($LookDev) { $userArgs+='--lookdev' }
if ($Ultra) { $userArgs+='--ultra' }
if ($userArgs.Count) { $campusArgs+=@('--')+$userArgs }
& $GodotExe @campusArgs
if ($LASTEXITCODE -ne 0) { throw "Campus demo exited with $LASTEXITCODE" }
if (Select-String -LiteralPath "$PSScriptRoot\renders\runtime.log" -Pattern '^SCRIPT ERROR:|^ERROR:' -Quiet) { throw 'Runtime error: inspect campus/renders/runtime.log' }
