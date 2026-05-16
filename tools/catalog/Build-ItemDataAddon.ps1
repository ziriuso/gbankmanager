param(
    [string]$ManifestPath = ".\\tools\\catalog\\runtime\\item-catalog-input.json",
    [string]$OutputLuaPath = ".\\GBankManager_ItemData\\Data.lua",
    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$exportScript = Join-Path $PSScriptRoot "Export-IndexedItemSearchData.ps1"

if (-not (Test-Path -LiteralPath $ManifestPath)) {
    throw "Manifest not found: $ManifestPath"
}

$input = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$exportSummary = & $exportScript -InputJsonPath $ManifestPath -OutputLuaPath $OutputLuaPath 6>$null

$summary = [pscustomobject]@{
    status = "built"
    manifestPath = [System.IO.Path]::GetFullPath($ManifestPath)
    outputLuaPath = [System.IO.Path]::GetFullPath($OutputLuaPath)
    tocPath = [string]$exportSummary.tocPath
    generatedDirectory = [string]$exportSummary.generatedDirectory
    itemCount = [int]$exportSummary.itemCount
    tokenCount = [int]$exportSummary.tokenCount
    itemChunkCount = [int]$exportSummary.itemChunkCount
    tokenChunkCount = [int]$exportSummary.tokenChunkCount
    generatedFileCount = [int]$exportSummary.generatedFileCount
    generatedAt = if ($input.generatedAt) { [string]$input.generatedAt } else { $null }
    source = if ($input.source) { [string]$input.source } else { $null }
    message = "Generated indexed item-search addon rebuild succeeded from the merged manifest."
}

if ($Json) {
    $summary | ConvertTo-Json -Depth 4 -Compress
} else {
    Write-Host ("Generated addon data: {0}" -f $summary.outputLuaPath)
    Write-Host ("Item count: {0}" -f $summary.itemCount)
}
