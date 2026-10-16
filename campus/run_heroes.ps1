param([string]$AiUrl='http://127.0.0.1:8787')
$ErrorActionPreference='Stop'
& "$PSScriptRoot\run_game.ps1" -Heroes -AiUrl $AiUrl
