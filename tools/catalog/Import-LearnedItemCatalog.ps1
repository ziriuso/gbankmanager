param(
    [string]$ManifestPath = ".\\tools\\catalog\\runtime\\item-catalog-input.json",
    [string]$LearnedRowsPath,
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

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "Learned rows path is required."
    }

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "JSON input not found: $Path"
    }

    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
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

function Resolve-AbsolutePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return [System.IO.Path]::GetFullPath($Path)
}

function Get-LearnedRows {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Payload
    )

    $itemsProperty = Get-ObjectPropertyValue -Object $Payload -Name "items"
    if ($null -ne $itemsProperty) {
        return @($itemsProperty)
    }

    if ($Payload -is [System.Array]) {
        return @($Payload)
    }

    throw "Learned import payload must expose an items array."
}

function ConvertTo-ManifestItemRecord {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Item,

        [string]$StatusOverride
    )

    $itemID = [int](Get-ObjectPropertyValue -Object $Item -Name "itemID")
    $status = if (-not [string]::IsNullOrWhiteSpace($StatusOverride)) {
        $StatusOverride
    } else {
        [string](Get-ObjectPropertyValue -Object $Item -Name "status")
    }

    $unresolved = Get-ObjectPropertyValue -Object $Item -Name "unresolved"
    if ($null -eq $unresolved) {
        $unresolved = ($status -eq "unresolved")
    } else {
        $unresolved = [bool]$unresolved
    }

    return [pscustomobject][ordered]@{
        itemID = $itemID
        name = [string](Get-ObjectPropertyValue -Object $Item -Name "name")
        quality = Get-ObjectPropertyValue -Object $Item -Name "quality"
        qualityName = Get-ObjectPropertyValue -Object $Item -Name "qualityName"
        craftedQuality = Get-ObjectPropertyValue -Object $Item -Name "craftedQuality"
        craftedQualityIcon = Get-ObjectPropertyValue -Object $Item -Name "craftedQualityIcon"
        status = $status
        lastVerifiedAt = Get-ObjectPropertyValue -Object $Item -Name "lastVerifiedAt"
        unresolved = $unresolved
        source = [string](Get-ObjectPropertyValue -Object $Item -Name "source")
        target = Get-ObjectPropertyValue -Object $Item -Name "target"
        build = Get-ObjectPropertyValue -Object $Item -Name "build"
        locale = Get-ObjectPropertyValue -Object $Item -Name "locale"
    }
}

function ConvertTo-LearnedImportRecord {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Item,

        [AllowNull()]
        [object]$Payload
    )

    $itemIDValue = Get-ObjectPropertyValue -Object $Item -Name "itemID"
    if ($null -eq $itemIDValue) {
        throw "Each learned row must include itemID."
    }

    $itemID = [int]$itemIDValue
    if ($itemID -le 0) {
        throw "Each learned row must include a positive itemID."
    }

    $name = [string](Get-ObjectPropertyValue -Object $Item -Name "name")
    if ([string]::IsNullOrWhiteSpace($name)) {
        throw "Each learned row must include name."
    }

    $quality = Get-ObjectPropertyValue -Object $Item -Name "quality"
    if ($null -ne $quality -and [string]::IsNullOrWhiteSpace([string]$quality)) {
        $quality = $null
    }

    $qualityName = [string](Get-ObjectPropertyValue -Object $Item -Name "qualityName")
    if ([string]::IsNullOrWhiteSpace($qualityName)) {
        $qualityName = $null
    }

    $craftedQuality = Get-ObjectPropertyValue -Object $Item -Name "craftedQuality"
    if ($null -ne $craftedQuality -and [string]::IsNullOrWhiteSpace([string]$craftedQuality)) {
        $craftedQuality = $null
    } elseif ($null -ne $craftedQuality) {
        $craftedQuality = [int]$craftedQuality
        if ($craftedQuality -le 0) {
            $craftedQuality = $null
        }
    }

    $craftedQualityIcon = [string](Get-ObjectPropertyValue -Object $Item -Name "craftedQualityIcon")
    if ([string]::IsNullOrWhiteSpace($craftedQualityIcon)) {
        if ($null -ne $craftedQuality) {
            $craftedQualityIcon = "Professions-ChatIcon-Quality-Tier$craftedQuality"
        } else {
            $craftedQualityIcon = $null
        }
    }

    $source = [string](Get-ObjectPropertyValue -Object $Item -Name "source")
    if ([string]::IsNullOrWhiteSpace($source)) {
        $source = [string](Get-ObjectPropertyValue -Object $Payload -Name "source")
    }
    if ([string]::IsNullOrWhiteSpace($source)) {
        $source = "addon_saved_search_catalog"
    }

    $target = Get-ObjectPropertyValue -Object $Item -Name "target"
    if ($null -eq $target) {
        $target = Get-ObjectPropertyValue -Object $Payload -Name "target"
    }

    $build = Get-ObjectPropertyValue -Object $Item -Name "build"
    if ($null -eq $build) {
        $build = Get-ObjectPropertyValue -Object $Payload -Name "build"
    }

    $locale = Get-ObjectPropertyValue -Object $Item -Name "locale"
    if ($null -eq $locale) {
        $locale = Get-ObjectPropertyValue -Object $Payload -Name "locale"
    }

    return [pscustomobject][ordered]@{
        itemID = $itemID
        name = $name
        quality = $quality
        qualityName = $qualityName
        craftedQuality = $craftedQuality
        craftedQualityIcon = $craftedQualityIcon
        status = "learned"
        lastVerifiedAt = $null
        unresolved = $false
        source = $source
        target = $target
        build = $build
        locale = $locale
    }
}

