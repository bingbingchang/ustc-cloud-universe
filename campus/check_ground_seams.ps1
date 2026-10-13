$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\tools\find_apps.ps1"
foreach ($variant in @('live','diorama','optimized','game')) {
    $seamArgs=@('--headless','--path',"$PSScriptRoot\godot",'--script',"$PSScriptRoot\tools\validate_ground_seams.gd")
    if ($variant -eq 'diorama') {$seamArgs+=@('--','--diorama')}
    if ($variant -eq 'optimized') {$seamArgs+=@('--','--optimized','--expand-west')}
    if ($variant -eq 'game') {$seamArgs+=@('--','--game')}
    & $GodotExe @seamArgs
    if ($LASTEXITCODE -ne 0) {throw "Visible ground seam regression: $variant"}
}
