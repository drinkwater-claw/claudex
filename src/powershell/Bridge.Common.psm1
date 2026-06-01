$script:AIBridgeVersion = "0.1.0"

function Get-AIBridgeVersion {
    return $script:AIBridgeVersion
}

function Get-AIBridgeUtcNow {
    return [DateTimeOffset]::UtcNow.ToString("o")
}

function New-AIBridgeId {
    $stamp = [DateTimeOffset]::UtcNow.ToString("yyyyMMdd-HHmmss")
    $suffix = [guid]::NewGuid().ToString("N").Substring(0, 8)
    return "task-$stamp-$suffix"
}

function Get-AIBridgeDirectories {
    return @(
        "inbox",
        "working",
        "outbox",
        "archive",
        "locks",
        "logs",
        "tmp",
        "bin",
        "docs",
        "schemas",
        "examples"
    )
}

function Initialize-AIBridgeRoot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $BridgeRoot
    )

    $rootItem = New-Item -ItemType Directory -Force -Path $BridgeRoot
    foreach ($dir in Get-AIBridgeDirectories) {
        New-Item -ItemType Directory -Force -Path (Join-Path $rootItem.FullName $dir) | Out-Null
    }

    return $rootItem.FullName
}

function ConvertTo-AIBridgeJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object] $InputObject,

        [int] $Depth = 32
    )

    process {
        return ($InputObject | ConvertTo-Json -Depth $Depth)
    }
}

function Write-AIBridgeJsonAtomic {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [object] $InputObject,

        [int] $Depth = 32
    )

    $directory = Split-Path -Parent $Path
    New-Item -ItemType Directory -Force -Path $directory | Out-Null

    $tempName = ".tmp-" + [guid]::NewGuid().ToString("N") + ".json"
    $tempPath = Join-Path $directory $tempName
    $json = $InputObject | ConvertTo-Json -Depth $Depth
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)

    try {
        [System.IO.File]::WriteAllText($tempPath, $json + [Environment]::NewLine, $utf8NoBom)
        Move-Item -LiteralPath $tempPath -Destination $Path -Force
    }
    finally {
        if (Test-Path $tempPath) {
            Remove-Item -LiteralPath $tempPath -Force
        }
    }

    return $Path
}

function Read-AIBridgeJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    return (Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json)
}

function Get-AIBridgeTaskFileName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Id
    )

    return "$Id.task.json"
}

function Get-AIBridgeResultFileName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Id
    )

    return "$Id.result.json"
}

function ConvertTo-AIBridgeOutput {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object] $InputObject
    )

    $InputObject | ConvertTo-Json -Depth 32
}

Export-ModuleMember -Function @(
    "Get-AIBridgeVersion",
    "Get-AIBridgeUtcNow",
    "New-AIBridgeId",
    "Get-AIBridgeDirectories",
    "Initialize-AIBridgeRoot",
    "ConvertTo-AIBridgeJson",
    "Write-AIBridgeJsonAtomic",
    "Read-AIBridgeJson",
    "Get-AIBridgeTaskFileName",
    "Get-AIBridgeResultFileName",
    "ConvertTo-AIBridgeOutput"
)
