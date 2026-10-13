param([switch]$ImportOnly)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\tools\find_apps.ps1"
$liveOutput=Join-Path $PSScriptRoot 'renders\lookdev_live'
New-Item -ItemType Directory -Force -Path $liveOutput | Out-Null
if (-not $ImportOnly) {
    $liveBuild=Start-Process -FilePath $BlenderExe -ArgumentList @('--background','--factory-startup','--python-exit-code','1','--python',('"'+"$PSScriptRoot\blender\scripts\build_lookdev_live.py"+'"')) -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput "$liveOutput\build.log" -RedirectStandardError "$liveOutput\build_stderr.log"
    if ($liveBuild.ExitCode -ne 0) { throw 'LookDev extraction failed; inspect build.log' }
}
& $GodotExe --headless --editor --path "$PSScriptRoot\godot" --import --quit --log-file "$liveOutput\import.log"
if ($LASTEXITCODE -ne 0) { throw 'LookDev Live import failed' }
