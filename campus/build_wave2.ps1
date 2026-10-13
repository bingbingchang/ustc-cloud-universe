param([switch]$ImportOnly)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\tools\find_apps.ps1"
$waveOutput=Join-Path $PSScriptRoot 'renders\wave2'
New-Item -ItemType Directory -Force -Path $waveOutput | Out-Null
if (-not $ImportOnly) {
    foreach ($waveScript in @('build_cameos.py','build_mascots.py')) {
        $waveTag=[IO.Path]::GetFileNameWithoutExtension($waveScript)
        $waveBuild=Start-Process -FilePath $BlenderExe -ArgumentList @('--background','--factory-startup','--python-exit-code','1','--python',('"'+"$PSScriptRoot\blender\scripts\$waveScript"+'"')) -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput "$waveOutput\$waveTag.log" -RedirectStandardError "$waveOutput\${waveTag}_stderr.log"
        if ($waveBuild.ExitCode -ne 0) { throw "Build failed: $waveScript" }
    }
}
& $GodotExe --headless --path "$PSScriptRoot\godot" --editor --import --quit --log-file "$waveOutput\import.log"
if ($LASTEXITCODE -ne 0) { throw 'Wave2 import failed' }
