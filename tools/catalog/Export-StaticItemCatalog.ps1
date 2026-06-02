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

function Set-FastPropertyValue {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Object,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        $Value
    )

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
        return
    }

    $property.Value = $Value
}

function Normalize-FamilyName {
    param([AllowNull()][string]$Value)

    return ([string]$Value).Trim().ToLowerInvariant()
}

function Get-CraftedQualityDisplayAtlas {
    param(
        [int]$CraftedQuality,
        [int]$CraftedQualityMax,
        [AllowNull()][string]$FallbackIcon
    )

    if ($CraftedQuality -lt 1) {
        return $null
    }

    if ($CraftedQualityMax -eq 2) {
        if ($CraftedQuality -eq 1) {
            return "Professions-ChatIcon-Quality-Tier1"
        }
        if ($CraftedQuality -eq 2) {
            return "Interface-Crafting-ReagentQuality-2-Med"
        }
    }

    if ($CraftedQualityMax -ge 3) {
        return "Professions-ChatIcon-Quality-Tier$CraftedQuality"
    }

    if (-not [string]::IsNullOrWhiteSpace($FallbackIcon)) {
        return [string]$FallbackIcon
    }

    return "Professions-ChatIcon-Quality-Tier$CraftedQuality"
}

function Apply-CraftedQualityDisplayFields {
    param([object[]]$Items)

    $tiersByFamily = @{}
    foreach ($item in @($Items)) {
        $familyName = Normalize-FamilyName -Value ([string](Get-FastPropertyValue -Object $item -Name "name"))
        $tier = Get-FastPropertyValue -Object $item -Name "craftedQuality"
        $tier = if ($null -ne $tier) { [int]$tier } else { 0 }
        if (-not [string]::IsNullOrWhiteSpace($familyName) -and $tier -ge 1 -and $tier -le 5) {
            if (-not $tiersByFamily.ContainsKey($familyName)) {
                $tiersByFamily[$familyName] = @{}
            }
            $tiersByFamily[$familyName][$tier] = $true
        }
    }

    foreach ($item in @($Items)) {
        $familyName = Normalize-FamilyName -Value ([string](Get-FastPropertyValue -Object $item -Name "name"))
        $tier = Get-FastPropertyValue -Object $item -Name "craftedQuality"
        $tier = if ($null -ne $tier) { [int]$tier } else { 0 }
        if ($tier -lt 1) {
            continue
        }

        $familyTiers = if ($tiersByFamily.ContainsKey($familyName)) { $tiersByFamily[$familyName] } else { @{} }
        $distinctCount = 0
        $maxTier = 0
        foreach ($candidateTier in 1..5) {
            if ($familyTiers.ContainsKey($candidateTier)) {
                $distinctCount += 1
                $maxTier = $candidateTier
            }
        }

        $craftedQualityMax = Get-FastPropertyValue -Object $item -Name "craftedQualityMax"
        $craftedQualityMax = if ($null -ne $craftedQualityMax) { [int]$craftedQualityMax } else { 0 }
        if ($craftedQualityMax -le 0) {
            if ($maxTier -ge 3) {
                $craftedQualityMax = 5
            } elseif ($distinctCount -eq 2 -and $familyTiers.ContainsKey(1) -and $familyTiers.ContainsKey(2)) {
                $craftedQualityMax = 2
            } elseif ($maxTier -gt 0) {
                $craftedQualityMax = $maxTier
            }
        }

        $fallbackIcon = [string](Get-FastPropertyValue -Object $item -Name "craftedQualityIcon")
        Set-FastPropertyValue -Object $item -Name "craftedQualityMax" -Value $craftedQualityMax
        $displayAtlas = Get-CraftedQualityDisplayAtlas -CraftedQuality $tier -CraftedQualityMax $craftedQualityMax -FallbackIcon $fallbackIcon
        Set-FastPropertyValue -Object $item -Name "craftedQualityDisplayAtlas" -Value $displayAtlas
        Set-FastPropertyValue -Object $item -Name "craftedQualityPreferredAtlas" -Value $displayAtlas
        Set-FastPropertyValue -Object $item -Name "craftedQualityFamilySize" -Value $craftedQualityMax
    }
}

if (-not (Test-Path -LiteralPath $InputJsonPath)) {
    throw "Input manifest not found: $InputJsonPath"
}

$input = Get-Content -LiteralPath $InputJsonPath -Raw | ConvertFrom-Json
$items = @($input.items | Where-Object {
    [string](Get-FastPropertyValue -Object $_ -Name "status") -ne "deprecated"
})
Apply-CraftedQualityDisplayFields -Items $items
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
    $craftedQualityMaxValue = Get-FastPropertyValue -Object $item -Name "craftedQualityMax"
    $craftedQualityDisplayAtlasValue = Get-FastPropertyValue -Object $item -Name "craftedQualityDisplayAtlas"
    $craftedQualityPreferredAtlasValue = Get-FastPropertyValue -Object $item -Name "craftedQualityPreferredAtlas"
    $craftedQualityFamilySizeValue = Get-FastPropertyValue -Object $item -Name "craftedQualityFamilySize"
    $quality = if ($null -ne $qualityValue) { [int]$qualityValue } else { $null }
    $qualityName = if ($null -ne $qualityNameValue) { ConvertTo-LuaString ([string]$qualityNameValue) } else { 'nil' }
    $craftedQuality = if ($null -ne $craftedQualityValue) { [int]$craftedQualityValue } else { $null }
    $craftedQualityIcon = if ($null -ne $craftedQualityIconValue) { ConvertTo-LuaString ([string]$craftedQualityIconValue) } else { 'nil' }
    $craftedQualityMax = if ($null -ne $craftedQualityMaxValue) { [int]$craftedQualityMaxValue } else { $null }
    $craftedQualityDisplayAtlas = if ($null -ne $craftedQualityDisplayAtlasValue) { ConvertTo-LuaString ([string]$craftedQualityDisplayAtlasValue) } else { 'nil' }
    $craftedQualityPreferredAtlas = if ($null -ne $craftedQualityPreferredAtlasValue) { ConvertTo-LuaString ([string]$craftedQualityPreferredAtlasValue) } else { 'nil' }
    $craftedQualityFamilySize = if ($null -ne $craftedQualityFamilySizeValue) { [int]$craftedQualityFamilySizeValue } else { $null }
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
    if ($null -ne $craftedQualityMax) {
        $recordFields.Add("craftedQualityMax = $craftedQualityMax")
    }
    if ($craftedQualityDisplayAtlas -ne 'nil') {
        $recordFields.Add("craftedQualityDisplayAtlas = $craftedQualityDisplayAtlas")
    }
    if ($craftedQualityPreferredAtlas -ne 'nil') {
        $recordFields.Add("craftedQualityPreferredAtlas = $craftedQualityPreferredAtlas")
    }
    if ($null -ne $craftedQualityFamilySize) {
        $recordFields.Add("craftedQualityFamilySize = $craftedQualityFamilySize")
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
