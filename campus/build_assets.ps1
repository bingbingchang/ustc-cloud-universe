param([switch]$SkipImport,[string]$TexturePython)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\tools\find_apps.ps1"
if ($TexturePython) {
    & $TexturePython "$PSScriptRoot\tools\lookdev_textures.py"
    if ($LASTEXITCODE -ne 0) { throw 'PBR texture generation failed; Python needs NumPy and Pillow' }
}
& $BlenderExe --background --factory-startup --python "$PSScriptRoot\blender\scripts\build_campus.py" 2>&1 | Tee-Object "$PSScriptRoot\renders\build.log"
if ($LASTEXITCODE -ne 0 -or !(Test-Path "$PSScriptRoot\blender\exports\architecture.glb")) { throw 'Campus Blender build failed' }
if (Select-String -LiteralPath "$PSScriptRoot\renders\build.log" -Pattern 'Traceback|Error: Python' -Quiet) { throw 'Blender Python error' }
& $BlenderExe --background --factory-startup --python "$PSScriptRoot\blender\scripts\build_life.py" 2>&1 | Tee-Object "$PSScriptRoot\renders\life\build_life.log"
if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath "$PSScriptRoot\renders\life\build_life.log" -Pattern 'Traceback|Error: Python' -Quiet)) { throw 'Life asset build failed' }
& $BlenderExe --background --factory-startup --python-exit-code 1 --python "$PSScriptRoot\blender\scripts\build_tiku.py" 2>&1 | Tee-Object "$PSScriptRoot\renders\tiku_boy1\build.log"
if ($LASTEXITCODE -ne 0) { throw 'Tiku character build failed' }
& $BlenderExe --background --factory-startup --python-exit-code 1 --python "$PSScriptRoot\blender\scripts\build_tiku.py" -- --uniform 2>&1 | Tee-Object "$PSScriptRoot\renders\tiku_boy1\build_uniform.log"
if ($LASTEXITCODE -ne 0) { throw 'Tiku uniform build failed' }
if (!$SkipImport) {
    & $GodotExe --headless --path "$PSScriptRoot\godot" --editor --import 2>&1 | Tee-Object "$PSScriptRoot\renders\import.log"
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath "$PSScriptRoot\renders\import.log" -Pattern '^SCRIPT ERROR:|^ERROR:' -Quiet)) { throw 'Godot import failed' }
}
