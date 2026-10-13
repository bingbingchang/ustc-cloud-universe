$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\tools\find_apps.ps1"
& $BlenderExe --background --factory-startup --python-exit-code 1 --python "$PSScriptRoot\blender\scripts\build_lake_study.py"
if ($LASTEXITCODE -ne 0) { throw 'Study asset build failed' }
& $GodotExe --headless --path "$PSScriptRoot\godot" --editor --import
if ($LASTEXITCODE -ne 0) { throw 'Godot import failed' }
