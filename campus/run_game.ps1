param(
  [switch]$Quality,[switch]$Plaza,[switch]$NorthCampus,[switch]$Library,[switch]$Sports,[switch]$SouthSports,
  [switch]$NetHost,[switch]$Server,[string]$NetJoin='',[string]$NetName='',[int]$NetPort=45888,[switch]$NetSelftest,
  [switch]$Heroes,[string]$AiUrl=''
)
$ErrorActionPreference='Stop'
$GodotExe=$env:GODOT_EXE
if (-not $GodotExe) {
  $godotCommand=Get-Command godot -ErrorAction SilentlyContinue
  if ($godotCommand) {$GodotExe=$godotCommand.Source}
}
if (-not $GodotExe -or -not (Test-Path -LiteralPath $GodotExe)) {
  throw 'Set GODOT_EXE to the Godot 4.7.1 executable, or open campus/godot/project.godot in the editor.'
}
$gameLogDir=Join-Path $PSScriptRoot 'renders\gameplay'
New-Item -ItemType Directory -Path $gameLogDir -Force | Out-Null

# Two instances must not share one log file, or they clobber each other's output.
$logName='runtime.log'
if ($NetHost -or $Server) {$logName='runtime_host.log'}
elseif ($NetJoin) {$logName='runtime_client.log'}

$gameArgs=@('--path',"$PSScriptRoot\godot",'res://scenes/campus_game.tscn','--log-file',(Join-Path $gameLogDir $logName))

# Dedicated server: no window, no GPU work. Running host + client on ONE machine
# with two Vulkan windows is what triggers VK_ERROR_SURFACE_LOST_KHR, so the
# recommended way to test on a single machine is: server (headless) + one client.
if ($Server) {$gameArgs+='--headless'}

$gameArgs+='--'; $gameArgs+='--lookdev'; $gameArgs+='--expand-west'
if ($Quality) {$gameArgs+='--game-quality'}
if ($Plaza) {$gameArgs+='--plaza-focus'}
if ($NorthCampus) {$gameArgs+='--north-campus-focus'}
if ($Library) {$gameArgs+='--library-focus'}
if ($Sports) {$gameArgs+='--sports-focus'}
if ($SouthSports) {$gameArgs+='--south-sports-focus'}
if ($NetHost -or $Server) {$gameArgs+="--net-host=$NetPort"}
elseif ($NetJoin) {$gameArgs+="--net-join=$NetJoin`:$NetPort"}
# NOTE: only pass --net-name for ASCII names. cmd.exe hands non-ASCII argv to the
# native process through the ANSI code page, so Chinese names arrive as mojibake.
# Leave it empty to use the built-in default (which is a UTF-8 string literal).
if ($NetName) {$gameArgs+="--net-name=$NetName"}
if ($NetSelftest) {$gameArgs+='--net-selftest'}
if ($Heroes) {$gameArgs+='--heroes-focus'}
if ($AiUrl) {$gameArgs+="--ai-url=$AiUrl"}

# Preflight: one running instance costs about 2.7 GB working set / 4.4 GB commit.
# Two graphical instances exceed a 15 GB machine and the second one dies at
# startup (usually reported as VK_ERROR_SURFACE_LOST_KHR, which is misleading -
# the real cause is memory, not the GPU driver).
$graphicalNet = ($NetHost -and -not $Server) -or [bool]$NetJoin
if ($graphicalNet) {
  try {
    $os=Get-CimInstance Win32_OperatingSystem
    $freeGB=[math]::Round($os.FreePhysicalMemory/1MB,2)
    $totalGB=[math]::Round($os.TotalVisibleMemorySize/1MB,1)
    $commitGB=[math]::Round((Get-Counter '\Memory\Committed Bytes').CounterSamples[0].CookedValue/1GB,1)
    $limitGB=[math]::Round((Get-Counter '\Memory\Commit Limit').CounterSamples[0].CookedValue/1GB,1)
    Write-Host ("[net preflight] RAM {0} GB total / {1} GB free | commit {2} / {3} GB" -f $totalGB,$freeGB,$commitGB,$limitGB)
    if ($freeGB -lt 6.0) {
      Write-Warning ("Only {0} GB free RAM. A second graphical instance needs about 2.7 GB and will likely fail." -f $freeGB)
      Write-Warning "Close heavy apps first, or run the host headless via OPEN_NET_SERVER.cmd and open one client."
    }
  } catch {
    Write-Host "[net preflight] memory probe unavailable"
  }
}

& $GodotExe @gameArgs
if ($LASTEXITCODE -ne 0) {throw 'Campus game failed; inspect renders/gameplay log'}
