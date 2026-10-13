param([switch]$ImportOnly,[string]$AssetPython)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\tools\find_apps.ps1"
if (-not $AssetPython) {$AssetPython='C:\Users\ysy2c\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'}
$avenueOutput=Join-Path $PSScriptRoot 'renders\plane_avenue'
$avenueSource=Join-Path $PSScriptRoot 'blender\avenue_study'
$avenueAssets=Join-Path $PSScriptRoot 'godot\samples\plane_avenue\assets'
New-Item -ItemType Directory -Force $avenueOutput,$avenueAssets | Out-Null
if (-not $ImportOnly) {
    & $AssetPython "$PSScriptRoot\blender\scripts\build_plane_avenue.py" *> "$avenueOutput\generator.log"
    if ($LASTEXITCODE -ne 0) {throw 'Avenue generation failed; see generator.log'}
    & $BlenderExe --background --python "$PSScriptRoot\blender\scripts\refine_plane_avenue.py" *> "$avenueOutput\blender.log"
    if ($LASTEXITCODE -ne 0) {throw 'Avenue Blender refinement failed; see blender.log'}
}
Copy-Item -LiteralPath "$avenueSource\assets\plane_avenue_collision.glb" -Destination "$avenueAssets\plane_avenue_collision.glb"
Copy-Item -LiteralPath "$avenueSource\preview\presentation_stage.glb" -Destination "$avenueAssets\presentation_stage.glb"
Copy-Item -LiteralPath "$avenueSource\manifest.json" -Destination "$avenueAssets\manifest.json"
& $GodotExe --headless --editor --path "$PSScriptRoot\godot" --import --log-file "$avenueOutput\import.log"
if ($LASTEXITCODE -ne 0) {throw 'Avenue Godot import failed'}
