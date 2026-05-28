param(
    [string]$InputJsonPath = ".\\tools\\catalog\\runtime\\item-catalog-input.json",
    [string]$OutputLuaPath = ".\\GBankManager_ItemData\\Data.lua",
    [int]$ItemChunkSize = 1000,
    [int]$TokenChunkSize = 500
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function ConvertTo-LuaString {
    param([AllowNull()][string]$Value)

    if ($null -eq $Value) {
        return "nil"
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

function Normalize-Text {
    param([AllowNull()][string]$Value)

    $normalized = [string]$Value
    $normalized = $normalized.ToLowerInvariant()
    $normalized = [System.Text.RegularExpressions.Regex]::Replace($normalized, "[^\p{L}\p{Nd}]+", " ")
    $normalized = [System.Text.RegularExpressions.Regex]::Replace($normalized, "\s+", " ").Trim()
    return $normalized
}

function Normalize-Token {
    param([AllowNull()][string]$Token)

    $normalized = [string]$Token
    if ($normalized.Length -gt 3 -and $normalized.EndsWith("s") -and (-not $normalized.EndsWith("ss"))) {
        $normalized = $normalized.Substring(0, $normalized.Length - 1)
    }
    return $normalized
}

function Get-SearchTokens {
    param([AllowNull()][string]$Value)

    $normalized = Normalize-Text -Value $Value
    if ([string]::IsNullOrWhiteSpace($normalized)) {
        return @()
    }

    $tokens = New-Object System.Collections.Generic.List[string]
    foreach ($token in $normalized.Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries)) {
        $normalizedToken = Normalize-Token -Token $token
        if (-not [string]::IsNullOrWhiteSpace($normalizedToken)) {
            $tokens.Add($normalizedToken)
        }
    }

    return @($tokens)
}

function Get-ChunkFileName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prefix,

        [Parameter(Mandatory = $true)]
        [int]$Index
    )

    return "{0}_{1:D3}.lua" -f $Prefix, $Index
}

function Write-AtomicContent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [System.Collections.IEnumerable]$Lines
    )

    $directory = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($directory) -and (-not (Test-Path -LiteralPath $directory))) {
        New-Item -ItemType Directory -Path $directory | Out-Null
    }

    $tempPath = "{0}.tmp" -f $Path
    $contentLines = @()
    foreach ($line in $Lines) {
        $contentLines += [string]$line
    }
    Set-Content -LiteralPath $tempPath -Value ($contentLines -join [Environment]::NewLine)
    Move-Item -LiteralPath $tempPath -Destination $Path -Force
}

function Add-WrappedIntegerArray {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Lines,

        [Parameter(Mandatory = $true)]
        [int[]]$Values,

        [string]$Indent = "            ",

        [int]$WrapSize = 24
    )

    if ($Values.Count -eq 0) {
        return
    }

    for ($offset = 0; $offset -lt $Values.Count; $offset += $WrapSize) {
        $count = [Math]::Min($WrapSize, $Values.Count - $offset)
        $segment = New-Object int[] $count
        [Array]::Copy($Values, $offset, $segment, 0, $count)
        $formattedLine = "{0}{1}," -f $Indent, (($segment | ForEach-Object { [string]$_ }) -join ", ")
        $Lines.Add($formattedLine)
    }
}

function Write-DataLuaShim {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("local _, ns = ...")
    $lines.Add("")
    $lines.Add("ns = _G.GBankManagerNamespace or ns or {}")
    $lines.Add("ns.data = ns.data or {}")
    $lines.Add("ns.modules = ns.modules or {}")
    $lines.Add("")
    $lines.Add("return ns.data.staticItemCatalog or ns.modules.staticItemCatalog or ns")
    Write-AtomicContent -Path $Path -Lines $lines
}

function Copy-AddonSupportFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RelativeSourcePath,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )

    $sourcePath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ("..\..\GBankManager_ItemData\" + $RelativeSourcePath)))
    if (-not (Test-Path -LiteralPath $sourcePath)) {
        throw "Search bootstrap source not found: $sourcePath"
    }

    $destinationFullPath = [System.IO.Path]::GetFullPath($DestinationPath)
    if ($sourcePath -eq $destinationFullPath) {
        return
    }

    $bootstrapLines = Get-Content -LiteralPath $sourcePath
    Write-AtomicContent -Path $destinationFullPath -Lines $bootstrapLines
}

