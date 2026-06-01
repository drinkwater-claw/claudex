[CmdletBinding()]
param(
    [string] $BridgeRoot = "C:\ai-bridge",

    [Parameter(Mandatory = $true)]
    [string] $Id,

    [int] $TimeoutSeconds = 600,

    [int] $PollMilliseconds = 250
)

$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "Bridge.Common.psm1") -Force

$root = Initialize-AIBridgeRoot -BridgeRoot $BridgeRoot
$resultPath = Join-Path (Join-Path $root "outbox") (Get-AIBridgeResultFileName -Id $Id)
$deadline = [DateTimeOffset]::UtcNow.AddSeconds($TimeoutSeconds)

while ([DateTimeOffset]::UtcNow -lt $deadline) {
    if (Test-Path $resultPath) {
        $result = Read-AIBridgeJson -Path $resultPath
        ConvertTo-AIBridgeOutput $result
        exit 0
    }

    Start-Sleep -Milliseconds $PollMilliseconds
}

throw "Timed out after $TimeoutSeconds seconds waiting for result: $resultPath"
