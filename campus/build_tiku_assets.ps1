param([switch]$Proof)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\tools\find_apps.ps1"
$out="$PSScriptRoot\renders\tiku_identity"
New-Item -ItemType Directory -Force $out | Out-Null
foreach ($variant in @('bench','uniform')) {
    $arguments=@('--background','--factory-startup','--python-exit-code','1','--python',"$PSScriptRoot\blender\scripts\build_tiku.py")
    if ($variant -eq 'uniform') { $arguments+=@('--','--uniform') }
    & $BlenderExe @arguments *> "$out\build_$variant.log"
    if ($LASTEXITCODE -ne 0) { throw "Character build failed: $variant" }
}
& $GodotExe --headless --path "$PSScriptRoot\godot" --editor --import *> "$out\import.log"
if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath "$out\import.log" -Pattern '^SCRIPT ERROR:|^ERROR:' -Quiet)) { throw 'Character import failed' }
if ($Proof) {
    foreach ($variant in @('bench','uniform')) {
        $arguments=@('--background','--factory-startup','--python-exit-code','1','--python',"$PSScriptRoot\blender\scripts\render_tiku_proof.py")
        if ($variant -eq 'uniform') { $arguments+=@('--','--uniform') }
        & $BlenderExe @arguments *> "$out\blender_$variant.log"
        if ($LASTEXITCODE -ne 0) { throw "Blender proof failed: $variant" }
    }
}
Write-Output 'Both Tiku identities built and imported.'
