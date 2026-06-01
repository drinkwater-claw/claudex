[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string] $BridgeRoot = "C:\ai-bridge",
    [ValidateRange(0, 3650)]
    [int] $RetentionDays = 30,
    [string[]] $Directories = @("tmp", "logs", "outbox", "archive")
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $BridgeRoot)) {
    throw "Bridge root not found: $BridgeRoot"
}

$root = (Resolve-Path $BridgeRoot).Path
$cutoffUtc = [DateTime]::UtcNow.AddDays(-1 * $RetentionDays)
$deletedFiles = 0
$deletedBytes = 0
$keptFiles = 0
$errors = New-Object 'System.Collections.Generic.List[object]'
$deleted = New-Object 'System.Collections.Generic.List[object]'

foreach ($directory in $Directories) {
    if ([string]::IsNullOrWhiteSpace($directory)) {
        continue
    }

    if ($directory -match '[\\/]') {
        throw "Directory entries must be bridge-root child directory names, not paths: $directory"
    }

    $target = Join-Path $root $directory
    if (-not (Test-Path $target)) {
        continue
    }

    $resolvedTarget = (Resolve-Path $target).Path
    if (-not $resolvedTarget.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to clean a path outside bridge root: $resolvedTarget"
    }

    $files = Get-ChildItem -LiteralPath $resolvedTarget -Recurse -File -ErrorAction SilentlyContinue
    foreach ($file in $files) {
        if ($file.LastWriteTimeUtc -gt $cutoffUtc) {
            $keptFiles++
            continue
        }

        $relativePath = $file.FullName.Substring($root.Length).TrimStart([char[]] @("\", "/"))
        if ($PSCmdlet.ShouldProcess($file.FullName, "Remove old bridge runtime file")) {
            try {
                $length = $file.Length
                Remove-Item -LiteralPath $file.FullName -Force
                $deletedFiles++
                $deletedBytes += $length
                $deleted.Add([ordered]@{
                    path = $relativePath
                    bytes = $length
                    last_write_time_utc = $file.LastWriteTimeUtc.ToString("o")
                })
            }
            catch {
                $errors.Add([ordered]@{
                    path = $relativePath
                    error = $_.Exception.Message
                })
            }
        }
    }
}

[ordered]@{
    bridge_root = $root
    retention_days = $RetentionDays
    cutoff_utc = $cutoffUtc.ToString("o")
    directories = @($Directories)
    deleted_files = $deletedFiles
    deleted_bytes = $deletedBytes
    kept_files = $keptFiles
    deleted = @($deleted.ToArray())
    errors = @($errors.ToArray())
} | ConvertTo-Json -Depth 8
