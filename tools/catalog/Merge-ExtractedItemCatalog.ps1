param(
    [string]$ManifestPath = ".\\tools\\catalog\\runtime\\item-catalog-input.json",
    [string]$ExtractedPath = ".\\tools\\catalog\\runtime\\item-catalog-extracted.json",
    [string]$OutputPath = ".\\tools\\catalog\\runtime\\item-catalog-input.json",
    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-JsonObject {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "JSON input not found: $Path"
    }

    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
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

function Get-FastPropertyValue {
    param(
        [AllowNull()]
        [object]$Object,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ($null -eq $Object) {
        return $null
    }

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

function Resolve-AbsolutePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return [System.IO.Path]::GetFullPath($Path)
}

function Write-ContentAtomic {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    $directory = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($directory) -and (-not (Test-Path -LiteralPath $directory))) {
        New-Item -ItemType Directory -Path $directory | Out-Null
    }

    $tempPath = "{0}.tmp" -f $Path
    Set-Content -LiteralPath $tempPath -Value $Content
    Move-Item -LiteralPath $tempPath -Destination $Path -Force
}

function ConvertTo-OrderedItemRecord {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Item,

        [string]$StatusOverride
    )

    $itemID = [int](Get-FastPropertyValue -Object $Item -Name "itemID")
    $status = if (-not [string]::IsNullOrWhiteSpace($StatusOverride)) {
        $StatusOverride
    } else {
        [string](Get-FastPropertyValue -Object $Item -Name "status")
    }

    $unresolved = Get-FastPropertyValue -Object $Item -Name "unresolved"
    if ($null -eq $unresolved) {
        $unresolved = ($status -eq "unresolved")
    } else {
        $unresolved = [bool]$unresolved
    }

    return [pscustomobject][ordered]@{
        itemID = $itemID
        name = [string](Get-FastPropertyValue -Object $Item -Name "name")
        quality = Get-FastPropertyValue -Object $Item -Name "quality"
        qualityName = Get-FastPropertyValue -Object $Item -Name "qualityName"
        craftedQuality = Get-FastPropertyValue -Object $Item -Name "craftedQuality"
        craftedQualityIcon = Get-FastPropertyValue -Object $Item -Name "craftedQualityIcon"
        status = $status
        lastVerifiedAt = Get-FastPropertyValue -Object $Item -Name "lastVerifiedAt"
        unresolved = $unresolved
        source = [string](Get-FastPropertyValue -Object $Item -Name "source")
        target = Get-FastPropertyValue -Object $Item -Name "target"
        build = Get-FastPropertyValue -Object $Item -Name "build"
        locale = Get-FastPropertyValue -Object $Item -Name "locale"
    }
}

function Get-BuildSortKey {
    param(
        [AllowNull()]
        [object]$Build
    )

    $rawBuild = [string]$Build
    if ([string]::IsNullOrWhiteSpace($rawBuild)) {
        return $null
    }

    $segments = $rawBuild -split '[^0-9]+'
    $parts = New-Object System.Collections.Generic.List[int]
    foreach ($segment in $segments) {
        if ([string]::IsNullOrWhiteSpace($segment)) {
            continue
        }

        [void]$parts.Add([int]$segment)
    }

    if ($parts.Count -eq 0) {
        return $null
    }

    return ,$parts.ToArray()
}

function Compare-BuildSortKey {
    param(
        [AllowNull()]
        [int[]]$Left,

        [AllowNull()]
        [int[]]$Right
    )

    if ($null -eq $Left -and $null -eq $Right) {
        return 0
    }

    if ($null -eq $Left) {
        return -1
    }

    if ($null -eq $Right) {
        return 1
    }

    $maxCount = [Math]::Max($Left.Length, $Right.Length)
    for ($index = 0; $index -lt $maxCount; $index += 1) {
        $leftPart = if ($index -lt $Left.Length) { $Left[$index] } else { 0 }
        $rightPart = if ($index -lt $Right.Length) { $Right[$index] } else { 0 }

        if ($leftPart -gt $rightPart) {
            return 1
        }

        if ($leftPart -lt $rightPart) {
            return -1
        }
    }

    return 0
}

function Test-ExtractedRowIsFreshEnough {
    param(
        [Parameter(Mandatory = $true)]
        [object]$ExistingItem,

        [Parameter(Mandatory = $true)]
        [object]$ExtractedItem
    )

    $existingStatus = [string](Get-FastPropertyValue -Object $ExistingItem -Name "status")
    if ($existingStatus -ne "confirmed") {
        return $true
    }

    $existingLastVerifiedAt = Get-FastPropertyValue -Object $ExistingItem -Name "lastVerifiedAt"
    $extractedLastVerifiedAt = Get-FastPropertyValue -Object $ExtractedItem -Name "lastVerifiedAt"

    $existingTimestamp = $null
    $extractedTimestamp = $null

    if (-not [string]::IsNullOrWhiteSpace([string]$existingLastVerifiedAt)) {
        $existingTimestamp = [DateTimeOffset]::Parse([string]$existingLastVerifiedAt)
    }

    if (-not [string]::IsNullOrWhiteSpace([string]$extractedLastVerifiedAt)) {
        $extractedTimestamp = [DateTimeOffset]::Parse([string]$extractedLastVerifiedAt)
    }

    if ($null -ne $existingTimestamp -and $null -ne $extractedTimestamp) {
        return $extractedTimestamp -ge $existingTimestamp
    }

    if ($null -eq $existingTimestamp -and $null -ne $extractedTimestamp) {
        return $true
    }

    if ($null -ne $existingTimestamp -and $null -eq $extractedTimestamp) {
        return $false
    }

    $existingBuild = Get-BuildSortKey -Build (Get-FastPropertyValue -Object $ExistingItem -Name "build")
    $extractedBuild = Get-BuildSortKey -Build (Get-FastPropertyValue -Object $ExtractedItem -Name "build")
    $buildComparison = Compare-BuildSortKey -Left $extractedBuild -Right $existingBuild

    return $buildComparison -ge 0
}

