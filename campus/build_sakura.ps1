param([switch]$ImportOnly)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\tools\find_apps.ps1"
$sakuraOutput=Join-Path $PSScriptRoot 'renders\sakura_avenue'
New-Item -ItemType Directory -Force -Path $sakuraOutput | Out-Null
if (-not $ImportOnly) {
    & $BlenderExe --background --factory-startup --python-exit-code 1 --python "$PSScriptRoot\blender\scripts\build_sakura.py" *> "$sakuraOutput\build.log"
    if ($LASTEXITCODE -ne 0) { throw 'Sakura kit build failed; inspect build.log' }
}
& $GodotExe --headless --editor --path "$PSScriptRoot\godot" --import --quit --log-file "$sakuraOutput\import.log"
if ($LASTEXITCODE -ne 0) { throw 'Sakura import failed' }
