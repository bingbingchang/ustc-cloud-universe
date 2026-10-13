param([switch]$Capture, [switch]$Roundtrip)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\..\tools\find_apps.ps1"
$roadArgs = @('--path', "$PSScriptRoot\godot", 'res://samples/threejs_road/review.tscn', '--resolution', '1200x1000', '--log-file', "$PSScriptRoot\renders\threejs_road\runtime.log", '--')
if ($Capture) { $roadArgs += '--capture-road' }
if ($Roundtrip) { $roadArgs += '--roundtrip-road' }
& $GodotExe @roadArgs
if ($LASTEXITCODE -ne 0) { throw 'Road sample failed; see renders/threejs_road/runtime.log' }
