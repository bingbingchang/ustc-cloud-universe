param(
    [string]$GodotExe=$env:GODOT_EXE,
    [string]$PythonExe='python',
    [Parameter(Mandatory=$true)][string]$TemplatesDir,
    [string]$OutputDir=(Join-Path $PSScriptRoot '../dist/Web')
)
$ErrorActionPreference='Stop'
if (-not $GodotExe) {$GodotExe=(Get-Command godot -ErrorAction Stop).Source}
if (-not (Test-Path -LiteralPath $GodotExe)) {throw 'Godot executable not found.'}
if (-not (Test-Path -LiteralPath (Join-Path $TemplatesDir 'web_nothreads_release.zip'))) {throw 'Matching Godot single-threaded Web export template is required.'}
$project=Join-Path $PSScriptRoot 'godot'
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
$OutputDir=(Resolve-Path -LiteralPath $OutputDir).Path
function Run-Godot($name,$arguments) {
    $log=Join-Path $OutputDir ($name+'.log')
    & $GodotExe '--path' $project '--log-file' $log @arguments
    if ($LASTEXITCODE -ne 0) {throw "Godot $name failed; inspect $log"}
    if (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR|Parse Error|Failed to load script|Error compiling shader' -Quiet) {throw "Godot $name reported a script/shader error; inspect $log"}
}
Run-Godot 'import' @('--headless','--editor','--import')
Run-Godot 'bake' @('--script','res://../tools/bake_web_regions.gd')
& $PythonExe (Join-Path $PSScriptRoot 'tools/prepare_streamed_web.py') --templates $TemplatesDir --output $OutputDir
if ($LASTEXITCODE -ne 0) {throw 'Web preparation failed.'}
$release=(Get-Content -LiteralPath (Join-Path $OutputDir 'current.json') -Raw | ConvertFrom-Json).release
$index=Join-Path $OutputDir ('releases/'+$release+'/index.html')
Run-Godot 'export' @('--headless','--export-release','Web Streamed',$index)
if (-not (Test-Path -LiteralPath $index)) {throw 'Web export did not produce index.html.'}
& $PythonExe (Join-Path $PSScriptRoot 'tools/finalize_streamed_web.py') --output $OutputDir
if ($LASTEXITCODE -ne 0) {throw 'Web checksum/compression failed.'}
Write-Host "Web build ready: $index"
