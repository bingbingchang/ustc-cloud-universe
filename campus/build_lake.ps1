param([switch]$ImportOnly)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\tools\find_apps.ps1"
if (-not $ImportOnly) {
  & $BlenderExe --background --factory-startup --python-exit-code 1 --python "$PSScriptRoot\blender\scripts\build_lake_garden.py"
  if ($LASTEXITCODE -ne 0) { throw 'Lake asset build failed' }
}
& $GodotExe --headless --editor --path "$PSScriptRoot\godot" --import --quit
if ($LASTEXITCODE -ne 0) { throw 'Godot import failed' }
