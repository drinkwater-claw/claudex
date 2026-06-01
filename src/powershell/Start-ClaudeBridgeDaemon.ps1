[CmdletBinding()]
param(
    [string] $BridgeRoot = "C:\ai-bridge",
    [int] $PollSeconds = 10,
    [int] $TaskTimeoutSeconds = 900,
    [string] $WindowTitle = "Claude",
    [string] $LogPath = "C:\ai-bridge\logs\claude-bridge-daemon.log",
    [switch] $Once
)

$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "Bridge.Common.psm1") -Force

Initialize-AIBridgeRoot -BridgeRoot $BridgeRoot | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $BridgeRoot "locks") | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $LogPath) | Out-Null

$pidPath = Join-Path (Join-Path $BridgeRoot "logs") "claude-bridge-daemon.pid"
[System.IO.File]::WriteAllText($pidPath, [string]$PID, [System.Text.Encoding]::UTF8)

function Write-DaemonLog {
    param([hashtable] $Event)
    $Event.at = [DateTimeOffset]::UtcNow.ToString("o")
    Add-Content -LiteralPath $LogPath -Value ($Event | ConvertTo-Json -Compress -Depth 8)
}

Write-DaemonLog @{ event = "start"; pid = $PID; bridge_root = $BridgeRoot; poll_seconds = $PollSeconds }

while ($true) {
    try {
        $inbox = Join-Path $BridgeRoot "inbox"
        $tasks = Get-ChildItem -LiteralPath $inbox -Filter "*.task.json" -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTimeUtc, Name

        foreach ($taskFile in $tasks) {
            $task = Read-AIBridgeJson -Path $taskFile.FullName
            $taskId = [string] $task.id
            if ([string]::IsNullOrWhiteSpace($taskId)) {
                Write-DaemonLog @{ event = "skip_invalid_task"; path = $taskFile.FullName }
                continue
            }

            $resultPath = Join-Path (Join-Path $BridgeRoot "outbox") "$taskId.result.json"
            if (Test-Path $resultPath) {
                Write-DaemonLog @{ event = "skip_existing_result"; id = $taskId }
                continue
            }

            Write-DaemonLog @{ event = "invoke"; id = $taskId; path = $taskFile.FullName }
            try {
                $invoke = (& (Join-Path $PSScriptRoot "Invoke-ClaudeBridgeTask.ps1") `
                    -ExistingTaskId $taskId `
                    -BridgeRoot $BridgeRoot `
                    -TimeoutSeconds $TaskTimeoutSeconds `
                    -ApprovalTimeoutSeconds $TaskTimeoutSeconds `
                    -WindowTitle $WindowTitle) | ConvertFrom-Json
                Write-DaemonLog @{ event = "invoke_done"; id = $taskId; status = $invoke.status; validation_valid = $invoke.validation_valid }
            }
            catch {
                Write-DaemonLog @{ event = "invoke_error"; id = $taskId; error = $_.Exception.Message }
            }
        }
    }
    catch {
        Write-DaemonLog @{ event = "loop_error"; error = $_.Exception.Message }
    }

    if ($Once) {
        break
    }

    Start-Sleep -Seconds $PollSeconds
}

Write-DaemonLog @{ event = "stop"; pid = $PID }
