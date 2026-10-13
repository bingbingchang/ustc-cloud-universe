$ErrorActionPreference='Stop'
function Find-PublicTool([string]$override,[string[]]$names) {
    if ($override -and (Test-Path -LiteralPath $override)) {return (Resolve-Path -LiteralPath $override).Path}
    foreach ($name in $names) {$command=Get-Command $name -ErrorAction SilentlyContinue;if ($command) {return $command.Source}}
    return $null
}
$GodotExe=Find-PublicTool $env:GODOT_EXE @('godot','Godot_v4.7.1-stable_win64_console.exe','Godot_v4.7.1-stable_win64.exe')
$BlenderExe=Find-PublicTool $env:BLENDER_EXE @('blender')
if (-not $GodotExe) {throw 'Set GODOT_EXE to your Godot executable, or open campus/godot/project.godot in Godot.'}
