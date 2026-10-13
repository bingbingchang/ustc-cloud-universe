param([switch]$Diagnostics)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\tools\find_apps.ps1"
$cases=@('baseline','optimized','baseline_motion','optimized_motion','expanded','expanded_motion')
if ($Diagnostics) {$cases=@('baseline','no_reflection','no_ssil','no_trees','lod_only','reflection_only','optimized','baseline_motion','optimized_motion','expanded','expanded_motion')}
foreach ($case in $cases) {
    $profileArgs=@('--path',"$PSScriptRoot\godot",'--resolution','1600x900','--script',"$PSScriptRoot\tools\profile_campus_performance.gd",'--','--lookdev',"--perf-case=$case")
    if ($case.EndsWith('_motion')) {$profileArgs+='--perf-motion'}
    if ($case.StartsWith('expanded')) {$profileArgs+='--expand-west'}
    & $GodotExe @profileArgs *> "$PSScriptRoot\renders\performance_upgrade\profile_$case.log"
    if ($LASTEXITCODE -ne 0) {throw "Performance sample failed: $case"}
    Write-Output "Completed $case"
}
