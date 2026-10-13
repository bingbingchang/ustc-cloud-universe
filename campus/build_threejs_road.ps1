param([switch]$ImportOnly)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\..\tools\find_apps.ps1"
$roadOriginal = Join-Path $PSScriptRoot 'references\threejs_road\original\campus_plane_tree_sample'
$roadSample = Join-Path $PSScriptRoot 'godot\samples\threejs_road'
New-Item -ItemType Directory -Force "$roadSample\assets","$PSScriptRoot\renders\threejs_road" | Out-Null
Copy-Item -LiteralPath "$roadOriginal\assets\campus_avenue_master.glb" -Destination "$roadSample\assets\campus_avenue_master.glb"
Copy-Item -LiteralPath "$roadOriginal\assets\campus_avenue_collision.glb" -Destination "$roadSample\assets\campus_avenue_collision.glb"
Copy-Item -LiteralPath "$roadOriginal\preview\presentation_stage.glb" -Destination "$roadSample\assets\presentation_stage.glb"
if (-not $ImportOnly) {
    & $BlenderExe --background --python "$PSScriptRoot\blender\scripts\import_threejs_road.py" *> "$PSScriptRoot\renders\threejs_road\blender.log"
    if ($LASTEXITCODE -ne 0) { throw 'Blender road import failed; see renders/threejs_road/blender.log' }
}
& $GodotExe --headless --editor --path "$PSScriptRoot\godot" --import --log-file "$PSScriptRoot\renders\threejs_road\import.log"
if ($LASTEXITCODE -ne 0) { throw 'Godot import failed' }
