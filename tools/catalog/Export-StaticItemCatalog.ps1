param(
    [string]$InputJsonPath = ".\\tools\\catalog\\runtime\\item-catalog-input.json",
    [string]$OutputLuaPath = ".\\GBankManager_ItemData\\Data.lua"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function ConvertTo-LuaString {
    param([string]$Value)

    if ($null -eq $Value) {
        return 'nil'
    }

    $escaped = $Value.Replace('\', '\\').Replace('"', '\"')
    return '"' + $escaped + '"'
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

if (-not (Test-Path -LiteralPath $InputJsonPath)) {
    throw "Input manifest not found: $InputJsonPath"
}

$input = Get-Content -LiteralPath $InputJsonPath -Raw | ConvertFrom-Json
$items = @($input.items | Where-Object {
    [string](Get-FastPropertyValue -Object $_ -Name "status") -ne "deprecated"
})
$generatedAt = if ($input.generatedAt) { [string]$input.generatedAt } else { (Get-Date).ToString("yyyy-MM-dd") }
$source = if ($input.source) { [string]$input.source } else { "manual_manifest" }
$chunkSize = 500

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('local _, ns = ...')
$lines.Add('')
$lines.Add('ns = ns or {}')
$lines.Add('ns.modules = ns.modules or {}')
$lines.Add('ns.data = ns.data or {}')
$lines.Add('')
$lines.Add('local staticItemCatalog = ns.data.staticItemCatalog or {}')
$lines.Add('staticItemCatalog.metadata = {')
$lines.Add("        source = $(ConvertTo-LuaString $source),")
$lines.Add("        generatedAt = $(ConvertTo-LuaString $generatedAt),")
$lines.Add("        itemCount = $($items.Count),")
$lines.Add('}')
$lines.Add('')
$lines.Add('local items = {}')
$lines.Add('staticItemCatalog.items = items')
$lines.Add('')
$lines.Add('local function append_chunk(chunk)')
$lines.Add('    local offset = #items')
$lines.Add('    for index = 1, #chunk do')
$lines.Add('        items[offset + index] = chunk[index]')
$lines.Add('    end')
$lines.Add('end')
$lines.Add('')
$lines.Add('local load_chunk')
$lines.Add('')

$currentChunkItemCount = 0
foreach ($item in $items) {
    if ($currentChunkItemCount -eq 0) {
        $lines.Add('load_chunk = function()')
        $lines.Add('    append_chunk({')
    }

    $itemID = [int](Get-FastPropertyValue -Object $item -Name "itemID")
    $resolvedName = [string](Get-FastPropertyValue -Object $item -Name "name")
    if ([string]::IsNullOrWhiteSpace($resolvedName)) {
        $resolvedName = "Item $itemID"
    }
    $name = ConvertTo-LuaString $resolvedName
    $qualityValue = Get-FastPropertyValue -Object $item -Name "quality"
    $qualityNameValue = Get-FastPropertyValue -Object $item -Name "qualityName"
    $craftedQualityValue = Get-FastPropertyValue -Object $item -Name "craftedQuality"
    $craftedQualityIconValue = Get-FastPropertyValue -Object $item -Name "craftedQualityIcon"
    $quality = if ($null -ne $qualityValue) { [int]$qualityValue } else { $null }
    $qualityName = if ($null -ne $qualityNameValue) { ConvertTo-LuaString ([string]$qualityNameValue) } else { 'nil' }
    $craftedQuality = if ($null -ne $craftedQualityValue) { [int]$craftedQualityValue } else { $null }
    $craftedQualityIcon = if ($null -ne $craftedQualityIconValue) { ConvertTo-LuaString ([string]$craftedQualityIconValue) } else { 'nil' }
    $qualityLiteral = if ($null -ne $quality) { [string]$quality } else { 'nil' }
    $recordFields = New-Object System.Collections.Generic.List[string]
    $recordFields.Add("itemID = $itemID")
    $recordFields.Add("name = $name")
    $recordFields.Add("quality = $qualityLiteral")
    $recordFields.Add("qualityName = $qualityName")
    if ($null -ne $craftedQuality) {
        $recordFields.Add("craftedQuality = $craftedQuality")
    }
    if ($craftedQualityIcon -ne 'nil') {
        $recordFields.Add("craftedQualityIcon = $craftedQualityIcon")
    }
    $lines.Add("        { $($recordFields -join ', ') },")
    $currentChunkItemCount += 1

    if ($currentChunkItemCount -ge $chunkSize) {
        $lines.Add('    })')
        $lines.Add('end')
        $lines.Add('load_chunk()')
        $lines.Add('')
        $currentChunkItemCount = 0
    }
}

if ($currentChunkItemCount -gt 0) {
    $lines.Add('    })')
    $lines.Add('end')
    $lines.Add('load_chunk()')
    $lines.Add('')
}

$lines.Add('')
$lines.Add('ns.data.staticItemCatalog = staticItemCatalog')
$lines.Add('ns.modules.staticItemCatalog = staticItemCatalog')
$lines.Add('')
$lines.Add('return staticItemCatalog')

$outputDirectory = Split-Path -Parent $OutputLuaPath
if (-not (Test-Path -LiteralPath $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory | Out-Null
}

$tempOutputPath = "{0}.tmp" -f $OutputLuaPath
Set-Content -LiteralPath $tempOutputPath -Value ($lines -join [Environment]::NewLine)
Move-Item -LiteralPath $tempOutputPath -Destination $OutputLuaPath -Force
Write-Host "Wrote static item catalog to $OutputLuaPath"
