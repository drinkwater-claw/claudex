[CmdletBinding()]
param(
    [string] $BridgeRoot = "C:\ai-bridge",
    [string] $TaskName = "AI Bridge Claude Daemon",
    [int] $PollSeconds = 10,
    [int] $TaskTimeoutSeconds = 900,
    [int] $WatchdogMinutes = 5,
    [switch] $StartNow
)

$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "Bridge.Common.psm1") -Force
Initialize-AIBridgeRoot -BridgeRoot $BridgeRoot | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $BridgeRoot "locks") | Out-Null

$ensureScript = Join-Path $PSScriptRoot "Ensure-ClaudeBridgeDaemon.ps1"
$arguments = "-WindowStyle Hidden -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$ensureScript`" -BridgeRoot `"$BridgeRoot`" -PollSeconds $PollSeconds -TaskTimeoutSeconds $TaskTimeoutSeconds"

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $arguments
$logonTrigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$watchdogTrigger = New-ScheduledTaskTrigger `
    -Once `
    -At (Get-Date).AddMinutes(1) `
    -RepetitionInterval (New-TimeSpan -Minutes $WatchdogMinutes) `
    -RepetitionDuration (New-TimeSpan -Days 3650)
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger @($logonTrigger, $watchdogTrigger) -Principal $principal -Settings $settings -Force | Out-Null

$startedPid = $null
$ensure = $null
if ($StartNow) {
    $ensure = (& $ensureScript `
        -BridgeRoot $BridgeRoot `
        -PollSeconds $PollSeconds `
        -TaskTimeoutSeconds $TaskTimeoutSeconds | ConvertFrom-Json)
    $startedPid = $ensure.started_pid
}

ConvertTo-AIBridgeOutput ([ordered]@{
    status = "installed"
    task_name = $TaskName
    bridge_root = $BridgeRoot
    poll_seconds = $PollSeconds
    task_timeout_seconds = $TaskTimeoutSeconds
    watchdog_minutes = $WatchdogMinutes
    started_pid = $startedPid
    ensure = $ensure
})
