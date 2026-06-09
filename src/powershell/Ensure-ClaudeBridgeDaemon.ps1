[CmdletBinding()]
param(
    [string] $BridgeRoot = "C:\ai-bridge",
    [int] $PollSeconds = 10,
    [int] $TaskTimeoutSeconds = 900,
    [string] $WindowTitle = "Claude",
    [string] $LogPath = "C:\ai-bridge\logs\claude-bridge-watchdog.log"
)

$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "Bridge.Common.psm1") -Force

Initialize-AIBridgeRoot -BridgeRoot $BridgeRoot | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $BridgeRoot "locks") | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $LogPath) | Out-Null

$daemonScript = Join-Path $PSScriptRoot "Start-ClaudeBridgeDaemon.ps1"

function Write-WatchdogLog {
    param([hashtable] $Event)
    $Event.at = [DateTimeOffset]::UtcNow.ToString("o")
    Add-Content -LiteralPath $LogPath -Value ($Event | ConvertTo-Json -Compress -Depth 8)
}

function Get-ClaudeBridgeDaemonProcess {
    $bridgeNeedle = $BridgeRoot.TrimEnd("\")

    Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe' OR Name = 'pwsh.exe'" |
        Where-Object {
            $_.ProcessId -ne $PID -and
            $_.CommandLine -like "*Start-ClaudeBridgeDaemon.ps1*" -and
            $_.CommandLine -like "*$bridgeNeedle*"
        } |
        Select-Object ProcessId, CommandLine
}

$processes = @(Get-ClaudeBridgeDaemonProcess)
$startedPid = $null
$status = "running"

if ($processes.Count -eq 0) {
    $arguments = @(
        "-NoProfile",
        "-ExecutionPolicy Bypass",
        "-File `"$daemonScript`"",
        "-BridgeRoot `"$BridgeRoot`"",
        "-PollSeconds $PollSeconds",
        "-TaskTimeoutSeconds $TaskTimeoutSeconds",
        "-WindowTitle `"$WindowTitle`""
    ) -join " "

    $process = Start-Process -FilePath "powershell.exe" -ArgumentList $arguments -WindowStyle Hidden -PassThru
    $startedPid = $process.Id

    Start-Sleep -Seconds 2
    $processes = @(Get-ClaudeBridgeDaemonProcess)

    if ($processes.Count -eq 0) {
        $status = "failed_to_start"
        Write-WatchdogLog @{ event = "start_failed"; bridge_root = $BridgeRoot; attempted_pid = $startedPid }
    }
    else {
        $status = "started"
        Write-WatchdogLog @{ event = "started_daemon"; bridge_root = $BridgeRoot; pid = $startedPid }
    }
}

ConvertTo-AIBridgeOutput ([ordered]@{
    status = $status
    bridge_root = $BridgeRoot
    daemon_process_count = $processes.Count
    daemon_pids = @($processes | ForEach-Object { $_.ProcessId })
    started_pid = $startedPid
})
