[CmdletBinding()]
param(
    [string] $BridgeRoot = "C:\ai-bridge",
    [string] $TaskName = "AI Bridge Claude Daemon",
    [int] $PollSeconds = 10,
    [int] $TaskTimeoutSeconds = 900,
    [switch] $StartNow
)

$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "Bridge.Common.psm1") -Force
Initialize-AIBridgeRoot -BridgeRoot $BridgeRoot | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $BridgeRoot "locks") | Out-Null

$daemonScript = Join-Path $PSScriptRoot "Start-ClaudeBridgeDaemon.ps1"
$arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$daemonScript`" -BridgeRoot `"$BridgeRoot`" -PollSeconds $PollSeconds -TaskTimeoutSeconds $TaskTimeoutSeconds"

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $arguments
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null

$startedPid = $null
if ($StartNow) {
    $process = Start-Process -WindowStyle Hidden -PassThru -FilePath powershell -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", $daemonScript,
        "-BridgeRoot", $BridgeRoot,
        "-PollSeconds", $PollSeconds,
        "-TaskTimeoutSeconds", $TaskTimeoutSeconds
    )
    $startedPid = $process.Id
}

ConvertTo-AIBridgeOutput ([ordered]@{
    status = "installed"
    task_name = $TaskName
    bridge_root = $BridgeRoot
    poll_seconds = $PollSeconds
    task_timeout_seconds = $TaskTimeoutSeconds
    started_pid = $startedPid
})
