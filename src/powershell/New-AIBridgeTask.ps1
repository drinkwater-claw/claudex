[CmdletBinding()]
param(
    [string] $BridgeRoot = "C:\ai-bridge",

    [Parameter(Mandatory = $true)]
    [string] $Prompt,

    [string[]] $ContextFiles = @(),

    [string[]] $Requirements = @(),

    [string] $OutputFormat = "markdown",

    [string] $Role = "claude-worker",

    [string] $ParentId = "",

    [switch] $Wait,

    [int] $TimeoutSeconds = 600
)

$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "Bridge.Common.psm1") -Force

$root = Initialize-AIBridgeRoot -BridgeRoot $BridgeRoot
$id = New-AIBridgeId
$createdAt = Get-AIBridgeUtcNow
$taskPath = Join-Path (Join-Path $root "inbox") (Get-AIBridgeTaskFileName -Id $id)

$task = [ordered]@{
    schema_version = "1.0"
    type = "task"
    id = $id
    status = "pending"
    created_at = $createdAt
    requester = "codex"
    assignee = "claude"
    role = $Role
    prompt = $Prompt
    context_files = @($ContextFiles)
    requirements = @($Requirements)
    output_format = $OutputFormat
    parent_id = $(if ([string]::IsNullOrWhiteSpace($ParentId)) { $null } else { $ParentId })
    metadata = [ordered]@{
        bridge_root = $root
        host = $env:COMPUTERNAME
        cwd = (Get-Location).Path
        pid = $PID
    }
}

Write-AIBridgeJsonAtomic -Path $taskPath -InputObject $task | Out-Null

if ($Wait) {
    & (Join-Path $PSScriptRoot "Wait-AIBridgeResult.ps1") -BridgeRoot $root -Id $id -TimeoutSeconds $TimeoutSeconds
    exit $LASTEXITCODE
}

ConvertTo-AIBridgeOutput ([ordered]@{
    status = "submitted"
    id = $id
    path = $taskPath
    created_at = $createdAt
})
