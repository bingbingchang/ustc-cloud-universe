param([switch]$Stop,[switch]$Watch)
$ErrorActionPreference='Stop'
$statePath=Join-Path $PSScriptRoot 'logs/web_ai_processes.json'
$tunnelConfig=Join-Path $PSScriptRoot 'logs/web_tunnel_config.yml'
$stopSignal=Join-Path $PSScriptRoot 'logs/web_ai.stop'
function Register-Relay($url) {
    & $python (Join-Path $PSScriptRoot 'register_web_relay.py') --url $url
    if($LASTEXITCODE -eq 0){"Web AI is connected: $url"}
    else {Write-Warning "Local AI and tunnel are running; Site registration is pending. Rerun run_web_ai.ps1 after Site publication. Tunnel: $url"}
}
function Own-Process($record) {
    if(-not $record){return $null}
    $process=Get-CimInstance Win32_Process -Filter ("ProcessId="+[int]$record.pid) -ErrorAction SilentlyContinue
    if(-not $process -or $process.CommandLine -notlike ('*'+$record.marker+'*')){return $null}
    if([math]::Abs((([datetime]$process.CreationDate).ToUniversalTime()-([datetime]$record.created).ToUniversalTime()).TotalSeconds) -gt 2){return $null}
    return $process
}
if($Stop) {
    New-Item -ItemType Directory -Path (Join-Path $PSScriptRoot 'logs') -Force | Out-Null
    Set-Content -LiteralPath $stopSignal -Value 'User requested stop' -Encoding ascii
    if(Test-Path -LiteralPath $statePath) {
        $state=Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
        foreach($name in @('tunnel','relay','backend')) {
            $owned=Own-Process $state.$name
            if($owned){Stop-Process -Id $owned.ProcessId -ErrorAction SilentlyContinue}
        }
        'Stopped only the Web AI processes recorded by this launcher.'
    }
    return
}
if($Watch) {
    $mutex=[System.Threading.Mutex]::new($false,'Local\USTCCampusWebAiMonitor')
    $locked=$false
    try {
        try {$locked=$mutex.WaitOne(0)} catch [System.Threading.AbandonedMutexException] {$locked=$true}
        if(-not $locked){'Web AI monitor is already running. Run run_web_ai.ps1 -Stop to stop it.';return}
        if(Test-Path -LiteralPath $stopSignal){Remove-Item -LiteralPath $stopSignal}
        'Web AI monitor running. Keep the campus network connected; run_web_ai.ps1 -Stop stops all owned services.'
        $repair=$true
        while(-not (Test-Path -LiteralPath $stopSignal)) {
            if($repair) {
                try { & $PSCommandPath } catch { Write-Warning 'Web AI startup failed; retrying shortly. Inspect logs for details.' }
            }
            Start-Sleep -Seconds 10
            if(Test-Path -LiteralPath $stopSignal){break}
            $saved=if(Test-Path -LiteralPath $statePath){Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json}else{$null}
            $backend=Get-NetTCPConnection -LocalAddress 127.0.0.1 -LocalPort 8787 -State Listen -ErrorAction SilentlyContinue
            $repair=(-not $saved -or -not $backend -or -not (Own-Process $saved.relay) -or -not (Own-Process $saved.tunnel))
            if($repair){'Web AI connection stopped; recovering local services and refreshing the tunnel.'}
        }
    } finally {if($locked){$mutex.ReleaseMutex()};$mutex.Dispose()}
    return
}
$python=Join-Path $PSScriptRoot '.venv/Scripts/python.exe'
if(-not (Test-Path -LiteralPath $python)){throw 'Create the campus AI virtual environment first.'}
& $python -c "from dotenv import dotenv_values; import sys; v=dotenv_values(sys.argv[1]); sys.exit(0 if len(v.get('CAMPUS_RELAY_TOKEN',''))>=32 and v.get('CAMPUS_WEB_SITE_URL','').startswith('https://') else 1)" (Join-Path $PSScriptRoot '.env')
if($LASTEXITCODE -ne 0){throw 'Configure the Web relay token and Site URL before starting Web AI.'}
$tunnelCommand=(Get-Command cloudflared -ErrorAction Stop).Source
New-Item -ItemType Directory -Path (Join-Path $PSScriptRoot 'logs') -Force | Out-Null
$state=@{backend=$null;relay=$null;tunnel=$null;url=$null}
$existing=$null
function Save-State {$state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $statePath -Encoding utf8}
function Start-LocalService($module,$port,$name) {
    $listener=Get-NetTCPConnection -LocalAddress 127.0.0.1 -LocalPort $port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
    if($listener){
        if($name -eq 'relay' -and (-not $existing -or -not (Own-Process $existing.relay) -or [int]$existing.relay.pid -ne $listener.OwningProcess)){
            throw 'Port 8790 is occupied by an unrecorded process. Leave it running and resolve the conflict before opening a tunnel.'
        }
        $process=Get-CimInstance Win32_Process -Filter ("ProcessId="+$listener.OwningProcess)
        $marker='-m uvicorn '+$module+':app --host 127.0.0.1 --port '+$port
        if($process.CommandLine -notlike ('*'+$marker+'*') -or $process.ExecutablePath -notlike '*python.exe'){
            throw "Port $port is occupied by another service; leave it running and choose the intended Campus service."
        }
        if($existing -and (Own-Process $existing.$name)){$state[$name]=$existing.$name;Save-State}
        return # A borrowed Campus service remains running when Web AI stops.
    }
    $out=Join-Path $PSScriptRoot ('logs/web_'+$name+'.out.log');$err=Join-Path $PSScriptRoot ('logs/web_'+$name+'.err.log')
    $starting=if($existing){Own-Process $existing.$name}else{$null}
    if($starting){$state[$name]=$existing.$name;Save-State}
    else {
        $started=Start-Process -FilePath $python -ArgumentList @('-u','-m','uvicorn',($module+':app'),'--host','127.0.0.1','--port',"$port") -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -RedirectStandardOutput $out -RedirectStandardError $err -PassThru
        $process=Get-CimInstance Win32_Process -Filter ("ProcessId="+$started.Id)
        if(-not $process){throw "$name exited before startup."}
        $state[$name]=@{pid=$process.ProcessId;created=([datetime]$process.CreationDate).ToString('o');marker=('-m uvicorn '+$module+':app --host 127.0.0.1 --port '+$port)};Save-State
    }
    $deadline=(Get-Date).AddSeconds(90)
    while((Get-Date) -lt $deadline) {
        $listener=Get-NetTCPConnection -LocalAddress 127.0.0.1 -LocalPort $port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
        if($listener) {
            $process=Get-CimInstance Win32_Process -Filter ("ProcessId="+$listener.OwningProcess)
            $state[$name]=@{pid=$process.ProcessId;created=([datetime]$process.CreationDate).ToString('o');marker=('-m uvicorn '+$module+':app --host 127.0.0.1 --port '+$port)};Save-State;return
        }
        if(-not (Own-Process $state[$name])){throw "$name exited during startup; inspect its logs."}
        Start-Sleep -Milliseconds 500
    }
    throw "$name did not start; inspect its logs."
}
if(Test-Path -LiteralPath $statePath) {
    $existing=Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    $state.tunnel=$existing.tunnel;$state.url=$existing.url;$state.config_isolated=$existing.config_isolated
}
Start-LocalService 'app' 8787 'backend'
Start-LocalService 'web_relay' 8790 'relay'
if($existing) {
    if((Own-Process $existing.tunnel) -and (Own-Process $existing.relay) -and $existing.url -and $existing.config_isolated) {
        $state.tunnel=$existing.tunnel;$state.url=$existing.url;$state.config_isolated=$true;Save-State
        Register-Relay $existing.url;return
    }
    $oldTunnel=Own-Process $existing.tunnel
    if($oldTunnel){Stop-Process -Id $oldTunnel.ProcessId -ErrorAction SilentlyContinue}
}
$tunnelLog=Join-Path $PSScriptRoot 'logs/web_tunnel.err.log'
# An unrelated global named-tunnel ingress must not override this quick tunnel.
Set-Content -LiteralPath $tunnelConfig -Value 'url: http://127.0.0.1:8790' -Encoding ascii
$tunnel=Start-Process -FilePath $tunnelCommand -ArgumentList @('tunnel','--url','http://127.0.0.1:8790','--config',('"'+$tunnelConfig+'"'),'--no-autoupdate','--protocol','http2') -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $PSScriptRoot 'logs/web_tunnel.out.log') -RedirectStandardError $tunnelLog
$process=Get-CimInstance Win32_Process -Filter ("ProcessId="+$tunnel.Id)
$state.tunnel=@{pid=$tunnel.Id;created=([datetime]$process.CreationDate).ToString('o');marker='tunnel --url http://127.0.0.1:8790'};$state.config_isolated=$true;Save-State
$deadline=(Get-Date).AddSeconds(45)
while((Get-Date) -lt $deadline) {
    if(Test-Path -LiteralPath $tunnelLog) {
        $taskTunnelText=Get-Content -LiteralPath $tunnelLog -Raw
        if(-not [string]::IsNullOrWhiteSpace($taskTunnelText)) {
            $match=[regex]::Match($taskTunnelText,'https://[a-z0-9-]+\.trycloudflare\.com')
            if($match.Success){$state.url=$match.Value;Save-State;break}
        }
    }
    if($tunnel.HasExited){throw 'Tunnel did not start; inspect logs/web_tunnel.err.log.'}
    Start-Sleep -Milliseconds 500
}
if(-not $state.url){throw 'Tunnel address unavailable; inspect the tunnel log.'}
Register-Relay $state.url
