param(
    [Parameter()]
    [string]$Target = "Retail",

    [Parameter()]
    [string]$WoWRoot,

    [Parameter()]
    [string]$ClientDirectory,

    [Parameter()]
    [string]$Locale = "en_US",

    [Parameter()]
    [ValidateSet("Full", "ProcurementCurrentExpansion")]
    [string]$CatalogProfile = "ProcurementCurrentExpansion",

    [Parameter()]
    [string]$ExtractionOutputPath = ".\\tools\\catalog\\runtime\\item-catalog-extracted.json",

    [Parameter()]
    [string]$ManifestPath = ".\\tools\\catalog\\runtime\\item-catalog-input.json",

    [Parameter()]
    [string]$OutputLuaPath = ".\\GBankManager_ItemData\\Data.lua",

    [Parameter()]
    [string]$ExtractionFixturePath,

    [Parameter()]
    [string]$ProgressPath,

    [Parameter()]
    [string]$PartialRowsPath,

    [Parameter()]
    [switch]$Fresh,

    [Parameter()]
    [switch]$Resume,

    [Parameter()]
    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function New-RequiredPathCheck {
    param(
        [string]$Name,
        [string]$Path
    )

    [pscustomobject]@{
        name = $Name
        path = $Path
        exists = Test-Path -LiteralPath $Path
    }
}

function Get-ObjectPropertyValue {
    param(
        [object]$Object,
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

function Get-AbsolutePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return [System.IO.Path]::GetFullPath($Path)
}

function Get-ExecutionMode {
    if ($Fresh -and $Resume) {
        throw "Select exactly one of -Fresh or -Resume."
    }

    if (-not $Fresh -and -not $Resume) {
        throw "Select exactly one of -Fresh or -Resume."
    }

    if ($Fresh) {
        return "Fresh"
    }

    return "Resume"
}

function Get-ProgressArtifacts {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RequestedTarget,

        [string]$ProgressPathOverride,

        [string]$PartialRowsPathOverride
    )

    $safeTarget = ([string]$RequestedTarget).Trim().ToLowerInvariant() -replace '[^a-z0-9_-]+', '-'
    if ([string]::IsNullOrWhiteSpace($safeTarget)) {
        $safeTarget = "target"
    }

    $stateDirectory = Join-Path $PSScriptRoot "runtime\state"
    $progressPath = if (-not [string]::IsNullOrWhiteSpace($ProgressPathOverride)) {
        Get-AbsolutePath -Path $ProgressPathOverride
    } else {
        Get-AbsolutePath -Path (Join-Path $stateDirectory ("item-catalog-refresh-{0}.json" -f $safeTarget))
    }
    $partialRowsPath = if (-not [string]::IsNullOrWhiteSpace($PartialRowsPathOverride)) {
        Get-AbsolutePath -Path $PartialRowsPathOverride
    } else {
        Get-AbsolutePath -Path (Join-Path $stateDirectory ("item-catalog-refresh-{0}.partial.jsonl" -f $safeTarget))
    }

    return [pscustomobject]@{
        progressPath = $progressPath
        partialRowsPath = $partialRowsPath
    }
}

function Get-ProgressState {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProgressPath
    )

    if (-not (Test-Path -LiteralPath $ProgressPath)) {
        return $null
    }

    return Get-Content -LiteralPath $ProgressPath -Raw | ConvertFrom-Json
}

function Set-ProgressProperty {
    param(
        [Parameter(Mandatory = $true)]
        [object]$State,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        $Value
    )

    $resolvedValue = $Value
    if ($null -ne $Value -and $Value -is [System.Array]) {
        $resolvedValue = [object[]]@($Value)
    }

    $property = $State.PSObject.Properties | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
    if ($null -eq $property) {
        $State | Add-Member -NotePropertyName $Name -NotePropertyValue $resolvedValue
        return
    }

    $property.Value = $resolvedValue
}

function Write-ProgressStateFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProgressPath,

        [Parameter(Mandatory = $true)]
        [object]$State
    )

    $directory = Split-Path -Parent $ProgressPath
    if (-not [string]::IsNullOrWhiteSpace($directory) -and (-not (Test-Path -LiteralPath $directory))) {
        New-Item -ItemType Directory -Path $directory | Out-Null
    }

    $tempPath = "{0}.tmp" -f $ProgressPath
    $State | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $tempPath
    Move-Item -LiteralPath $tempPath -Destination $ProgressPath -Force
}

