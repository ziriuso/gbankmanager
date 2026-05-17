param(
    [Parameter()]
    [ValidateSet("Retail", "PTR", "Beta")]
    [string]$Target = "Retail",

    [Parameter()]
    [string]$WoWRoot,

    [Parameter()]
    [string]$ClientDirectory,

    [Parameter()]
    [string]$Locale = "en_US",

    [Parameter()]
    [string]$ProgressPath,

    [Parameter()]
    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-AbsolutePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return [System.IO.Path]::GetFullPath($Path)
}

function Get-ObjectPropertyValue {
    param(
        [AllowNull()]
        [object]$Object,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ($null -eq $Object) {
        return $null
    }

    $property = $Object.PSObject.Properties | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

function Get-ProgressPathForTarget {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RequestedTarget
    )

    if (-not [string]::IsNullOrWhiteSpace($ProgressPath)) {
        return Get-AbsolutePath -Path $ProgressPath
    }

    $safeTarget = ([string]$RequestedTarget).Trim().ToLowerInvariant() -replace '[^a-z0-9_-]+', '-'
    if ([string]::IsNullOrWhiteSpace($safeTarget)) {
        $safeTarget = "target"
    }

    return Get-AbsolutePath -Path (Join-Path $PSScriptRoot ("runtime\state\item-catalog-refresh-{0}.json" -f $safeTarget))
}

function Resolve-MaintainerTarget {
    $resolveArguments = @{
        Target = $Target
        Locale = $Locale
    }

    if (-not [string]::IsNullOrWhiteSpace($WoWRoot)) {
        $resolveArguments.WoWRoot = $WoWRoot
    }
    if (-not [string]::IsNullOrWhiteSpace($ClientDirectory)) {
        $resolveArguments.ClientDirectory = $ClientDirectory
    }

    $resolveScript = Join-Path $PSScriptRoot "Resolve-WoWTarget.ps1"
    return & $resolveScript @resolveArguments
}

function Get-SyncStatus {
    param(
        [AllowNull()]
        [object]$ProgressState
    )

    if ($null -eq $ProgressState) {
        return "never_synced"
    }

    $status = [string](Get-ObjectPropertyValue -Object $ProgressState -Name "status")
    $phaseStatus = [string](Get-ObjectPropertyValue -Object $ProgressState -Name "phaseStatus")
    $buildSucceeded = Get-ObjectPropertyValue -Object $ProgressState -Name "buildSucceeded"

    if ($status -eq "failed" -or $phaseStatus -eq "failed") {
        return "failed"
    }

    if ($status -eq "in_progress" -or $phaseStatus -eq "running") {
        return "in_progress"
    }

    if ($status -eq "completed" -or $phaseStatus -eq "completed" -or $buildSucceeded -eq $true) {
        return "synced"
    }

    return "unknown"
}

function Get-LastSyncTimestamp {
    param(
        [AllowNull()]
        [object]$ProgressState
    )

    foreach ($field in @("completedAt", "phaseCompletedAt", "updatedAt", "startedAt")) {
        $value = [string](Get-ObjectPropertyValue -Object $ProgressState -Name $field)
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value
        }
    }

    return ""
}

$resolvedTarget = Resolve-MaintainerTarget
$resolvedProgressPath = Get-ProgressPathForTarget -RequestedTarget $Target
$progressState = $null
if (Test-Path -LiteralPath $resolvedProgressPath) {
    $progressState = Get-Content -LiteralPath $resolvedProgressPath -Raw | ConvertFrom-Json
}

$syncStatus = Get-SyncStatus -ProgressState $progressState
$lastSyncAt = Get-LastSyncTimestamp -ProgressState $progressState
$build = [string](Get-ObjectPropertyValue -Object $progressState -Name "build")
$completedPhases = @()
foreach ($phase in @(Get-ObjectPropertyValue -Object $progressState -Name "completedPhases")) {
    if (-not [string]::IsNullOrWhiteSpace([string]$phase)) {
        $completedPhases += [string]$phase
    }
}

$result = [pscustomobject]@{
    status = "ok"
    syncStatus = $syncStatus
    target = [string]$resolvedTarget.target
    wowRoot = [string]$resolvedTarget.wowRoot
    clientDirectory = [string]$resolvedTarget.clientDirectory
    addOnsDirectory = [System.IO.Path]::GetFullPath((Join-Path $resolvedTarget.clientDirectory "Interface\AddOns"))
    progressPath = $resolvedProgressPath
    build = if (-not [string]::IsNullOrWhiteSpace($build)) { $build } else { "" }
    lastSyncAt = $lastSyncAt
    mode = [string](Get-ObjectPropertyValue -Object $progressState -Name "mode")
    phase = [string](Get-ObjectPropertyValue -Object $progressState -Name "phase")
    phaseStatus = [string](Get-ObjectPropertyValue -Object $progressState -Name "phaseStatus")
    nextStep = [string](Get-ObjectPropertyValue -Object $progressState -Name "nextStep")
    buildSucceeded = [bool](Get-ObjectPropertyValue -Object $progressState -Name "buildSucceeded")
    completedPhases = @($completedPhases)
}

if ($Json) {
    $result | ConvertTo-Json -Depth 6 -Compress
    return
}

$result
