param(
    [Parameter()]
    [ValidateSet("Retail", "PTR", "Beta", "Forever")]
    [string]$Target = "Retail",

    [Parameter()]
    [string]$WoWRoot,

    [Parameter()]
    [string]$ClientDirectory,

    [Parameter()]
    [string]$Locale = "en_US",

    [Parameter()]
    [string]$AddOnsDirectory,

    [Parameter()]
    [string]$MainAddonPath,

    [Parameter()]
    [string]$ItemDataAddonPath,

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

function Resolve-RepoRoot {
    return Get-AbsolutePath -Path (Join-Path $PSScriptRoot "..\..")
}

function Resolve-SourcePath {
    param(
        [string]$ExplicitPath,
        [string]$DefaultName
    )

    if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
        return Get-AbsolutePath -Path $ExplicitPath
    }

    return Get-AbsolutePath -Path (Join-Path (Resolve-RepoRoot) $DefaultName)
}

$resolvedTarget = Resolve-MaintainerTarget
$resolvedAddOnsDirectory = if (-not [string]::IsNullOrWhiteSpace($AddOnsDirectory)) {
    Get-AbsolutePath -Path $AddOnsDirectory
} else {
    Get-AbsolutePath -Path (Join-Path $resolvedTarget.clientDirectory "Interface\AddOns")
}

$mainAddonSource = Resolve-SourcePath -ExplicitPath $MainAddonPath -DefaultName "GBankManager"
$defaultItemDataPath = if ($Target -eq "Forever") { "Forever\GBankManager_ItemData" } else { "GBankManager_ItemData" }
$itemDataAddonSource = Resolve-SourcePath -ExplicitPath $ItemDataAddonPath -DefaultName $defaultItemDataPath

if (-not (Test-Path -LiteralPath $mainAddonSource)) {
    throw ("Main addon source path does not exist: {0}" -f $mainAddonSource)
}
if (-not (Test-Path -LiteralPath $itemDataAddonSource)) {
    throw ("Item-data addon source path does not exist: {0}" -f $itemDataAddonSource)
}

New-Item -ItemType Directory -Force -Path $resolvedAddOnsDirectory | Out-Null
Copy-Item -LiteralPath $mainAddonSource -Destination $resolvedAddOnsDirectory -Recurse -Force
Copy-Item -LiteralPath $itemDataAddonSource -Destination $resolvedAddOnsDirectory -Recurse -Force

$result = [pscustomobject]@{
    status = "deployed"
    target = [string]$resolvedTarget.target
    wowRoot = [string]$resolvedTarget.wowRoot
    clientDirectory = [string]$resolvedTarget.clientDirectory
    addOnsDirectory = $resolvedAddOnsDirectory
    deployedAddons = @("GBankManager", "GBankManager_ItemData")
    deployedPaths = @(
        (Get-AbsolutePath -Path (Join-Path $resolvedAddOnsDirectory "GBankManager")),
        (Get-AbsolutePath -Path (Join-Path $resolvedAddOnsDirectory "GBankManager_ItemData"))
    )
}

if ($Json) {
    $result | ConvertTo-Json -Depth 6 -Compress
    return
}

$result