function Update-RefreshProgressState {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProgressPath,

        [AllowNull()]
        [object]$ExistingState,

        [Parameter(Mandatory = $true)]
        [string]$Phase,

        [Parameter(Mandatory = $true)]
        [string]$PhaseStatus,

        [Parameter(Mandatory = $true)]
        [string]$Mode,

        [AllowNull()]
        [object]$ResolvedTarget,

        [AllowNull()]
        [object]$ProgressArtifacts,

        [AllowNull()]
        [object]$ExtractionSummary,

        [AllowNull()]
        [object]$MergeSummary,

        [AllowNull()]
        [object]$BuildSummary,

        [string]$FailureClass,

        [string]$FailureMessage
    )

    $timestamp = [DateTimeOffset]::UtcNow.ToString("o")
    $state = if ($null -ne $ExistingState) { $ExistingState } else { [pscustomobject]@{} }

    if ($null -eq (Get-ObjectPropertyValue -Object $state -Name "startedAt")) {
        $startedAtValue = if ($null -ne $ExistingState) {
            Get-ObjectPropertyValue -Object $ExistingState -Name "startedAt"
        } elseif ($null -ne $ExtractionSummary) {
            Get-ObjectPropertyValue -Object $ExtractionSummary -Name "lastVerifiedAt"
        } else {
            $timestamp
        }
        Set-ProgressProperty -State $state -Name "startedAt" -Value $startedAtValue
    }

    $overallStatus = switch ($PhaseStatus) {
        "running" { "in_progress" }
        "completed" { "completed" }
        "failed" { "failed" }
        default { $PhaseStatus }
    }

    Set-ProgressProperty -State $state -Name "status" -Value $overallStatus
    Set-ProgressProperty -State $state -Name "mode" -Value $Mode
    Set-ProgressProperty -State $state -Name "phase" -Value $Phase
    Set-ProgressProperty -State $state -Name "phaseStatus" -Value $PhaseStatus
    Set-ProgressProperty -State $state -Name "updatedAt" -Value $timestamp
    Set-ProgressProperty -State $state -Name "progressPath" -Value $ProgressPath

    if ($null -ne $ResolvedTarget) {
        Set-ProgressProperty -State $state -Name "target" -Value $ResolvedTarget.target
        Set-ProgressProperty -State $state -Name "locale" -Value $ResolvedTarget.locale
        Set-ProgressProperty -State $state -Name "wowRoot" -Value $ResolvedTarget.wowRoot
        Set-ProgressProperty -State $state -Name "clientDirectory" -Value $ResolvedTarget.clientDirectory
    }

    if ($null -ne $ProgressArtifacts) {
        Set-ProgressProperty -State $state -Name "partialRowsPath" -Value $ProgressArtifacts.partialRowsPath
    }

    $resumeSupported = $true
    if ($null -ne $ExtractionSummary) {
        $resumeSupported = [bool](Get-ObjectPropertyValue -Object $ExtractionSummary -Name "resumeSupported")
        Set-ProgressProperty -State $state -Name "catalogProfile" -Value (Get-ObjectPropertyValue -Object $ExtractionSummary -Name "catalogProfile")
        Set-ProgressProperty -State $state -Name "build" -Value (Get-ObjectPropertyValue -Object $ExtractionSummary -Name "build")
        Set-ProgressProperty -State $state -Name "rawRowCountSeen" -Value (Get-ObjectPropertyValue -Object $ExtractionSummary -Name "rawRowCountSeen")
        Set-ProgressProperty -State $state -Name "normalizedCountWritten" -Value (Get-ObjectPropertyValue -Object $ExtractionSummary -Name "normalizedCountWritten")
        Set-ProgressProperty -State $state -Name "lastProcessedItemID" -Value (Get-ObjectPropertyValue -Object $ExtractionSummary -Name "lastProcessedItemID")
        Set-ProgressProperty -State $state -Name "lastProcessedIndex" -Value (Get-ObjectPropertyValue -Object $ExtractionSummary -Name "lastProcessedIndex")
        Set-ProgressProperty -State $state -Name "highestSeenItemID" -Value (Get-ObjectPropertyValue -Object $ExtractionSummary -Name "highestSeenItemID")
        Set-ProgressProperty -State $state -Name "outputPath" -Value (Get-ObjectPropertyValue -Object $ExtractionSummary -Name "normalizedRowsPath")
        Set-ProgressProperty -State $state -Name "lastVerifiedAt" -Value (Get-ObjectPropertyValue -Object $ExtractionSummary -Name "lastVerifiedAt")
    }

    Set-ProgressProperty -State $state -Name "resumeSupported" -Value $resumeSupported

    $phaseStartedAt = Get-ObjectPropertyValue -Object $state -Name "phaseStartedAt"
    if ($PhaseStatus -eq "running" -or [string](Get-ObjectPropertyValue -Object $state -Name "phase") -ne $Phase) {
        $phaseStartedAt = $timestamp
    }
    Set-ProgressProperty -State $state -Name "phaseStartedAt" -Value $phaseStartedAt
    if ($PhaseStatus -eq "completed" -or $PhaseStatus -eq "failed") {
        Set-ProgressProperty -State $state -Name "phaseCompletedAt" -Value $timestamp
    }

    $completedPhases = @()
    $existingCompletedPhases = Get-ObjectPropertyValue -Object $state -Name "completedPhases"
    if ($null -ne $existingCompletedPhases) {
        foreach ($existingPhase in @($existingCompletedPhases)) {
            if ($completedPhases -notcontains [string]$existingPhase) {
                $completedPhases += [string]$existingPhase
            }
        }
    }
    if ($null -ne $ExtractionSummary -and ($completedPhases -notcontains "extraction")) {
        $completedPhases += "extraction"
    }
    if ($null -ne $MergeSummary -and ($completedPhases -notcontains "merge")) {
        $completedPhases += "merge"
    }
    if ($null -ne $BuildSummary -and ($completedPhases -notcontains "build")) {
        $completedPhases += "build"
    }
    if ($PhaseStatus -eq "completed" -and ($completedPhases -notcontains $Phase)) {
        $completedPhases += $Phase
    }
    Set-ProgressProperty -State $state -Name "completedPhases" -Value @($completedPhases)

    if ($null -ne $MergeSummary) {
        Set-ProgressProperty -State $state -Name "manifestPath" -Value (Get-ObjectPropertyValue -Object $MergeSummary -Name "manifestPath")
        Set-ProgressProperty -State $state -Name "mergeSummary" -Value $MergeSummary
    }

    if ($null -ne $BuildSummary) {
        Set-ProgressProperty -State $state -Name "outputLuaPath" -Value (Get-ObjectPropertyValue -Object $BuildSummary -Name "outputLuaPath")
        Set-ProgressProperty -State $state -Name "buildSummary" -Value $BuildSummary
    }

    Set-ProgressProperty -State $state -Name "failureClass" -Value $FailureClass
    Set-ProgressProperty -State $state -Name "failureMessage" -Value $FailureMessage
    if ($PhaseStatus -eq "completed" -and $Phase -eq "build") {
        Set-ProgressProperty -State $state -Name "completedAt" -Value $timestamp
    }

    Write-ProgressStateFile -ProgressPath $ProgressPath -State $state
    return $state
}

