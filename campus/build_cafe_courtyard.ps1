param([switch]$ImportOnly)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\tools\find_apps.ps1"
$cafeOutput=Join-Path $PSScriptRoot 'renders\cafe_courtyard'
if (-not $ImportOnly) {
    & $BlenderExe --background --python "$PSScriptRoot\blender\scripts\build_cafe_courtyard.py" *> "$cafeOutput\blender.log"
    if ($LASTEXITCODE -ne 0) {throw 'Cafe Blender build failed; see blender.log'}
}
& $GodotExe --headless --editor --path "$PSScriptRoot\godot" --import --log-file "$cafeOutput\import.log" *> "$cafeOutput\import_console.log"
if ($LASTEXITCODE -ne 0) {throw 'Cafe Godot import failed'}
$cafeImport=Join-Path $PSScriptRoot 'godot\samples\cafe_courtyard\assets\cafe_courtyard.glb.import'
$cafeSettings=Get-Content -LiteralPath $cafeImport -Raw
if ($cafeSettings.Contains('import_script/path=""')) {
    $cafeSettings=$cafeSettings.Replace('import_script/path=""','import_script/path="res://samples/threejs_road/material_import.gd"')
    Set-Content -LiteralPath $cafeImport -Value $cafeSettings -Encoding utf8
    & $GodotExe --headless --editor --path "$PSScriptRoot\godot" --import --log-file "$cafeOutput\import.log" *> "$cafeOutput\import_console.log"
    if ($LASTEXITCODE -ne 0) {throw 'Cafe vertex-color import failed'}
}
