param(
    [Parameter()]
    [string]$Target = "Retail",

    [Parameter()]
    [string]$WoWRoot,

    [Parameter()]
    [string]$ClientDirectory,

    [Parameter()]
    [string]$Product,

    [Parameter()]
    [string]$Locale = "en_US",

    [Parameter()]
    [ValidateSet("Fresh", "Resume")]
    [string]$Mode = "Fresh",

    [Parameter()]
    [ValidateSet("Full", "ProcurementCurrentExpansion")]
    [string]$CatalogProfile = "ProcurementCurrentExpansion",

    [Parameter()]
    [string]$FixturePath,

    [Parameter()]
    [string]$OutputPath,

    [Parameter()]
    [string]$ProgressPath,

    [Parameter()]
    [string]$PartialRowsPath,

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

function Get-ProductFromTarget {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SelectedTarget
    )

    switch ($SelectedTarget) {
        "Retail" { return "wow" }
        "PTR" { return "wowt" }
        "Beta" { return "wow_beta" }
        default { throw "Unsupported target '$SelectedTarget' for extraction." }
    }
}

function Get-ResolvedWoWRoot {
    if (-not [string]::IsNullOrWhiteSpace($WoWRoot)) {
        return Get-AbsolutePath -Path $WoWRoot
    }

    if (-not [string]::IsNullOrWhiteSpace($ClientDirectory)) {
        return Get-AbsolutePath -Path (Split-Path -Parent $ClientDirectory)
    }

    return $null
}

function Write-ExtractionResult {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Summary,

        [Parameter(Mandatory = $true)]
        [int]$ExitCode
    )

    if ($Json) {
        $Summary | ConvertTo-Json -Depth 6 -Compress
    } else {
        if ($Summary.status -eq "extracted") {
            Write-Host ("Extracted {0} normalized rows for {1} ({2})." -f $Summary.normalizedCount, $Summary.target, $Summary.build)
            Write-Host ("Wrote normalized rows to {0}" -f $Summary.normalizedRowsPath)
        } else {
            Write-Host ("Extraction failed for target '{0}'." -f $Summary.target)
            Write-Host $Summary.message
        }
    }

    exit $ExitCode
}

try {
    $helperPath = Join-Path $PSScriptRoot "runtime\extract-item-db2.js"
    $wowExportRoot = Join-Path $PSScriptRoot "runtime\wow.export\portable-wow-export-win-x64-0.2.17"
    $runtimeDataPath = Join-Path $PSScriptRoot "runtime\wow-export-data"
    $resolvedOutputPath = if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
        Get-AbsolutePath -Path $OutputPath
    } else {
        Get-AbsolutePath -Path (Join-Path $PSScriptRoot "runtime\item-catalog-extracted.json")
    }
    $resolvedProgressPath = if (-not [string]::IsNullOrWhiteSpace($ProgressPath)) {
        Get-AbsolutePath -Path $ProgressPath
    } else {
        $null
    }
    $resolvedPartialRowsPath = if (-not [string]::IsNullOrWhiteSpace($PartialRowsPath)) {
        Get-AbsolutePath -Path $PartialRowsPath
    } else {
        $null
    }

    $arguments = @(
        "--target", $Target,
        "--mode", $Mode,
        "--catalog-profile", $CatalogProfile,
        "--locale", $Locale,
        "--output", $resolvedOutputPath
    )

    if (-not [string]::IsNullOrWhiteSpace($resolvedProgressPath)) {
        $arguments += @("--progress-path", $resolvedProgressPath)
    }

    if (-not [string]::IsNullOrWhiteSpace($resolvedPartialRowsPath)) {
        $arguments += @("--partial-rows-path", $resolvedPartialRowsPath)
    }

    if (-not [string]::IsNullOrWhiteSpace($FixturePath)) {
        $arguments += @("--fixture", (Get-AbsolutePath -Path $FixturePath))
    } else {
        $resolvedWoWRoot = Get-ResolvedWoWRoot
        if ([string]::IsNullOrWhiteSpace($resolvedWoWRoot)) {
            throw "Extract-ItemDb2.ps1 requires -WoWRoot, -ClientDirectory, or -FixturePath."
        }

        $resolvedProduct = if (-not [string]::IsNullOrWhiteSpace($Product)) {
            $Product
        } else {
            Get-ProductFromTarget -SelectedTarget $Target
        }

        $arguments += @(
            "--wow-root", $resolvedWoWRoot,
            "--product", $resolvedProduct,
            "--wow-export-root", (Get-AbsolutePath -Path $wowExportRoot),
            "--runtime-data-path", (Get-AbsolutePath -Path $runtimeDataPath)
        )
    }

    $helperOutput = & node $helperPath @arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw ("wow.export extraction helper failed: {0}" -f (($helperOutput | Out-String).Trim()))
    }

    $summary = (($helperOutput | Out-String).Trim() | ConvertFrom-Json)
    Write-ExtractionResult -Summary $summary -ExitCode 0
} catch {
    $summary = [pscustomobject]@{
        status = "failed"
        target = $Target
        catalogProfile = $CatalogProfile
        mode = $Mode
        build = $null
        locale = $Locale
        progressPath = $resolvedProgressPath
        partialRowsPath = $resolvedPartialRowsPath
        message = $_.Exception.Message
    }

    Write-ExtractionResult -Summary $summary -ExitCode 1
}