function Get-CompletedExtractionSummary {
    param(
        [Parameter(Mandatory = $true)]
        [object]$ProgressState,

        [Parameter(Mandatory = $true)]
        [string]$ExtractionOutputPath
    )

    if (-not (Test-Path -LiteralPath $ExtractionOutputPath)) {
        throw ("Resume requested with completed extraction state, but the extracted output is missing at {0}. Re-run with -Fresh." -f $ExtractionOutputPath)
    }

    $extractedDocument = Get-Content -LiteralPath $ExtractionOutputPath -Raw | ConvertFrom-Json

    return [pscustomobject]@{
        status = "extracted"
        mode = "Resume"
        target = Get-ObjectPropertyValue -Object $ProgressState -Name "target"
        catalogProfile = Get-ObjectPropertyValue -Object $ProgressState -Name "catalogProfile"
        build = Get-ObjectPropertyValue -Object $ProgressState -Name "build"
        locale = Get-ObjectPropertyValue -Object $ProgressState -Name "locale"
        rawRowCount = Get-ObjectPropertyValue -Object $ProgressState -Name "rawRowCountSeen"
        rawRowCountSeen = Get-ObjectPropertyValue -Object $ProgressState -Name "rawRowCountSeen"
        normalizedCount = Get-ObjectPropertyValue -Object $extractedDocument -Name "itemCount"
        normalizedCountWritten = Get-ObjectPropertyValue -Object $ProgressState -Name "normalizedCountWritten"
        normalizedRowsPath = (Get-AbsolutePath -Path $ExtractionOutputPath)
        progressPath = Get-ObjectPropertyValue -Object $ProgressState -Name "progressPath"
        partialRowsPath = Get-ObjectPropertyValue -Object $ProgressState -Name "partialRowsPath"
        resumeSupported = [bool](Get-ObjectPropertyValue -Object $ProgressState -Name "resumeSupported")
        phase = "extraction"
        lastProcessedItemID = Get-ObjectPropertyValue -Object $ProgressState -Name "lastProcessedItemID"
        lastProcessedIndex = Get-ObjectPropertyValue -Object $ProgressState -Name "lastProcessedIndex"
        highestSeenItemID = Get-ObjectPropertyValue -Object $ProgressState -Name "highestSeenItemID"
        generatedAt = Get-ObjectPropertyValue -Object $extractedDocument -Name "generatedAt"
        lastVerifiedAt = Get-ObjectPropertyValue -Object $ProgressState -Name "updatedAt"
    }
}

function Remove-ProgressArtifacts {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProgressPath,

        [Parameter(Mandatory = $true)]
        [string]$PartialRowsPath
    )

    if (Test-Path -LiteralPath $ProgressPath) {
        Remove-Item -LiteralPath $ProgressPath -Force
    }

    if (Test-Path -LiteralPath $PartialRowsPath) {
        Remove-Item -LiteralPath $PartialRowsPath -Force
    }
}

function Get-EffectiveResolvedTarget {
    param(
        [Parameter(Mandatory = $true)]
        [object]$ResolvedTarget
    )

    $defaultDataDirectory = [string]$ResolvedTarget.dataDirectory
    $defaultLocaleDirectory = [string]$ResolvedTarget.localeDirectory
    $rootDataDirectory = Join-Path ([string]$ResolvedTarget.wowRoot) "Data"
    $productDataDirectory = Join-Path $rootDataDirectory ([string]$ResolvedTarget.product)

    if ((-not (Test-Path -LiteralPath $defaultDataDirectory)) -and (Test-Path -LiteralPath $rootDataDirectory) -and (Test-Path -LiteralPath $productDataDirectory)) {
        return [pscustomobject]@{
            target = [string]$ResolvedTarget.target
            product = [string]$ResolvedTarget.product
            locale = [string]$ResolvedTarget.locale
            wowRoot = [string]$ResolvedTarget.wowRoot
            clientDirectory = [string]$ResolvedTarget.clientDirectory
            dataDirectory = $rootDataDirectory
            localeDirectory = $productDataDirectory
            installRootSource = [string]$ResolvedTarget.installRootSource
        }
    }

    return $ResolvedTarget
}

