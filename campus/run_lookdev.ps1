param([switch]$Ultra,[switch]$Archive)
$ErrorActionPreference='Stop'
if ($Archive) { & "$PSScriptRoot\run_demo.ps1" -LookDev -Ultra:$Ultra; return }
. "$PSScriptRoot\..\tools\find_apps.ps1"
$liveOutput=Join-Path $PSScriptRoot 'renders\lookdev_live'
New-Item -ItemType Directory -Force -Path $liveOutput | Out-Null
$liveArgs=@('--path',"$PSScriptRoot\godot",'res://scenes/lookdev_live.tscn','--log-file',"$liveOutput\runtime.log",'--','--lookdev')
if ($Ultra) { $liveArgs+='--ultra' }
& $GodotExe @liveArgs
if ($LASTEXITCODE -ne 0) { throw 'LookDev Live launch failed' }
if (Select-String -LiteralPath "$liveOutput\runtime.log" -Pattern '^SCRIPT ERROR:|^ERROR:' -Quiet) { throw 'Inspect renders/lookdev_live/runtime.log' }
