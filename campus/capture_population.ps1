param([switch]$Verify,[switch]$Motion,[switch]$EncodeOnly)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\tools\find_apps.ps1"
$populationOutput=Join-Path $PSScriptRoot 'renders\population'
New-Item -ItemType Directory -Force -Path $populationOutput | Out-Null
function Invoke-PopulationEncode {
    # Windows PowerShell 5 treats redirected native stderr warnings as terminating
    # errors under ErrorActionPreference=Stop. Inspect the actual process exit code.
    $populationEncoder=Start-Process -FilePath $BlenderExe -ArgumentList @('--background','--factory-startup','--python-exit-code','1','--python',('"'+"$PSScriptRoot\tools\encode_life_video.py"+'"'),'--',('"'+$populationOutput+'"')) -WindowStyle Hidden -PassThru -Wait -RedirectStandardOutput "$populationOutput\encode.log" -RedirectStandardError "$populationOutput\encode_stderr.log"
    if ($populationEncoder.ExitCode -ne 0) { throw 'Motion encoding failed; inspect encode logs' }
}
if ($EncodeOnly) { Invoke-PopulationEncode; return }
$populationArgs=@('--path',"$PSScriptRoot\godot",'res://scenes/diorama.tscn')
if ($Verify) { $populationArgs+=@('--headless','--log-file',"$populationOutput\qa.log",'--','--lookdev','--population-qa') }
elseif ($Motion) { $populationArgs+=@('--log-file',"$populationOutput\motion.log",'--','--lookdev','--ultra','--population-motion') }
else { $populationArgs+=@('--log-file',"$populationOutput\capture.log",'--','--lookdev','--ultra','--capture','--population-capture') }
& $GodotExe @populationArgs
if ($LASTEXITCODE -ne 0) { throw 'Population capture/validation failed; inspect renders/population logs' }
if ($Motion) {
    Invoke-PopulationEncode
}
