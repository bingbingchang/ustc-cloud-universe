param(
    [string]$PythonExe='',
    [int]$Port=8787,
    [switch]$Check,
    [switch]$Online
)
$ErrorActionPreference='Stop'
if (-not $PythonExe) {
    $PythonExe=Join-Path $PSScriptRoot '.venv\Scripts\python.exe'
    if (-not (Test-Path -LiteralPath $PythonExe)) {$PythonExe='python'}
}
& $PythonExe -c 'import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)'
if ($LASTEXITCODE -ne 0) {throw 'Python 3.10+ required (3.12 recommended). Pass -PythonExe or create campus/ai/.venv.'}
Push-Location $PSScriptRoot
try {
    if ($Check -or $Online) {
        $checkArgs=@('check_api.py')
        if ($Online) {$checkArgs+='--online'}
        & $PythonExe @checkArgs
    } else {
        & $PythonExe -m uvicorn app:app --host 127.0.0.1 --port $Port
    }
    if ($LASTEXITCODE -ne 0) {throw 'Campus AI failed; inspect the output above.'}
} finally {Pop-Location}
