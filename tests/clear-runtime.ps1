[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

function Assert-True {
    param(
        [bool] $Condition,
        [string] $Message
    )

    if (-not $Condition) {
        throw "ASSERTION FAILED: $Message"
    }
}

function New-TestFile {
    param(
        [string] $Path,
        [string] $Content,
        [datetime] $LastWriteTimeUtc
    )

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null
    Set-Content -LiteralPath $Path -Value $Content -NoNewline -Encoding UTF8
    $item = Get-Item -LiteralPath $Path
    $item.LastWriteTimeUtc = $LastWriteTimeUtc
}

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$binRoot = Join-Path $projectRoot "src\powershell"
$bridgeRoot = Join-Path $env:TEMP ("claudex-clear-" + [guid]::NewGuid().ToString("N"))

try {
    & (Join-Path $binRoot "Install-AIBridge.ps1") -BridgeRoot $bridgeRoot | Out-Null

    $old = [DateTime]::UtcNow.AddDays(-45)
    $new = [DateTime]::UtcNow.AddDays(-5)

    $oldRuntime = @(
        "tmp\old.response.md",
        "logs\old.log",
        "outbox\old.result.json",
        "archive\old.task.json"
    )

    foreach ($relative in $oldRuntime) {
        New-TestFile -Path (Join-Path $bridgeRoot $relative) -Content "old" -LastWriteTimeUtc $old
    }

    $newRuntime = @(
        "tmp\new.response.md",
        "logs\new.log",
        "outbox\new.result.json",
        "archive\new.task.json"
    )

    foreach ($relative in $newRuntime) {
        New-TestFile -Path (Join-Path $bridgeRoot $relative) -Content "new" -LastWriteTimeUtc $new
    }

    $protected = @(
        "inbox\old.task.json",
        "working\old.task.json",
        "bin\old-script.ps1",
        "docs\old-doc.md"
    )

    foreach ($relative in $protected) {
        New-TestFile -Path (Join-Path $bridgeRoot $relative) -Content "protected" -LastWriteTimeUtc $old
    }

    $summary = (& (Join-Path $binRoot "Clear-ClaudeBridgeRuntime.ps1") -BridgeRoot $bridgeRoot -RetentionDays 30) | ConvertFrom-Json

    Assert-True ($summary.deleted_files -eq 4) "Expected four old runtime files to be deleted."
    Assert-True ($summary.deleted_bytes -gt 0) "Expected deleted byte count."

    foreach ($relative in $oldRuntime) {
        Assert-True (-not (Test-Path (Join-Path $bridgeRoot $relative))) "Expected old runtime file removed: $relative"
    }

    foreach ($relative in $newRuntime) {
        Assert-True (Test-Path (Join-Path $bridgeRoot $relative)) "Expected new runtime file kept: $relative"
    }

    foreach ($relative in $protected) {
        Assert-True (Test-Path (Join-Path $bridgeRoot $relative)) "Expected protected file kept: $relative"
    }

    Write-Output "PASS claudex runtime cleanup test"
}
finally {
    if (Test-Path $bridgeRoot) {
        Remove-Item -LiteralPath $bridgeRoot -Recurse -Force
    }
}
