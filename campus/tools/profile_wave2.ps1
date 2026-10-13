param()
$ErrorActionPreference = 'Stop'
$campusRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot '..\..\tools\find_apps.ps1')
$profileLog = Join-Path $campusRoot 'renders\wave2\performance_runtime.log'
$profileReport = Join-Path $campusRoot 'renders\wave2\performance.json'
$profileArgs = @('--path', (Join-Path $campusRoot 'godot'), '--log-file', $profileLog, '--', '--lookdev', '--wave2-profile')
& $GodotExe @profileArgs
if ($LASTEXITCODE -ne 0) { throw "Wave 2 profile exited with $LASTEXITCODE; see $profileLog" }
if (Select-String -LiteralPath $profileLog -Pattern '^SCRIPT ERROR:|^ERROR:' -Quiet) { throw "Runtime error; see $profileLog" }
$profileData = Get-Content -LiteralPath $profileReport -Raw | ConvertFrom-Json
if (-not $profileData.completed -or -not $profileData.resolution_verified) { throw 'Wave 2 measurements did not complete at the requested resolution.' }
$profileData.views | Select-Object id, effective_fps, median_frame_ms, p95_frame_ms, @{Name='median_draw_calls'; Expression={$_.draw_calls.median}}, focus_fraction | Format-Table -AutoSize
Write-Output "Report: $profileReport"
