[CmdletBinding(DefaultParameterSetName = "NewTask")]
param(
    [Parameter(ParameterSetName = "NewTask", Mandatory = $true)]
    [string] $Prompt,

    [Parameter(ParameterSetName = "ExistingTask", Mandatory = $true)]
    [string] $ExistingTaskId,

    [string] $BridgeRoot = "C:\ai-bridge",
    [string[]] $ContextFiles = @(),
    [string[]] $Requirements = @(),
    [string] $OutputFormat = "markdown",
    [int] $TimeoutSeconds = 900,
    [int] $ApprovalTimeoutSeconds = 900,
    [string] $WindowTitle = "Claude",
    [switch] $NoGuiSend
)

$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "Bridge.Common.psm1") -Force

Initialize-AIBridgeRoot -BridgeRoot $BridgeRoot | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $BridgeRoot "locks") | Out-Null

if ($PSCmdlet.ParameterSetName -eq "NewTask") {
    $created = (& (Join-Path $PSScriptRoot "New-AIBridgeTask.ps1") `
        -BridgeRoot $BridgeRoot `
        -Prompt $Prompt `
        -ContextFiles $ContextFiles `
        -Requirements $Requirements `
        -OutputFormat $OutputFormat) | ConvertFrom-Json
    $taskId = $created.id
}
else {
    $taskId = $ExistingTaskId
}

$lockPath = Join-Path (Join-Path $BridgeRoot "locks") "$taskId.invoke.lock"
$logPath = Join-Path (Join-Path $BridgeRoot "logs") "invoke-$taskId.log"
$approvalLogPath = Join-Path (Join-Path $BridgeRoot "logs") "claude-approval-$taskId.log"
$watcher = $null

if (Test-Path $lockPath) {
    throw "Task is already being invoked: $taskId"
}

try {
    [System.IO.File]::WriteAllText($lockPath, ([DateTimeOffset]::UtcNow.ToString("o") + " pid=$PID"), [System.Text.Encoding]::UTF8)
    Add-Content -LiteralPath $logPath -Value ("START " + [DateTimeOffset]::UtcNow.ToString("o") + " " + $taskId)

    if (-not $NoGuiSend) {
        $watcher = Start-Process -WindowStyle Hidden -PassThru -FilePath powershell -ArgumentList @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File", (Join-Path $PSScriptRoot "Watch-ClaudeBridgeApprovals.ps1"),
            "-WindowTitle", $WindowTitle,
            "-TaskId", $taskId,
            "-TimeoutSeconds", $ApprovalTimeoutSeconds,
            "-PollMilliseconds", "300",
            "-LogPath", $approvalLogPath
        )

        & (Join-Path $PSScriptRoot "Send-ClaudeBridgeWorkerCommand.ps1") `
            -TaskId $taskId `
            -BridgeRoot $BridgeRoot `
            -WindowTitle $WindowTitle `
            -MinimizeCodex | Out-Null
    }

    $result = (& (Join-Path $PSScriptRoot "Wait-AIBridgeResult.ps1") `
        -BridgeRoot $BridgeRoot `
        -Id $taskId `
        -TimeoutSeconds $TimeoutSeconds `
        -PollMilliseconds 500) | ConvertFrom-Json

    $resultPath = Join-Path (Join-Path $BridgeRoot "outbox") "$taskId.result.json"
    $validation = (& (Join-Path $PSScriptRoot "Test-AIBridgePayload.ps1") -Path $resultPath -Kind result) | ConvertFrom-Json

    Add-Content -LiteralPath $logPath -Value ("DONE " + [DateTimeOffset]::UtcNow.ToString("o") + " " + $taskId + " " + $result.status)

    ConvertTo-AIBridgeOutput ([ordered]@{
        id = $taskId
        status = $result.status
        validation_valid = $validation.valid
        validation_errors = @($validation.errors)
        result_path = $resultPath
        approval_log_path = $approvalLogPath
        response_markdown = $result.response_markdown
    })
}
finally {
    if ($watcher -and -not $watcher.HasExited) {
        Stop-Process -Id $watcher.Id -ErrorAction SilentlyContinue
    }

    if (Test-Path $lockPath) {
        Remove-Item -LiteralPath $lockPath -Force
    }
}
