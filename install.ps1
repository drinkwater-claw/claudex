[CmdletBinding()]
param(
    [string] $BridgeRoot = "C:\ai-bridge",
    [switch] $InstallDaemon,
    [switch] $StartDaemon,
    [int] $PollSeconds = 10,
    [int] $TaskTimeoutSeconds = 900,
    [int] $WatchdogMinutes = 5
)

$ErrorActionPreference = "Stop"

$ProjectRoot = $PSScriptRoot
$RuntimeBin = Join-Path $BridgeRoot "bin"

foreach ($dir in @(
    $BridgeRoot,
    (Join-Path $BridgeRoot "bin"),
    (Join-Path $BridgeRoot "docs"),
    (Join-Path $BridgeRoot "schemas"),
    (Join-Path $BridgeRoot "examples")
)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
}

Copy-Item -Force (Join-Path $ProjectRoot "src\powershell\*.ps1") $RuntimeBin
Copy-Item -Force (Join-Path $ProjectRoot "src\powershell\*.psm1") $RuntimeBin
Copy-Item -Force (Join-Path $ProjectRoot "src\powershell\*.vbs") $RuntimeBin
Copy-Item -Force (Join-Path $ProjectRoot "docs\*.md") (Join-Path $BridgeRoot "docs")
Copy-Item -Force (Join-Path $ProjectRoot "schemas\*.json") (Join-Path $BridgeRoot "schemas")
Copy-Item -Force (Join-Path $ProjectRoot "examples\*.json") (Join-Path $BridgeRoot "examples")
Copy-Item -Force (Join-Path $ProjectRoot "README.md") (Join-Path $BridgeRoot "README.md")

& (Join-Path $RuntimeBin "Install-AIBridge.ps1") -BridgeRoot $BridgeRoot | Out-Null

$daemon = $null
if ($InstallDaemon) {
    $daemonParams = @{
        BridgeRoot = $BridgeRoot
        PollSeconds = $PollSeconds
        TaskTimeoutSeconds = $TaskTimeoutSeconds
        WatchdogMinutes = $WatchdogMinutes
    }
    if ($StartDaemon) {
        $daemonParams.StartNow = $true
    }

    $daemon = (& (Join-Path $RuntimeBin "Install-ClaudeBridgeDaemon.ps1") @daemonParams | ConvertFrom-Json)
}

[ordered]@{
    status = "installed"
    bridge_root = $BridgeRoot
    runtime_bin = $RuntimeBin
    daemon = $daemon
} | ConvertTo-Json -Depth 8