function New-RefreshSummary {
    param(
        [string]$Status,
        [string]$RequestedTarget,
        [string]$Mode,
        $FailureClass,
        [string]$Message,
        [object]$ProgressArtifacts,
        [object]$ProgressState,
        [object]$ResolvedTarget,
        [object[]]$PathChecks,
        [object]$ExtractionSummary,
        [object]$MergeSummary,
        [object]$BuildSummary
    )

    $missingPaths = New-Object System.Collections.ArrayList
    if ($null -ne $PathChecks) {
        foreach ($path in @($PathChecks | Where-Object { -not $_.exists } | ForEach-Object { $_.path })) {
            [void]$missingPaths.Add($path)
        }
    }

    $requiredPaths = New-Object System.Collections.ArrayList
    if ($null -ne $PathChecks) {
        foreach ($path in @($PathChecks | ForEach-Object { $_.path })) {
            [void]$requiredPaths.Add($path)
        }
    }

    $checks = New-Object System.Collections.ArrayList
    if ($null -ne $PathChecks) {
        foreach ($check in @($PathChecks)) {
            [void]$checks.Add($check)
        }
    }

    return [pscustomobject]@{
        status = $Status
        requestedTarget = $RequestedTarget
        mode = $Mode
        catalogProfile = if ($null -ne $ExtractionSummary) { Get-ObjectPropertyValue -Object $ExtractionSummary -Name "catalogProfile" } elseif ($null -ne $ProgressState) { Get-ObjectPropertyValue -Object $ProgressState -Name "catalogProfile" } else { $CatalogProfile }
        target = if ($null -ne $ResolvedTarget) { $ResolvedTarget.target } else { $null }
        failureClass = $FailureClass
        message = $Message
        progressPath = if ($null -ne $ProgressArtifacts) { $ProgressArtifacts.progressPath } else { $null }
        partialRowsPath = if ($null -ne $ProgressArtifacts) { $ProgressArtifacts.partialRowsPath } else { $null }
        phase = if ($null -ne $ProgressState) { Get-ObjectPropertyValue -Object $ProgressState -Name "phase" } elseif ($null -ne $ExtractionSummary) { Get-ObjectPropertyValue -Object $ExtractionSummary -Name "phase" } else { $null }
        phaseStatus = if ($null -ne $ProgressState) { Get-ObjectPropertyValue -Object $ProgressState -Name "phaseStatus" } else { $null }
        phaseStartedAt = if ($null -ne $ProgressState) { Get-ObjectPropertyValue -Object $ProgressState -Name "phaseStartedAt" } else { $null }
        phaseCompletedAt = if ($null -ne $ProgressState) { Get-ObjectPropertyValue -Object $ProgressState -Name "phaseCompletedAt" } else { $null }
        completedPhases = if ($null -ne $ProgressState) { Get-ObjectPropertyValue -Object $ProgressState -Name "completedPhases" } else { @() }
        resumeSupported = if ($null -ne $ExtractionSummary) { [bool](Get-ObjectPropertyValue -Object $ExtractionSummary -Name "resumeSupported") } elseif ($null -ne $ProgressState) { [bool](Get-ObjectPropertyValue -Object $ProgressState -Name "resumeSupported") } else { $false }
        wowRoot = if ($null -ne $ResolvedTarget) { $ResolvedTarget.wowRoot } else { $null }
        clientDirectory = if ($null -ne $ResolvedTarget) { $ResolvedTarget.clientDirectory } else { $null }
        dataDirectory = if ($null -ne $ResolvedTarget) { $ResolvedTarget.dataDirectory } else { $null }
        localeDirectory = if ($null -ne $ResolvedTarget) { $ResolvedTarget.localeDirectory } else { $null }
        product = if ($null -ne $ResolvedTarget) { $ResolvedTarget.product } else { $null }
        locale = if ($null -ne $ResolvedTarget) { $ResolvedTarget.locale } else { $Locale }
        installRootSource = if ($null -ne $ResolvedTarget) { $ResolvedTarget.installRootSource } else { $null }
        requiredPaths = $requiredPaths
        missingPaths = $missingPaths
        checks = $checks
        extractionImplemented = $null -ne $ExtractionSummary
        rawRowCount = Get-ObjectPropertyValue -Object $ExtractionSummary -Name "rawRowCount"
        rawRowCountSeen = if ($null -ne $ExtractionSummary) { Get-ObjectPropertyValue -Object $ExtractionSummary -Name "rawRowCountSeen" } elseif ($null -ne $ProgressState) { Get-ObjectPropertyValue -Object $ProgressState -Name "rawRowCountSeen" } else { $null }
        normalizedCount = Get-ObjectPropertyValue -Object $ExtractionSummary -Name "normalizedCount"
        normalizedCountWritten = if ($null -ne $ExtractionSummary) { Get-ObjectPropertyValue -Object $ExtractionSummary -Name "normalizedCountWritten" } elseif ($null -ne $ProgressState) { Get-ObjectPropertyValue -Object $ProgressState -Name "normalizedCountWritten" } else { $null }
        normalizedRowsPath = Get-ObjectPropertyValue -Object $ExtractionSummary -Name "normalizedRowsPath"
        build = if ($null -ne $ProgressState) { Get-ObjectPropertyValue -Object $ProgressState -Name "build" } else { Get-ObjectPropertyValue -Object $ExtractionSummary -Name "build" }
        lastVerifiedAt = if ($null -ne $ProgressState) { Get-ObjectPropertyValue -Object $ProgressState -Name "lastVerifiedAt" } else { Get-ObjectPropertyValue -Object $ExtractionSummary -Name "lastVerifiedAt" }
        lastProcessedItemID = if ($null -ne $ExtractionSummary) { Get-ObjectPropertyValue -Object $ExtractionSummary -Name "lastProcessedItemID" } elseif ($null -ne $ProgressState) { Get-ObjectPropertyValue -Object $ProgressState -Name "lastProcessedItemID" } else { $null }
        lastProcessedIndex = if ($null -ne $ExtractionSummary) { Get-ObjectPropertyValue -Object $ExtractionSummary -Name "lastProcessedIndex" } elseif ($null -ne $ProgressState) { Get-ObjectPropertyValue -Object $ProgressState -Name "lastProcessedIndex" } else { $null }
        highestSeenItemID = if ($null -ne $ExtractionSummary) { Get-ObjectPropertyValue -Object $ExtractionSummary -Name "highestSeenItemID" } elseif ($null -ne $ProgressState) { Get-ObjectPropertyValue -Object $ProgressState -Name "highestSeenItemID" } else { $null }
        manifestPath = Get-ObjectPropertyValue -Object $MergeSummary -Name "manifestPath"
        mergedItemCount = Get-ObjectPropertyValue -Object $MergeSummary -Name "itemCount"
        addedCount = Get-ObjectPropertyValue -Object $MergeSummary -Name "addedCount"
        refreshedCount = Get-ObjectPropertyValue -Object $MergeSummary -Name "refreshedCount"
        retainedCount = Get-ObjectPropertyValue -Object $MergeSummary -Name "retainedCount"
        deprecatedCount = Get-ObjectPropertyValue -Object $MergeSummary -Name "deprecatedCount"
        buildSucceeded = if ($null -ne $BuildSummary) { (Get-ObjectPropertyValue -Object $BuildSummary -Name "status") -eq "built" } else { $false }
        outputLuaPath = Get-ObjectPropertyValue -Object $BuildSummary -Name "outputLuaPath"
        generatedItemCount = Get-ObjectPropertyValue -Object $BuildSummary -Name "itemCount"
        generatedTokenCount = Get-ObjectPropertyValue -Object $BuildSummary -Name "tokenCount"
        itemChunkCount = Get-ObjectPropertyValue -Object $BuildSummary -Name "itemChunkCount"
        tokenChunkCount = Get-ObjectPropertyValue -Object $BuildSummary -Name "tokenChunkCount"
        generatedFileCount = Get-ObjectPropertyValue -Object $BuildSummary -Name "generatedFileCount"
        tocPath = Get-ObjectPropertyValue -Object $BuildSummary -Name "tocPath"
        phaseProgress = [pscustomobject]@{
            current = switch ($(if ($null -ne $ProgressState) { [string](Get-ObjectPropertyValue -Object $ProgressState -Name "phase") } else { [string](Get-ObjectPropertyValue -Object $ExtractionSummary -Name "phase") })) {
                "extraction" { 1 }
                "merge" { 2 }
                "build" { 3 }
                default { $null }
            }
            total = 3
        }
        nextStep = if ($Status -eq "ready" -and $null -ne $BuildSummary) { "addon-rebuilt" } elseif ($Status -eq "ready") { "build-pending" } else { $null }
    }
}