function Write-MergeResult {
    param(
        [pscustomobject]$Summary,
        [int]$ExitCode
    )

    if ($Json) {
        $Summary | ConvertTo-Json -Depth 8 -Compress
    } else {
        Write-Host $Summary.message
        Write-Host ("Manifest path: {0}" -f $Summary.manifestPath)
        Write-Host ("Item count: {0}" -f $Summary.itemCount)
    }

    exit $ExitCode
}

$existingManifest = Get-JsonObject -Path $ManifestPath
$extractedManifest = Get-JsonObject -Path $ExtractedPath

$mergedIndex = @{}
$extractedIndex = @{}

foreach ($item in @($extractedManifest.items)) {
    $record = ConvertTo-OrderedItemRecord -Item $item -StatusOverride "confirmed"
    $extractedIndex[[string]$record.itemID] = $record
}

$addedCount = 0
$refreshedCount = 0
$retainedCount = 0
$deprecatedCount = 0

foreach ($item in @($existingManifest.items)) {
    $itemID = [int](Get-FastPropertyValue -Object $item -Name "itemID")
    $key = [string]$itemID

    if ($extractedIndex.ContainsKey($key)) {
        $existingRecord = ConvertTo-OrderedItemRecord -Item $item
        $extractedRecord = $extractedIndex[$key]

        if (Test-ExtractedRowIsFreshEnough -ExistingItem $existingRecord -ExtractedItem $extractedRecord) {
            $mergedIndex[$key] = $extractedRecord
            $refreshedCount += 1
        } else {
            $mergedIndex[$key] = $existingRecord
            $retainedCount += 1
        }

        $null = $extractedIndex.Remove($key)
        continue
    }

    $existingStatus = [string](Get-FastPropertyValue -Object $item -Name "status")
    $mergedStatus = $existingStatus
    if ($existingStatus -eq "confirmed") {
        $mergedStatus = "deprecated"
    }

    if ($mergedStatus -eq "deprecated") {
        $deprecatedCount += 1
    } else {
        $retainedCount += 1
    }

    $mergedIndex[$key] = ConvertTo-OrderedItemRecord -Item $item -StatusOverride $mergedStatus
}

foreach ($key in @($extractedIndex.Keys | Sort-Object { [int]$_ })) {
    $mergedIndex[$key] = $extractedIndex[$key]
    $addedCount += 1
}

$mergedItems = @(
    $mergedIndex.GetEnumerator() |
        Sort-Object { [int]$_.Name } |
        ForEach-Object { $_.Value }
)

$manifestDirectory = Split-Path -Parent $OutputPath
if (-not [string]::IsNullOrWhiteSpace($manifestDirectory) -and (-not (Test-Path -LiteralPath $manifestDirectory))) {
    New-Item -ItemType Directory -Path $manifestDirectory | Out-Null
}

$mergedManifest = [pscustomobject][ordered]@{
    source = if ($extractedManifest.source) { [string]$extractedManifest.source } elseif ($existingManifest.source) { [string]$existingManifest.source } else { "manual_manifest" }
    generatedAt = if ($extractedManifest.generatedAt) { [string]$extractedManifest.generatedAt } else { (Get-Date).ToString("yyyy-MM-dd") }
    region = Get-ObjectPropertyValue -Object $existingManifest -Name "region"
    target = Get-ObjectPropertyValue -Object $extractedManifest -Name "target"
    build = Get-ObjectPropertyValue -Object $extractedManifest -Name "build"
    locale = Get-ObjectPropertyValue -Object $extractedManifest -Name "locale"
    itemCount = $mergedItems.Count
    unresolvedCount = @($mergedItems | Where-Object { [string]$_.status -ne "confirmed" }).Count
    items = $mergedItems
}

$mergedManifestJson = $mergedManifest | ConvertTo-Json -Depth 8
Write-ContentAtomic -Path $OutputPath -Content $mergedManifestJson

$summary = [pscustomobject][ordered]@{
    status = "merged"
    message = "Merged normalized extracted rows into the checked-in manifest."
    manifestPath = Resolve-AbsolutePath -Path $OutputPath
    itemCount = $mergedItems.Count
    addedCount = $addedCount
    refreshedCount = $refreshedCount
    retainedCount = $retainedCount
    deprecatedCount = $deprecatedCount
    target = Get-ObjectPropertyValue -Object $extractedManifest -Name "target"
    build = Get-ObjectPropertyValue -Object $extractedManifest -Name "build"
    locale = Get-ObjectPropertyValue -Object $extractedManifest -Name "locale"
}

Write-MergeResult -Summary $summary -ExitCode 0
