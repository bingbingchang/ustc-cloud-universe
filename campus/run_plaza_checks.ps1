param([switch]$Baseline)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\tools\find_apps.ps1"
if ($Baseline) {
    & $GodotExe --path "$PSScriptRoot\godot" --resolution 1600x900 --script res://../tools/validate_plaza.gd --log-file "$PSScriptRoot\renders\plaza_expansion\before.log" -- --plaza-before --profile-only
    if ($LASTEXITCODE -ne 0) {throw 'Pre-expansion profiling failed'}
}
& $GodotExe --path "$PSScriptRoot\godot" --resolution 1600x900 --script res://../tools/validate_plaza.gd --log-file "$PSScriptRoot\renders\plaza_expansion\validation.log"
if ($LASTEXITCODE -ne 0) {throw 'Plaza checks failed; inspect renders/plaza_expansion/validation.json'}