function Write-ItemChunkFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [object[]]$ChunkItems
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("local _, ns = ...")
    $lines.Add("")
    $lines.Add("ns = _G.GBankManagerNamespace or ns or {}")
    $lines.Add("local bootstrap = ((ns.data or {}).staticItemSearchBootstrap)")
    $lines.Add('if type(bootstrap) ~= "table" or type(bootstrap.AppendItemChunk) ~= "function" then')
    $lines.Add("    return")
    $lines.Add("end")
    $lines.Add("")
    $lines.Add("bootstrap.AppendItemChunk({")

    foreach ($item in $ChunkItems) {
        $itemID = [int](Get-FastPropertyValue -Object $item -Name "itemID")
        $resolvedName = [string](Get-FastPropertyValue -Object $item -Name "name")
        if ([string]::IsNullOrWhiteSpace($resolvedName)) {
            $resolvedName = "Item $itemID"
        }

        $recordFields = New-Object System.Collections.Generic.List[string]
        $recordFields.Add("itemID = $itemID")
        $recordFields.Add("name = $(ConvertTo-LuaString $resolvedName)")

        $itemLinkValue = Get-FastPropertyValue -Object $item -Name "itemLink"
        if ($null -ne $itemLinkValue) {
            $recordFields.Add("itemLink = $(ConvertTo-LuaString ([string]$itemLinkValue))")
        }

        $itemStringValue = Get-FastPropertyValue -Object $item -Name "itemString"
        if ($null -ne $itemStringValue) {
            $recordFields.Add("itemString = $(ConvertTo-LuaString ([string]$itemStringValue))")
        }

        $qualityValue = Get-FastPropertyValue -Object $item -Name "quality"
        if ($null -ne $qualityValue) {
            $recordFields.Add("quality = $([int]$qualityValue)")
        }

        $qualityNameValue = Get-FastPropertyValue -Object $item -Name "qualityName"
        if ($null -ne $qualityNameValue) {
            $recordFields.Add("qualityName = $(ConvertTo-LuaString ([string]$qualityNameValue))")
        }

        $craftedQualityValue = Get-FastPropertyValue -Object $item -Name "craftedQuality"
        if ($null -ne $craftedQualityValue) {
            $recordFields.Add("craftedQuality = $([int]$craftedQualityValue)")
        }

        $craftedQualityIconValue = Get-FastPropertyValue -Object $item -Name "craftedQualityIcon"
        if ($null -ne $craftedQualityIconValue) {
            $recordFields.Add("craftedQualityIcon = $(ConvertTo-LuaString ([string]$craftedQualityIconValue))")
        }

        $craftedQualityMaxValue = Get-FastPropertyValue -Object $item -Name "craftedQualityMax"
        if ($null -ne $craftedQualityMaxValue) {
            $recordFields.Add("craftedQualityMax = $([int]$craftedQualityMaxValue)")
        }

        $craftedQualityDisplayAtlasValue = Get-FastPropertyValue -Object $item -Name "craftedQualityDisplayAtlas"
        $craftedQualityPreferredAtlasValue = Get-FastPropertyValue -Object $item -Name "craftedQualityPreferredAtlas"
        $craftedQualityFamilySizeValue = Get-FastPropertyValue -Object $item -Name "craftedQualityFamilySize"
        if ($null -ne $craftedQualityDisplayAtlasValue) {
            $recordFields.Add("craftedQualityDisplayAtlas = $(ConvertTo-LuaString ([string]$craftedQualityDisplayAtlasValue))")
        }
        if ($null -ne $craftedQualityPreferredAtlasValue) {
            $recordFields.Add("craftedQualityPreferredAtlas = $(ConvertTo-LuaString ([string]$craftedQualityPreferredAtlasValue))")
        }
        if ($null -ne $craftedQualityFamilySizeValue) {
            $recordFields.Add("craftedQualityFamilySize = $([int]$craftedQualityFamilySizeValue)")
        }

        $lines.Add("    { $($recordFields -join ', ') },")
    }

    $lines.Add("})")
    Write-AtomicContent -Path $Path -Lines $lines
}