function Write-RefreshResult {
    param(
        [pscustomobject]$Summary,
        [int]$ExitCode
    )

    if ($Json) {
        $Summary | ConvertTo-Json -Depth 6 -Compress
    } else {
        if ($Summary.status -eq "ready") {
            Write-Host ("Refresh target: {0}" -f $Summary.target)
            Write-Host ("WoW root: {0}" -f $Summary.wowRoot)
            Write-Host ("Client directory: {0}" -f $Summary.clientDirectory)
            Write-Host ("Locale directory: {0}" -f $Summary.localeDirectory)
            Write-Host $Summary.message
        } else {
            Write-Host ("Refresh failed [{0}] for target '{1}'." -f $Summary.failureClass, $Summary.requestedTarget)
            Write-Host $Summary.message

            if ($Summary.missingPaths.Count -gt 0) {
                Write-Host "Missing paths:"
                foreach ($path in $Summary.missingPaths) {
                    Write-Host ("- {0}" -f $path)
                }
            }
        }
    }

    exit $ExitCode
}

function Get-PowerShellExecutable {
    $candidates = @("powershell", "pwsh")
    foreach ($commandName in $candidates) {
        try {
            $command = Get-Command $commandName -ErrorAction Stop | Select-Object -First 1
            if ($command -and -not [string]::IsNullOrWhiteSpace([string]$command.Source)) {
                return $command.Source
            }
        } catch {
        }
    }

    throw "Unable to locate a usable PowerShell executable for nested catalog commands."
}

function Invoke-JsonScript {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,

        [Parameter(Mandatory = $true)]
        [hashtable]$Arguments
    )

    $command = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", $ScriptPath
    )

    foreach ($key in $Arguments.Keys) {
        $value = $Arguments[$key]
        if ($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)) {
            continue
        }

        $command += @("-$key", [string]$value)
    }

    $command += "-Json"

    $powerShellExecutable = Get-PowerShellExecutable
    $output = & $powerShellExecutable @command 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw (($output | Out-String).Trim())
    }

    return (($output | Out-String).Trim() | ConvertFrom-Json)
}

$mode = $null
$progressArtifacts = Get-ProgressArtifacts -RequestedTarget $Target -ProgressPathOverride $ProgressPath -PartialRowsPathOverride $PartialRowsPath
$progressState = $null
$resolvedTarget = $null
$effectiveTarget = $null
$pathChecks = @()
$extractionSummary = $null
$mergeSummary = $null
$buildSummary = $null

