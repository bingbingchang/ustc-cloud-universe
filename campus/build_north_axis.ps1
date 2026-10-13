param([switch]$ImportOnly)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\tools\find_apps.ps1"
$axisOutput=Join-Path $PSScriptRoot 'renders\north_axis'
New-Item -ItemType Directory -Force -Path $axisOutput | Out-Null
if (-not $ImportOnly) {
    $axisBuild=Start-Process -FilePath $BlenderExe -ArgumentList @('--background','--factory-startup','--python-exit-code','1','--python',('"'+"$PSScriptRoot\blender\scripts\build_north_axis.py"+'"')) -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput "$axisOutput\build.log" -RedirectStandardError "$axisOutput\build_stderr.log"
    if ($axisBuild.ExitCode -ne 0) { throw 'North axis asset build failed; inspect renders/north_axis/build.log' }
    $axisProps=Start-Process -FilePath $BlenderExe -ArgumentList @('--background','--factory-startup','--python-exit-code','1','--python',('"'+"$PSScriptRoot\blender\scripts\build_north_lake_props.py"+'"')) -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput "$axisOutput\props_build.log" -RedirectStandardError "$axisOutput\props_build_stderr.log"
    if ($axisProps.ExitCode -ne 0) { throw 'Lake detail asset build failed' }
}
& $GodotExe --headless --editor --path "$PSScriptRoot\godot" --import --quit --log-file "$axisOutput\import.log"
if ($LASTEXITCODE -ne 0) { throw 'North axis Godot import failed' }
