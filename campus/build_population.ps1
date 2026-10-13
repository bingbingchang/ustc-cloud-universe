param([switch]$ImportOnly)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\tools\find_apps.ps1"
$populationOutput=Join-Path $PSScriptRoot 'renders\population'
New-Item -ItemType Directory -Force -Path $populationOutput | Out-Null
if (-not $ImportOnly) {
    $populationBuild=Start-Process -FilePath $BlenderExe -ArgumentList @('--background','--factory-startup','--python-exit-code','1','--python',('"'+"$PSScriptRoot\blender\scripts\build_population.py"+'"')) -WindowStyle Hidden -PassThru -Wait -RedirectStandardOutput "$populationOutput\build.log" -RedirectStandardError "$populationOutput\build_stderr.log"
    if ($populationBuild.ExitCode -ne 0) { throw 'Ambient asset build failed: renders/population/build.log' }
}
& $GodotExe --headless --editor --path "$PSScriptRoot\godot" --import --log-file "$populationOutput\import.log"
if ($LASTEXITCODE -ne 0) { throw 'Godot import failed' }
if (Select-String -LiteralPath "$populationOutput\import.log" -Pattern '^SCRIPT ERROR:|^ERROR:' -Quiet) { throw 'Godot import reported errors' }
