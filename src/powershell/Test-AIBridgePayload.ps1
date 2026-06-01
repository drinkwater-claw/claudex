[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $Path,

    [ValidateSet("task", "result", "auto")]
    [string] $Kind = "auto"
)

$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "Bridge.Common.psm1") -Force

function Add-ValidationError {
    param(
        [System.Collections.Generic.List[string]] $Errors,
        [string] $Message
    )

    $Errors.Add($Message)
}

function Test-RequiredString {
    param(
        [object] $Payload,
        [string] $Name,
        [System.Collections.Generic.List[string]] $Errors
    )

    $value = $Payload.$Name
    if ($null -eq $value -or [string]::IsNullOrWhiteSpace([string] $value)) {
        Add-ValidationError -Errors $Errors -Message "Missing required string: $Name"
    }
}

if (-not (Test-Path $Path)) {
    throw "Payload file not found: $Path"
}

$payload = Read-AIBridgeJson -Path $Path
$errors = New-Object 'System.Collections.Generic.List[string]'
$actualKind = $Kind

if ($Kind -eq "auto") {
    $actualKind = [string] $payload.type
}

if ($payload.schema_version -ne "1.0") {
    Add-ValidationError -Errors $errors -Message "schema_version must be 1.0"
}

if ($actualKind -eq "task") {
    foreach ($field in @("type", "id", "status", "created_at", "requester", "assignee", "prompt", "output_format")) {
        Test-RequiredString -Payload $payload -Name $field -Errors $errors
    }

    if ($payload.type -ne "task") {
        Add-ValidationError -Errors $errors -Message "type must be task"
    }

    if (@("pending", "working", "completed") -notcontains $payload.status) {
        Add-ValidationError -Errors $errors -Message "task status must be pending, working, or completed"
    }

    if ($null -eq $payload.context_files -or $payload.context_files -isnot [array]) {
        Add-ValidationError -Errors $errors -Message "context_files must be an array"
    }
}
elseif ($actualKind -eq "result") {
    foreach ($field in @("type", "id", "task_id", "status", "completed_at", "worker", "summary", "response_markdown")) {
        Test-RequiredString -Payload $payload -Name $field -Errors $errors
    }

    if ($payload.type -ne "result") {
        Add-ValidationError -Errors $errors -Message "type must be result"
    }

    if (@("succeeded", "failed", "partial") -notcontains $payload.status) {
        Add-ValidationError -Errors $errors -Message "result status must be succeeded, failed, or partial"
    }
}
else {
    Add-ValidationError -Errors $errors -Message "Unknown payload type: $actualKind"
}

ConvertTo-AIBridgeOutput ([ordered]@{
    valid = ($errors.Count -eq 0)
    kind = $actualKind
    path = (Resolve-Path $Path).Path
    errors = @($errors)
})
