$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\tools\find_apps.ps1"
New-Item -ItemType Directory -Path "$PSScriptRoot\renders\gameplay" -Force | Out-Null
& $GodotExe --path "$PSScriptRoot\godot" --resolution 1600x900 --script res://../tools/validate_gameplay.gd --log-file "$PSScriptRoot\renders\gameplay\validation.log"
if ($LASTEXITCODE -ne 0) {throw 'Gameplay checks failed; inspect renders/gameplay/validation.json'}