function Write-TokenChunkFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [System.Collections.DictionaryEntry[]]$TokenEntries
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("local _, ns = ...")
    $lines.Add("")
    $lines.Add("ns = _G.GBankManagerNamespace or ns or {}")
    $lines.Add("local bootstrap = ((ns.data or {}).staticItemSearchBootstrap)")
    $lines.Add('if type(bootstrap) ~= "table" or type(bootstrap.AppendTokenChunk) ~= "function" then')
    $lines.Add("    return")
    $lines.Add("end")
    $lines.Add("")
    $lines.Add("bootstrap.AppendTokenChunk({")

    foreach ($entry in $TokenEntries) {
        $token = [string]$entry.Key
        $ids = @($entry.Value)
        $lines.Add("    [$(ConvertTo-LuaString $token)] = {")
        Add-WrappedIntegerArray -Lines $lines -Values ([int[]]$ids)
        $lines.Add("    },")
    }

    $lines.Add("})")
    Write-AtomicContent -Path $Path -Lines $lines
}

function Write-FinalizeChunkFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Source,

        [Parameter(Mandatory = $true)]
        [string]$GeneratedAt,

        [Parameter(Mandatory = $true)]
        [int]$ItemCount,

        [Parameter(Mandatory = $true)]
        [int]$TokenCount
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("local _, ns = ...")
    $lines.Add("")
    $lines.Add("ns = _G.GBankManagerNamespace or ns or {}")
    $lines.Add("local bootstrap = ((ns.data or {}).staticItemSearchBootstrap)")
    $lines.Add('if type(bootstrap) ~= "table" or type(bootstrap.Finalize) ~= "function" then')
    $lines.Add("    return")
    $lines.Add("end")
    $lines.Add("")
    $lines.Add("bootstrap.Finalize({")
    $lines.Add("    source = $(ConvertTo-LuaString $Source),")
    $lines.Add("    generatedAt = $(ConvertTo-LuaString $GeneratedAt),")
    $lines.Add("    itemCount = $ItemCount,")
    $lines.Add("    tokenCount = $TokenCount,")
    $lines.Add("})")
    Write-AtomicContent -Path $Path -Lines $lines
}

