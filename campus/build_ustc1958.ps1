param([switch]$ImportOnly)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\tools\find_apps.ps1"
$ustcOutput=Join-Path $PSScriptRoot 'renders\ustc1958'
New-Item -ItemType Directory -Force -Path $ustcOutput | Out-Null
if (-not $ImportOnly) {
    & $BlenderExe --background --python "$PSScriptRoot\blender\scripts\build_ustc1958.py" *> "$ustcOutput\blender.log"
    if ($LASTEXITCODE -ne 0) {throw 'USTC1958 Blender build failed; see blender.log'}
}
& $GodotExe --headless --editor --path "$PSScriptRoot\godot" --import --log-file "$ustcOutput\import.log" *> "$ustcOutput\import_console.log"
if ($LASTEXITCODE -ne 0) {throw 'USTC1958 Godot import failed'}
$ustcChanged=$false
foreach ($ustcAsset in @('ustc1958_building_site','ustc1958_shared_library')) {
    $ustcImport=Join-Path $PSScriptRoot "godot\samples\ustc1958\assets\$ustcAsset.glb.import"
    $ustcSettings=Get-Content -LiteralPath $ustcImport -Raw
    if ($ustcSettings.Contains('import_script/path=""')) {
        $ustcSettings=$ustcSettings.Replace('import_script/path=""','import_script/path="res://samples/threejs_road/material_import.gd"')
        Set-Content -LiteralPath $ustcImport -Value $ustcSettings -Encoding utf8
        $ustcChanged=$true
    }
}
if ($ustcChanged) {
    & $GodotExe --headless --editor --path "$PSScriptRoot\godot" --import --log-file "$ustcOutput\import.log" *> "$ustcOutput\import_console.log"
    if ($LASTEXITCODE -ne 0) {throw 'USTC1958 vertex-color import failed'}
}
