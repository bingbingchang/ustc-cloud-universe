param([switch]$Capture,[switch]$Ultra,[switch]$Verify,[switch]$CharacterFocus,[switch]$Wave2Focus)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\tools\find_apps.ps1"
$campusArgs=@('--path',"$PSScriptRoot\godot",'res://scenes/diorama.tscn','--log-file',"$PSScriptRoot\renders\diorama\runtime.log",'--','--lookdev')
if ($Verify) { $campusArgs+="--verify" }
if ($Capture) { $campusArgs+='--capture' }
if ($Ultra -or $Capture) { $campusArgs+='--ultra' }
if ($CharacterFocus) { $campusArgs+='--character-focus' }
if ($Wave2Focus) { $campusArgs+='--wave2-focus' }
& $GodotExe @campusArgs
if ($LASTEXITCODE -ne 0) { throw 'Diorama run failed' }

if (Select-String -LiteralPath "$PSScriptRoot\renders\diorama\runtime.log" -Pattern "^SCRIPT ERROR:|^ERROR:" -Quiet) { throw "Inspect diorama/runtime.log" }
