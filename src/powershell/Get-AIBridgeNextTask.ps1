[CmdletBinding()]
param(
    [string] $BridgeRoot = "C:\ai-bridge"
)

$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "Bridge.Common.psm1") -Force

$root = Initialize-AIBridgeRoot -BridgeRoot $BridgeRoot
$inbox = Join-Path $root "inbox"
$working = Join-Path $root "working"
$tasks = Get-ChildItem -LiteralPath $inbox -Filter "*.task.json" -File |
    Sort-Object LastWriteTimeUtc, Name

foreach ($file in $tasks) {
    $claimedPath = Join-Path $working $file.Name

    try {
        Move-Item -LiteralPath $file.FullName -Destination $claimedPath -ErrorAction Stop
    }
    catch {
        continue
    }

    $task = Read-AIBridgeJson -Path $claimedPath
    $task | Add-Member -NotePropertyName status -NotePropertyValue "working" -Force
    $task | Add-Member -NotePropertyName claimed_at -NotePropertyValue (Get-AIBridgeUtcNow) -Force
    $task | Add-Member -NotePropertyName claimed_by -NotePropertyValue "claude" -Force
    Write-AIBridgeJsonAtomic -Path $claimedPath -InputObject $task | Out-Null

    ConvertTo-AIBridgeOutput ([ordered]@{
        status = "claimed"
        id = $task.id
        claimed_path = $claimedPath
        task = $task
    })
    exit 0
}

ConvertTo-AIBridgeOutput ([ordered]@{
    status = "empty"
    id = $null
    claimed_path = $null
    checked_at = Get-AIBridgeUtcNow
})