function Merge-LearnedRecord {
    param(
        [Parameter(Mandatory = $true)]
        [object]$ExistingRecord,

        [Parameter(Mandatory = $true)]
        [object]$LearnedRecord
    )

    $quality = $LearnedRecord.quality
    if ($null -eq $quality) {
        $quality = $ExistingRecord.quality
    }

    $qualityName = $LearnedRecord.qualityName
    if ([string]::IsNullOrWhiteSpace([string]$qualityName)) {
        $qualityName = $ExistingRecord.qualityName
    }

    $craftedQuality = $LearnedRecord.craftedQuality
    if ($null -eq $craftedQuality) {
        $craftedQuality = $ExistingRecord.craftedQuality
    }

    $craftedQualityIcon = $LearnedRecord.craftedQualityIcon
    if ([string]::IsNullOrWhiteSpace([string]$craftedQualityIcon)) {
        $craftedQualityIcon = $ExistingRecord.craftedQualityIcon
    }

    $target = $LearnedRecord.target
    if ($null -eq $target) {
        $target = $ExistingRecord.target
    }

    $build = $LearnedRecord.build
    if ($null -eq $build) {
        $build = $ExistingRecord.build
    }

    $locale = $LearnedRecord.locale
    if ($null -eq $locale) {
        $locale = $ExistingRecord.locale
    }

    $source = $LearnedRecord.source
    if ([string]::IsNullOrWhiteSpace([string]$source)) {
        $source = $ExistingRecord.source
    }

    return [pscustomobject][ordered]@{
        itemID = $ExistingRecord.itemID
        name = $LearnedRecord.name
        quality = $quality
        qualityName = $qualityName
        craftedQuality = $craftedQuality
        craftedQualityIcon = $craftedQualityIcon
        status = "learned"
        lastVerifiedAt = $null
        unresolved = $false
        source = $source
        target = $target
        build = $build
        locale = $locale
    }
}

function Write-ImportResult {
    param(
        [Parameter(Mandatory = $true)]
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
$learnedPayload = Get-JsonObject -Path $LearnedRowsPath
$learnedRows = Get-LearnedRows -Payload $learnedPayload

$mergedIndex = @{}
$learnedIndex = @{}

foreach ($item in $learnedRows) {
    $record = ConvertTo-LearnedImportRecord -Item $item -Payload $learnedPayload
    $learnedIndex[[string]$record.itemID] = $record
}

$addedCount = 0
$refreshedCount = 0
$retainedCount = 0
$skippedConfirmedCount = 0

foreach ($item in @($existingManifest.items)) {
    $existingRecord = ConvertTo-ManifestItemRecord -Item $item
    $key = [string]$existingRecord.itemID

    if ($learnedIndex.ContainsKey($key)) {
        $learnedRecord = $learnedIndex[$key]

        if ([string]$existingRecord.status -eq "confirmed") {
            $mergedIndex[$key] = $existingRecord
            $retainedCount += 1
            $skippedConfirmedCount += 1
        } else {
            $mergedIndex[$key] = Merge-LearnedRecord -ExistingRecord $existingRecord -LearnedRecord $learnedRecord
            $refreshedCount += 1
        }

        $null = $learnedIndex.Remove($key)
        continue
    }

    $mergedIndex[$key] = $existingRecord
    $retainedCount += 1
}

foreach ($key in @($learnedIndex.Keys | Sort-Object { [int]$_ })) {
    $mergedIndex[$key] = $learnedIndex[$key]
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

$generatedAt = Get-ObjectPropertyValue -Object $learnedPayload -Name "generatedAt"
if ([string]::IsNullOrWhiteSpace([string]$generatedAt)) {
    $generatedAt = Get-ObjectPropertyValue -Object $learnedPayload -Name "exportedAt"
}
if ([string]::IsNullOrWhiteSpace([string]$generatedAt)) {
    $generatedAt = (Get-Date).ToString("yyyy-MM-dd")
}

$mergedManifest = [pscustomobject][ordered]@{
    source = if ($existingManifest.source) { [string]$existingManifest.source } elseif (Get-ObjectPropertyValue -Object $learnedPayload -Name "source") { [string](Get-ObjectPropertyValue -Object $learnedPayload -Name "source") } else { "manual_manifest" }
    generatedAt = [string]$generatedAt
    region = Get-ObjectPropertyValue -Object $existingManifest -Name "region"
    target = Get-ObjectPropertyValue -Object $existingManifest -Name "target"
    build = Get-ObjectPropertyValue -Object $existingManifest -Name "build"
    locale = Get-ObjectPropertyValue -Object $existingManifest -Name "locale"
    itemCount = $mergedItems.Count
    unresolvedCount = @($mergedItems | Where-Object { [string]$_.status -ne "confirmed" }).Count
    items = $mergedItems
}

$mergedManifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath

$summary = [pscustomobject][ordered]@{
    status = "imported"
    message = "Imported learned runtime rows into the checked-in manifest."
    manifestPath = Resolve-AbsolutePath -Path $OutputPath
    itemCount = $mergedItems.Count
    addedCount = $addedCount
    refreshedCount = $refreshedCount
    retainedCount = $retainedCount
    skippedConfirmedCount = $skippedConfirmedCount
    learnedRowsPath = Resolve-AbsolutePath -Path $LearnedRowsPath
}

Write-ImportResult -Summary $summary -ExitCode 0