try {
    $mode = Get-ExecutionMode

    if ($mode -eq "Resume") {
        $progressState = Get-ProgressState -ProgressPath $progressArtifacts.progressPath
        if ($null -eq $progressState) {
            $summary = New-RefreshSummary `
                -Status "failed" `
                -RequestedTarget $Target `
                -Mode $mode `
                -FailureClass "usage" `
                -Message ("Resume requested but no saved progress state exists at {0}. Re-run with -Fresh." -f $progressArtifacts.progressPath) `
                -ProgressArtifacts $progressArtifacts `
                -ProgressState $null `
                -ResolvedTarget $null `
                -PathChecks @() `
                -ExtractionSummary $null `
                -MergeSummary $null `
                -BuildSummary $null
            Write-RefreshResult -Summary $summary -ExitCode 1
        }
    } else {
        Remove-ProgressArtifacts -ProgressPath $progressArtifacts.progressPath -PartialRowsPath $progressArtifacts.partialRowsPath
    }

    $resolveScript = Join-Path $PSScriptRoot "Resolve-WoWTarget.ps1"
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

    $resolvedTarget = & $resolveScript @resolveArguments -Json | ConvertFrom-Json

    $effectiveTarget = Get-EffectiveResolvedTarget -ResolvedTarget $resolvedTarget

    $pathChecks = @(
        (New-RequiredPathCheck -Name "wowRoot" -Path $effectiveTarget.wowRoot),
        (New-RequiredPathCheck -Name "clientDirectory" -Path $effectiveTarget.clientDirectory),
        (New-RequiredPathCheck -Name "dataDirectory" -Path $effectiveTarget.dataDirectory),
        (New-RequiredPathCheck -Name "localeDirectory" -Path $effectiveTarget.localeDirectory)
    )

    $missingChecks = @($pathChecks | Where-Object { -not $_.exists })
    if ($missingChecks.Count -gt 0) {
        $summary = New-RefreshSummary `
            -Status "failed" `
            -RequestedTarget $Target `
            -Mode $mode `
            -FailureClass "environment" `
            -Message "The selected WoW install is missing required client data paths. Verify the target install, locale, and extracted client data layout before running the catalog refresh." `
            -ProgressArtifacts $progressArtifacts `
            -ProgressState $progressState `
            -ResolvedTarget $effectiveTarget `
            -PathChecks $pathChecks `
            -ExtractionSummary $null `
            -MergeSummary $null `
            -BuildSummary $null
        Write-RefreshResult -Summary $summary -ExitCode 1
    }

    $buildManifestPath = Join-Path $effectiveTarget.wowRoot ".build.info"
    $wowExportExecutablePath = Join-Path $PSScriptRoot "runtime\wow.export\portable-wow-export-win-x64-0.2.17\wow.export.exe"
    $shouldRunExtraction = (-not [string]::IsNullOrWhiteSpace($ExtractionFixturePath)) -or ((Test-Path -LiteralPath $buildManifestPath) -and (Test-Path -LiteralPath $wowExportExecutablePath))
    $skipMerge = $false
    $skipBuild = $false
    $resumePhase = if ($null -ne $progressState) { [string](Get-ObjectPropertyValue -Object $progressState -Name "phase") } else { $null }
    $resumePhaseStatus = if ($null -ne $progressState) {
        $storedPhaseStatus = [string](Get-ObjectPropertyValue -Object $progressState -Name "phaseStatus")
        if ([string]::IsNullOrWhiteSpace($storedPhaseStatus)) {
            [string](Get-ObjectPropertyValue -Object $progressState -Name "status")
        } else {
            $storedPhaseStatus
        }
    } else {
        $null
    }
    $shouldRunExtractionPipeline = $shouldRunExtraction -or ($mode -eq "Resume" -and $null -ne $progressState -and @("extraction", "merge", "build") -contains $resumePhase)

    if ($shouldRunExtractionPipeline) {
        $reuseCompletedExtraction = $mode -eq "Resume" -and `
            $null -ne $progressState -and `
            (
                ($resumePhase -eq "extraction" -and $resumePhaseStatus -eq "completed") -or
                ($resumePhase -eq "merge") -or
                ($resumePhase -eq "build")
            )

        if ($mode -eq "Resume" -and $resumePhase -eq "merge" -and $resumePhaseStatus -eq "completed") {
            if (-not (Test-Path -LiteralPath $ManifestPath)) {
                $summary = New-RefreshSummary `
                    -Status "failed" `
                    -RequestedTarget $Target `
                    -Mode $mode `
                    -FailureClass "usage" `
                    -Message ("Resume requested with completed merge state, but the merged manifest is missing at {0}. Re-run with -Fresh." -f (Get-AbsolutePath -Path $ManifestPath)) `
                    -ProgressArtifacts $progressArtifacts `
                    -ProgressState $progressState `
                    -ResolvedTarget $effectiveTarget `
                    -PathChecks $pathChecks `
                    -ExtractionSummary $null `
                    -MergeSummary $null `
                    -BuildSummary $null
                Write-RefreshResult -Summary $summary -ExitCode 1
            }

            $skipMerge = $true
        }

        if ($mode -eq "Resume" -and $resumePhase -eq "build") {
            if (-not (Test-Path -LiteralPath $ManifestPath)) {
                $summary = New-RefreshSummary `
                    -Status "failed" `
                    -RequestedTarget $Target `
                    -Mode $mode `
                    -FailureClass "usage" `
                    -Message ("Resume requested with build phase state, but the merged manifest is missing at {0}. Re-run with -Fresh." -f (Get-AbsolutePath -Path $ManifestPath)) `
                    -ProgressArtifacts $progressArtifacts `
                    -ProgressState $progressState `
                    -ResolvedTarget $effectiveTarget `
                    -PathChecks $pathChecks `
                    -ExtractionSummary $null `
                    -MergeSummary $null `
                    -BuildSummary $null
                Write-RefreshResult -Summary $summary -ExitCode 1
            }

            $skipMerge = $true
            if ($resumePhaseStatus -eq "completed" -and (Test-Path -LiteralPath $OutputLuaPath)) {
                $skipBuild = $true
                $buildSummary = Get-ObjectPropertyValue -Object $progressState -Name "buildSummary"
            }
        }

        if ($reuseCompletedExtraction) {
            try {
                $extractionSummary = Get-CompletedExtractionSummary -ProgressState $progressState -ExtractionOutputPath $ExtractionOutputPath
            } catch {
                $summary = New-RefreshSummary `
                    -Status "failed" `
                    -RequestedTarget $Target `
                    -Mode $mode `
                    -FailureClass "usage" `
                    -Message $_.Exception.Message `
                    -ProgressArtifacts $progressArtifacts `
                    -ProgressState $progressState `
                    -ResolvedTarget $effectiveTarget `
                    -PathChecks $pathChecks `
                    -ExtractionSummary $null `
                    -MergeSummary $null `
                    -BuildSummary $null
                Write-RefreshResult -Summary $summary -ExitCode 1
            }
        } else {
            $extractScript = Join-Path $PSScriptRoot "Extract-ItemDb2.ps1"
            $extractArguments = @{
                Target = $effectiveTarget.target
                Mode = $mode
                CatalogProfile = $CatalogProfile
                WoWRoot = $effectiveTarget.wowRoot
                ClientDirectory = $effectiveTarget.clientDirectory
                Product = $effectiveTarget.product
                Locale = $effectiveTarget.locale
                OutputPath = $ExtractionOutputPath
                ProgressPath = $progressArtifacts.progressPath
                PartialRowsPath = $progressArtifacts.partialRowsPath
            }

            if (-not [string]::IsNullOrWhiteSpace($ExtractionFixturePath)) {
                $extractArguments.FixturePath = $ExtractionFixturePath
            }

            try {
                $extractionSummary = Invoke-JsonScript -ScriptPath $extractScript -Arguments $extractArguments
                $progressState = Get-ProgressState -ProgressPath $progressArtifacts.progressPath
            } catch {
                $progressState = Get-ProgressState -ProgressPath $progressArtifacts.progressPath
                $summary = New-RefreshSummary `
                    -Status "failed" `
                    -RequestedTarget $Target `
                    -Mode $mode `
                    -FailureClass "extraction" `
                    -Message $_.Exception.Message `
                    -ProgressArtifacts $progressArtifacts `
                    -ProgressState $progressState `
                    -ResolvedTarget $effectiveTarget `
                    -PathChecks $pathChecks `
                    -ExtractionSummary $null `
                    -MergeSummary $null `
                    -BuildSummary $null
                Write-RefreshResult -Summary $summary -ExitCode 1
            }
        }

        if ($null -eq $extractionSummary -or $extractionSummary.status -ne "extracted") {
            $extractMessage = if ($extractionSummary.message) { [string]$extractionSummary.message } else { "The extractor did not return an extracted status." }
            $summary = New-RefreshSummary `
                -Status "failed" `
                -RequestedTarget $Target `
                -Mode $mode `
                -FailureClass "extraction" `
                -Message $extractMessage `
                -ProgressArtifacts $progressArtifacts `
                -ProgressState $progressState `
                -ResolvedTarget $effectiveTarget `
                -PathChecks $pathChecks `
                -ExtractionSummary $extractionSummary `
                -MergeSummary $null `
                -BuildSummary $null
            Write-RefreshResult -Summary $summary -ExitCode 1
        }

        if (-not $skipMerge) {
            $progressState = Update-RefreshProgressState `
                -ProgressPath $progressArtifacts.progressPath `
                -ExistingState $progressState `
                -Phase "merge" `
                -PhaseStatus "running" `
                -Mode $mode `
                -ResolvedTarget $effectiveTarget `
                -ProgressArtifacts $progressArtifacts `
                -ExtractionSummary $extractionSummary `
                -MergeSummary $null `
                -BuildSummary $null `
                -FailureClass $null `
                -FailureMessage $null

            $mergeScript = Join-Path $PSScriptRoot "Merge-ExtractedItemCatalog.ps1"
            $mergeArguments = @{
                ManifestPath = $ManifestPath
                ExtractedPath = $ExtractionOutputPath
                OutputPath = $ManifestPath
            }

            try {
                $mergeSummary = Invoke-JsonScript -ScriptPath $mergeScript -Arguments $mergeArguments
                $progressState = Update-RefreshProgressState `
                    -ProgressPath $progressArtifacts.progressPath `
                    -ExistingState $progressState `
                    -Phase "merge" `
                    -PhaseStatus "completed" `
                    -Mode $mode `
                    -ResolvedTarget $effectiveTarget `
                    -ProgressArtifacts $progressArtifacts `
                    -ExtractionSummary $extractionSummary `
                    -MergeSummary $mergeSummary `
                    -BuildSummary $null `
                    -FailureClass $null `
                    -FailureMessage $null
            } catch {
                $progressState = Update-RefreshProgressState `
                    -ProgressPath $progressArtifacts.progressPath `
                    -ExistingState $progressState `
                    -Phase "merge" `
                    -PhaseStatus "failed" `
                    -Mode $mode `
                    -ResolvedTarget $effectiveTarget `
                    -ProgressArtifacts $progressArtifacts `
                    -ExtractionSummary $extractionSummary `
                    -MergeSummary $null `
                    -BuildSummary $null `
                    -FailureClass "merge" `
                    -FailureMessage $_.Exception.Message

                $summary = New-RefreshSummary `
                    -Status "failed" `
                    -RequestedTarget $Target `
                    -Mode $mode `
                    -FailureClass "merge" `
                    -Message $_.Exception.Message `
                    -ProgressArtifacts $progressArtifacts `
                    -ProgressState $progressState `
                    -ResolvedTarget $effectiveTarget `
                    -PathChecks $pathChecks `
                    -ExtractionSummary $extractionSummary `
                    -MergeSummary $null `
                    -BuildSummary $null
                Write-RefreshResult -Summary $summary -ExitCode 1
            }

            if ($null -eq $mergeSummary -or $mergeSummary.status -ne "merged") {
                $mergeMessage = if ($mergeSummary.message) { [string]$mergeSummary.message } else { "The manifest merge did not return a merged status." }
                $summary = New-RefreshSummary `
                    -Status "failed" `
                    -RequestedTarget $Target `
                    -Mode $mode `
                    -FailureClass "merge" `
                    -Message $mergeMessage `
                    -ProgressArtifacts $progressArtifacts `
                    -ProgressState $progressState `
                    -ResolvedTarget $effectiveTarget `
                    -PathChecks $pathChecks `
                    -ExtractionSummary $extractionSummary `
                    -MergeSummary $mergeSummary `
                    -BuildSummary $null
                Write-RefreshResult -Summary $summary -ExitCode 1
            }
        } elseif ($resumePhase -eq "merge" -or $resumePhase -eq "build") {
            $mergeSummary = Get-ObjectPropertyValue -Object $progressState -Name "mergeSummary"
        }
    }

    $buildScript = Join-Path $PSScriptRoot "Build-ItemDataAddon.ps1"
    $buildArguments = @{
        ManifestPath = $ManifestPath
        OutputLuaPath = $OutputLuaPath
    }

    if (-not $skipBuild) {
        $progressState = Update-RefreshProgressState `
            -ProgressPath $progressArtifacts.progressPath `
            -ExistingState $progressState `
            -Phase "build" `
            -PhaseStatus "running" `
            -Mode $mode `
            -ResolvedTarget $effectiveTarget `
            -ProgressArtifacts $progressArtifacts `
            -ExtractionSummary $extractionSummary `
            -MergeSummary $mergeSummary `
            -BuildSummary $null `
            -FailureClass $null `
            -FailureMessage $null

        try {
            $buildSummary = Invoke-JsonScript -ScriptPath $buildScript -Arguments $buildArguments
            $progressState = Update-RefreshProgressState `
                -ProgressPath $progressArtifacts.progressPath `
                -ExistingState $progressState `
                -Phase "build" `
                -PhaseStatus "completed" `
                -Mode $mode `
                -ResolvedTarget $effectiveTarget `
                -ProgressArtifacts $progressArtifacts `
                -ExtractionSummary $extractionSummary `
                -MergeSummary $mergeSummary `
                -BuildSummary $buildSummary `
                -FailureClass $null `
                -FailureMessage $null
        } catch {
            $progressState = Update-RefreshProgressState `
                -ProgressPath $progressArtifacts.progressPath `
                -ExistingState $progressState `
                -Phase "build" `
                -PhaseStatus "failed" `
                -Mode $mode `
                -ResolvedTarget $effectiveTarget `
                -ProgressArtifacts $progressArtifacts `
                -ExtractionSummary $extractionSummary `
                -MergeSummary $mergeSummary `
                -BuildSummary $null `
                -FailureClass "build" `
                -FailureMessage $_.Exception.Message

            $summary = New-RefreshSummary `
                -Status "failed" `
                -RequestedTarget $Target `
                -Mode $mode `
                -FailureClass "build" `
                -Message $_.Exception.Message `
                -ProgressArtifacts $progressArtifacts `
                -ProgressState $progressState `
                -ResolvedTarget $effectiveTarget `
                -PathChecks $pathChecks `
                -ExtractionSummary $extractionSummary `
                -MergeSummary $mergeSummary `
                -BuildSummary $null
            Write-RefreshResult -Summary $summary -ExitCode 1
        }

        if ($null -eq $buildSummary -or $buildSummary.status -ne "built") {
            $buildMessage = if ($buildSummary.message) { [string]$buildSummary.message } else { "The generated addon rebuild did not return a built status." }
            $summary = New-RefreshSummary `
                -Status "failed" `
                -RequestedTarget $Target `
                -Mode $mode `
                -FailureClass "build" `
                -Message $buildMessage `
                -ProgressArtifacts $progressArtifacts `
                -ProgressState $progressState `
                -ResolvedTarget $effectiveTarget `
                -PathChecks $pathChecks `
                -ExtractionSummary $extractionSummary `
                -MergeSummary $mergeSummary `
                -BuildSummary $buildSummary
            Write-RefreshResult -Summary $summary -ExitCode 1
        }
    }

    $readyMessage = if ($null -ne $extractionSummary) {
        "Environment validation, extraction, manifest merge, and generated addon rebuild succeeded for the selected WoW target, clearing the earlier not implemented refresh boundary."
    } else {
        "Environment validation passed for the selected WoW target. Extraction was skipped because no local build manifest or wow.export runtime was available, and the generated addon rebuild succeeded from the current manifest."
    }

    $readySummary = New-RefreshSummary `
        -Status "ready" `
        -RequestedTarget $Target `
        -Mode $mode `
        -FailureClass $null `
        -Message $readyMessage `
        -ProgressArtifacts $progressArtifacts `
        -ProgressState $progressState `
        -ResolvedTarget $effectiveTarget `
        -PathChecks $pathChecks `
        -ExtractionSummary $extractionSummary `
        -MergeSummary $mergeSummary `
        -BuildSummary $buildSummary
    Write-RefreshResult -Summary $readySummary -ExitCode 0
} catch {
    $message = $_.Exception.Message
    $failureSummary = New-RefreshSummary `
        -Status "failed" `
        -RequestedTarget $Target `
        -Mode $mode `
        -FailureClass "environment" `
        -Message $message `
        -ProgressArtifacts $progressArtifacts `
        -ProgressState $progressState `
        -ResolvedTarget $(if ($null -ne $effectiveTarget) { $effectiveTarget } else { $resolvedTarget }) `
        -PathChecks $pathChecks `
        -ExtractionSummary $extractionSummary `
        -MergeSummary $mergeSummary `
        -BuildSummary $buildSummary
    Write-RefreshResult -Summary $failureSummary -ExitCode 1
}
