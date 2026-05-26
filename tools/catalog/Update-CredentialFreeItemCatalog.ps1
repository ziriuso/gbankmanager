param(
    [string]$Region = "us",
    [string]$ManifestPath = ".\\tools\\catalog\\runtime\\item-catalog-input.json",
    [string]$OutputLuaPath = ".\\GBankManager_ItemData\\Data.lua"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-ExistingManifest {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return @{
            source = "undermine_exchange_public"
            generatedAt = (Get-Date).ToString("yyyy-MM-dd")
            items = @()
        }
    }

    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Merge-ItemRecord {
    param(
        [hashtable]$Index,
        [int]$ItemID,
        [string]$DefaultSource
    )

    $key = [string]$ItemID
    if (-not $Index.ContainsKey($key)) {
        $Index[$key] = @{
            itemID = $ItemID
            name = "Item $ItemID"
            quality = $null
            qualityName = $null
            unresolved = $true
            source = $DefaultSource
        }
    }
}

$existingManifest = Get-ExistingManifest -Path $ManifestPath
$index = @{}

foreach ($item in @($existingManifest.items)) {
    $itemID = [int]$item.itemID
    $record = @{
        itemID = $itemID
        name = [string]$item.name
        quality = $item.quality
        qualityName = $item.qualityName
        unresolved = [bool]($item.unresolved -eq $true)
        source = if ($item.source) { [string]$item.source } else { "existing_manifest" }
    }
    $index[[string]$itemID] = $record
}

$itemSummaryUrl = "https://api.undermine.exchange/v1/region/$Region/items.json"
$commoditySummaryUrl = "https://api.undermine.exchange/v1/region/$Region/commodities.json"

try {
    Write-Host "Fetching item universe from $itemSummaryUrl"
    $itemSummary = Invoke-RestMethod -Uri $itemSummaryUrl -Method Get
    Write-Host "Fetching commodity universe from $commoditySummaryUrl"
    $commoditySummary = Invoke-RestMethod -Uri $commoditySummaryUrl -Method Get
}
catch {
    $message = $_.Exception.Message
    throw "Credential-free live refresh is currently unavailable. The current Undermine Exchange API host requires authenticated access or a different supported public endpoint. Original error: $message"
}

foreach ($property in ($itemSummary.result.items.PSObject.Properties | Select-Object -ExpandProperty Name)) {
    Merge-ItemRecord -Index $index -ItemID ([int]$property) -DefaultSource "undermine_items"
}

foreach ($property in ($commoditySummary.result.items.PSObject.Properties | Select-Object -ExpandProperty Name)) {
    Merge-ItemRecord -Index $index -ItemID ([int]$property) -DefaultSource "undermine_commodities"
}

$mergedItems = @(
    $index.GetEnumerator() |
        ForEach-Object { $_.Value } |
        Sort-Object -Property @{ Expression = { if ($_.unresolved) { 1 } else { 0 } } }, @{ Expression = { $_.name } }, @{ Expression = { $_.itemID } }
)

$manifest = [pscustomobject]@{
    source = "undermine_exchange_public"
    generatedAt = (Get-Date).ToString("yyyy-MM-dd")
    region = $Region
    itemCount = $mergedItems.Count
    unresolvedCount = (@($mergedItems | Where-Object { $_.unresolved -eq $true })).Count
    items = $mergedItems
}

$manifestDirectory = Split-Path -Parent $ManifestPath
if (-not (Test-Path -LiteralPath $manifestDirectory)) {
    New-Item -ItemType Directory -Path $manifestDirectory | Out-Null
}

$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ManifestPath
Write-Host "Wrote manifest to $ManifestPath"

$buildScript = Join-Path (Split-Path -Parent $PSCommandPath) "Build-ItemDataAddon.ps1"
& $buildScript -ManifestPath $ManifestPath -OutputLuaPath $OutputLuaPath
