[CmdletBinding()]
param(
    [string] $BridgeRoot = "C:\ai-bridge"
)

$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "Bridge.Common.psm1") -Force

$root = Initialize-AIBridgeRoot -BridgeRoot $BridgeRoot
$manifestPath = Join-Path $root "bridge.manifest.json"
$manifest = [ordered]@{
    schema_version = "1.0"
    bridge_version = Get-AIBridgeVersion
    bridge_root = $root
    installed_at = Get-AIBridgeUtcNow
    directories = Get-AIBridgeDirectories
}

Write-AIBridgeJsonAtomic -Path $manifestPath -InputObject $manifest | Out-Null

ConvertTo-AIBridgeOutput ([ordered]@{
    status = "installed"
    bridge_root = $root
    manifest_path = $manifestPath
    directories = Get-AIBridgeDirectories
})
