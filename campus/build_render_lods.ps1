$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\tools\find_apps.ps1"
& $GodotExe --headless --path "$PSScriptRoot\godot" --script "$PSScriptRoot\tools\build_render_lods.gd"
if ($LASTEXITCODE -ne 0) {throw 'LOD build failed'}
& $GodotExe --headless --path "$PSScriptRoot\godot" --script "$PSScriptRoot\tools\validate_render_lods.gd"
if ($LASTEXITCODE -ne 0) {throw 'LOD validation failed'}
