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

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$binRoot = Join-Path $projectRoot "src\powershell"
$bridgeRoot = Join-Path $env:TEMP ("claudex-smoke-" + [guid]::NewGuid().ToString("N"))

try {
    & (Join-Path $binRoot "Install-AIBridge.ps1") -BridgeRoot $bridgeRoot | Out-Null

    foreach ($dir in @("inbox", "working", "outbox", "archive", "locks", "logs", "tmp", "bin", "docs", "schemas", "examples")) {
        Assert-True (Test-Path (Join-Path $bridgeRoot $dir)) "Expected directory '$dir' to exist."
    }

    $createdJson = & (Join-Path $binRoot "New-AIBridgeTask.ps1") `
        -BridgeRoot $bridgeRoot `
        -Prompt "Smoke test task with UTF-8 text: 中文优先, StepDock, DeepSeek, npm run build." `
        -ContextFiles @($PSCommandPath) `
        -OutputFormat "markdown"

    $created = $createdJson | ConvertFrom-Json
    Assert-True ([string]::IsNullOrWhiteSpace($created.id) -eq $false) "Expected task id."
    Assert-True (Test-Path $created.path) "Expected task file to be written."

    $taskValidation = (& (Join-Path $binRoot "Test-AIBridgePayload.ps1") -Path $created.path -Kind task) | ConvertFrom-Json
    Assert-True ($taskValidation.valid -eq $true) "Expected task validation to pass."

    $claimed = (& (Join-Path $binRoot "Get-AIBridgeNextTask.ps1") -BridgeRoot $bridgeRoot | ConvertFrom-Json)
    Assert-True ($claimed.status -eq "claimed") "Expected a claimed task."
    Assert-True ($claimed.id -eq $created.id) "Expected claimed id to match created id."
    Assert-True ($claimed.task.prompt -like "*中文优先*") "Expected UTF-8 task text to survive claim."

    $responseFile = Join-Path $bridgeRoot "tmp\$($created.id).response.md"
    "Claudex smoke result." | Set-Content -LiteralPath $responseFile -Encoding UTF8

    $completed = (& (Join-Path $binRoot "Complete-AIBridgeTask.ps1") `
        -BridgeRoot $bridgeRoot `
        -Id $created.id `
        -ResponseFile $responseFile `
        -Summary "Smoke completed." `
        -Status "succeeded" | ConvertFrom-Json)

    Assert-True (Test-Path $completed.result_path) "Expected result file."
    Assert-True (Test-Path $completed.archive_path) "Expected archive file."

    $resultValidation = (& (Join-Path $binRoot "Test-AIBridgePayload.ps1") -Path $completed.result_path -Kind result) | ConvertFrom-Json
    Assert-True ($resultValidation.valid -eq $true) "Expected result validation to pass."

    $result = (& (Join-Path $binRoot "Wait-AIBridgeResult.ps1") -BridgeRoot $bridgeRoot -Id $created.id -TimeoutSeconds 5 | ConvertFrom-Json)
    Assert-True ($result.response_markdown -eq "Claudex smoke result.") "Expected response body."

    Write-Output "PASS claudex bridge smoke test"
}
finally {
    if (Test-Path $bridgeRoot) {
        Remove-Item -LiteralPath $bridgeRoot -Recurse -Force
    }
}
