param(
    [ValidateSet('all','cat','duck','sparrow','open')][string]$Species='all',
    [switch]$ImportOnly,
    [string]$TexturePython=(Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe')
)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\tools\find_apps.ps1"
$animalOutput=Join-Path $PSScriptRoot 'renders\wildlife'
New-Item -ItemType Directory -Force -Path $animalOutput | Out-Null
if (-not $ImportOnly) {
    & $TexturePython "$PSScriptRoot\blender\wildlife\make_textures.py"
    if ($LASTEXITCODE -ne 0) { throw 'Animal texture generation failed' }
    if ($Species -ne 'open') {
        $animalTargets=if ($Species -eq 'all') { @('cat','duck','sparrow') } else { @($Species) }
        $animalArgs=@('--background','--factory-startup','--python-exit-code','1','--python',('"'+"$PSScriptRoot\blender\wildlife\build_animals.py"+'"'),'--')+$animalTargets
        $animalBuild=Start-Process -FilePath $BlenderExe -ArgumentList $animalArgs -WindowStyle Hidden -PassThru -Wait -RedirectStandardOutput "$animalOutput\build.log" -RedirectStandardError "$animalOutput\build_stderr.log"
        if ($animalBuild.ExitCode -ne 0) { throw 'Animal build failed; see renders/wildlife/build.log' }
    }
    if ($Species -in @('all','open')) {
        & $TexturePython "$PSScriptRoot\blender\wildlife\paint_hedgehog_coat.py"
        if ($LASTEXITCODE -ne 0) { throw 'Hedgehog coat generation failed' }
        $animalBuild=Start-Process -FilePath $BlenderExe -ArgumentList @('--background','--factory-startup','--python-exit-code','1','--python',('"'+"$PSScriptRoot\blender\wildlife\prepare_open_animals.py"+'"')) -WindowStyle Hidden -PassThru -Wait -RedirectStandardOutput "$animalOutput\open_build.log" -RedirectStandardError "$animalOutput\open_build_stderr.log"
        if ($animalBuild.ExitCode -ne 0) { throw 'Open asset preparation failed; see renders/wildlife/open_build.log' }
    }
}
& $GodotExe --headless --editor --path "$PSScriptRoot\godot" --import --log-file "$animalOutput\import.log"
if ($LASTEXITCODE -ne 0) { throw 'Animal import failed' }
if (Select-String -LiteralPath "$animalOutput\import.log" -Pattern '^SCRIPT ERROR:|^ERROR:' -Quiet) { throw 'Godot import reported errors' }
