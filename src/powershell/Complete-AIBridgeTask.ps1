[CmdletBinding()]
param(
    [string] $BridgeRoot = "C:\ai-bridge",

    [Parameter(Mandatory = $true)]
    [string] $Id,

    [string] $ResponseMarkdown = "",

    [string] $ResponseFile = "",

    [string] $Summary = "",

    [ValidateSet("succeeded", "failed", "partial")]
    [string] $Status = "succeeded"
)

$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "Bridge.Common.psm1") -Force

$root = Initialize-AIBridgeRoot -BridgeRoot $BridgeRoot
$taskPath = Join-Path (Join-Path $root "working") (Get-AIBridgeTaskFileName -Id $Id)
$archivePath = Join-Path (Join-Path $root "archive") (Get-AIBridgeTaskFileName -Id $Id)
$resultPath = Join-Path (Join-Path $root "outbox") (Get-AIBridgeResultFileName -Id $Id)

if (-not (Test-Path $taskPath)) {
    throw "Cannot complete task '$Id': working task file not found at $taskPath"
}

if (-not [string]::IsNullOrWhiteSpace($ResponseFile)) {
    if (-not (Test-Path $ResponseFile)) {
        throw "Response file not found: $ResponseFile"
    }

    $ResponseMarkdown = [System.IO.File]::ReadAllText((Resolve-Path $ResponseFile))
}

$ResponseMarkdown = $ResponseMarkdown.TrimEnd("`r", "`n")
$task = Read-AIBridgeJson -Path $taskPath
$completedAt = Get-AIBridgeUtcNow

$result = [ordered]@{
    schema_version = "1.0"
    type = "result"
    id = $Id
    task_id = $Id
    status = $Status
    created_at = $completedAt
    completed_at = $completedAt
    worker = "claude"
    summary = $Summary
    response_markdown = $ResponseMarkdown
    files_changed = @()
    diagnostics = @()
    metadata = [ordered]@{
        bridge_root = $root
        task_prompt = $task.prompt
        output_format = $task.output_format
    }
}

Write-AIBridgeJsonAtomic -Path $resultPath -InputObject $result | Out-Null

$task | Add-Member -NotePropertyName status -NotePropertyValue "completed" -Force
$task | Add-Member -NotePropertyName completed_at -NotePropertyValue $completedAt -Force
$task | Add-Member -NotePropertyName result_path -NotePropertyValue $resultPath -Force
Write-AIBridgeJsonAtomic -Path $taskPath -InputObject $task | Out-Null
Move-Item -LiteralPath $taskPath -Destination $archivePath -Force

ConvertTo-AIBridgeOutput ([ordered]@{
    status = $Status
    id = $Id
    result_path = $resultPath
    archive_path = $archivePath
    completed_at = $completedAt
})