function Write-IndexedToc {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string[]]$GeneratedFiles
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("## Interface: 120005")
    $lines.Add("## Title: GBankManager Item Data")
    $lines.Add("## Notes: Bundled item search data for GBankManager")
    $lines.Add("## Author: ziriuso")
    $lines.Add("")
    $lines.Add("Namespace.lua")
    $lines.Add("SearchBootstrap.lua")
    foreach ($file in $GeneratedFiles) {
        $lines.Add($file.Replace("\", "/"))
    }
    Write-AtomicContent -Path $Path -Lines $lines
}

if (-not (Test-Path -LiteralPath $InputJsonPath)) {
    throw "Input manifest not found: $InputJsonPath"
}

$input = Get-Content -LiteralPath $InputJsonPath -Raw | ConvertFrom-Json
$manifestItems = @($input.items)
$items = @($manifestItems | Where-Object {
    [string](Get-FastPropertyValue -Object $_ -Name "status") -ne "deprecated"
})
Apply-CraftedQualityDisplayFields -Items $items
$generatedAt = if ($input.generatedAt) { [string]$input.generatedAt } else { (Get-Date).ToString("yyyy-MM-dd") }
$source = if ($input.source) { [string]$input.source } else { "manual_manifest" }

$outputShimPath = [System.IO.Path]::GetFullPath($OutputLuaPath)
$addonDirectory = Split-Path -Parent $outputShimPath
$tocPath = Join-Path $addonDirectory "GBankManager_ItemData.toc"
$namespacePath = Join-Path $addonDirectory "Namespace.lua"
$searchBootstrapPath = Join-Path $addonDirectory "SearchBootstrap.lua"
$generatedDirectory = Join-Path $addonDirectory "Generated"

if (Test-Path -LiteralPath $generatedDirectory) {
    Remove-Item -LiteralPath $generatedDirectory -Recurse -Force
}
New-Item -ItemType Directory -Path $generatedDirectory | Out-Null

$tokenIndex = @{}
foreach ($item in $items) {
    $itemID = [int](Get-FastPropertyValue -Object $item -Name "itemID")
    $tokens = Get-SearchTokens -Value ([string](Get-FastPropertyValue -Object $item -Name "name"))
    $seenTokens = @{}
    foreach ($token in $tokens) {
        if ($seenTokens.ContainsKey($token)) {
            continue
        }
        $seenTokens[$token] = $true
        if (-not $tokenIndex.ContainsKey($token)) {
            $tokenIndex[$token] = New-Object System.Collections.Generic.List[int]
        }
        $tokenIndex[$token].Add($itemID)
    }
}

$generatedRelativeFiles = New-Object System.Collections.Generic.List[string]
$itemChunkCount = 0
for ($offset = 0; $offset -lt $items.Count; $offset += $ItemChunkSize) {
    $count = [Math]::Min($ItemChunkSize, $items.Count - $offset)
    $chunkItems = New-Object object[] $count
    [Array]::Copy($items, $offset, $chunkItems, 0, $count)
    $itemChunkCount += 1
    $fileName = Get-ChunkFileName -Prefix "Items" -Index $itemChunkCount
    $relativePath = Join-Path "Generated" $fileName
    $generatedRelativeFiles.Add($relativePath.Replace("\", "/"))
    Write-ItemChunkFile -Path (Join-Path $generatedDirectory $fileName) -ChunkItems $chunkItems
}

$sortedTokens = @($tokenIndex.GetEnumerator() | Sort-Object Key)
$tokenChunkCount = 0
for ($offset = 0; $offset -lt $sortedTokens.Count; $offset += $TokenChunkSize) {
    $count = [Math]::Min($TokenChunkSize, $sortedTokens.Count - $offset)
    $chunkEntries = New-Object System.Collections.Generic.List[System.Collections.DictionaryEntry]
    for ($index = 0; $index -lt $count; $index += 1) {
        $chunkEntries.Add([System.Collections.DictionaryEntry]$sortedTokens[$offset + $index])
    }
    $tokenChunkCount += 1
    $fileName = Get-ChunkFileName -Prefix "Tokens" -Index $tokenChunkCount
    $relativePath = Join-Path "Generated" $fileName
    $generatedRelativeFiles.Add($relativePath.Replace("\", "/"))
    Write-TokenChunkFile -Path (Join-Path $generatedDirectory $fileName) -TokenEntries @($chunkEntries)
}

$finalizeRelativePath = "Generated/Finalize.lua"
$generatedRelativeFiles.Add($finalizeRelativePath)
Write-FinalizeChunkFile `
    -Path (Join-Path $generatedDirectory "Finalize.lua") `
    -Source $source `
    -GeneratedAt $generatedAt `
    -ItemCount $items.Count `
    -TokenCount $sortedTokens.Count

Copy-AddonSupportFile -RelativeSourcePath "Namespace.lua" -DestinationPath $namespacePath
Copy-AddonSupportFile -RelativeSourcePath "SearchBootstrap.lua" -DestinationPath $searchBootstrapPath
Write-IndexedToc -Path $tocPath -GeneratedFiles @($generatedRelativeFiles)
Write-DataLuaShim -Path $outputShimPath

[pscustomobject]@{
    status = "exported"
    outputLuaPath = $outputShimPath
    tocPath = [System.IO.Path]::GetFullPath($tocPath)
    namespacePath = [System.IO.Path]::GetFullPath($namespacePath)
    searchBootstrapPath = [System.IO.Path]::GetFullPath($searchBootstrapPath)
    generatedDirectory = [System.IO.Path]::GetFullPath($generatedDirectory)
    itemCount = $items.Count
    tokenCount = $sortedTokens.Count
    itemChunkCount = $itemChunkCount
    tokenChunkCount = $tokenChunkCount
    generatedFileCount = $generatedRelativeFiles.Count + 1
    generatedAt = $generatedAt
    source = $source
}
