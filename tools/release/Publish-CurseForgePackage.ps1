[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectId,
    [Parameter(Mandatory = $true)]
    [string]$ApiToken,
    [Parameter(Mandatory = $true)]
    [string]$FilePath,
    [Parameter(Mandatory = $true)]
    [ValidateSet("alpha", "beta", "release")]
    [string]$ReleaseType,
    [Parameter(Mandatory = $true)]
    [string]$TagName,
    [string]$DisplayName,
    [string]$TocPath = ".\GBankManager\GBankManager.toc",
    [string]$GameVersionIds = "",
    [ValidateSet("Retail", "Forever")]
    [string]$Target = "Retail"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-TocInterfaceVersion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$ReleaseTarget
    )

    foreach ($line in Get-Content -Path $Path) {
        if ($ReleaseTarget -eq "Forever" -and $line -match '^## Interface:\s*(?:\d{5,6}\s*,\s*)*(16001)(?:\s*,\s*\d{5,6})*\s*$') {
            return $Matches[1]
        }
        if ($line -match '^## Interface:\s*(\d{6})(?:\s*,\s*\d{5,6})*\s*$') {
            if ($ReleaseTarget -eq "Retail") {
                return $Matches[1]
            }
        }
    }

    throw "Failed to find ## Interface in TOC '$Path'."
}

function Convert-InterfaceToVersionName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Interface
    )

    if ($Interface -match '^\d{5}$') {
        return "$([int]$Interface.Substring(0, 1)).$([int]$Interface.Substring(1, 2)).$([int]$Interface.Substring(3, 2))"
    }
    if ($Interface -notmatch '^\d{6}$') {
        throw "Interface '$Interface' must be a supported Retail or Forever interface value."
    }

    $major = [int]$Interface.Substring(0, 2)
    $minor = [int]$Interface.Substring(2, 2)
    $patch = [int]$Interface.Substring(4, 2)
    return "$major.$minor.$patch"
}

function Resolve-GameVersionIds {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Token,
        [Parameter(Mandatory = $true)]
        [string]$InterfaceValue,
        [string]$ConfiguredIds = ""
    )

    $overrideName = if ($InterfaceValue -eq "16001") { "CF_FOREVER_GAME_VERSION_IDS" } else { "CF_GAME_VERSION_IDS" }
    if (-not [string]::IsNullOrWhiteSpace($ConfiguredIds)) {
        $ids = @($ConfiguredIds -split '[,\s]+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { [int]$_ })
        if ($InterfaceValue -eq "16001" -and $ids.Count -ne 1) {
            throw "Forever must be tagged with exactly one CurseForge game version id in $overrideName."
        }
        return $ids
    }

    $versionName = Convert-InterfaceToVersionName -Interface $InterfaceValue
    $headers = @{
        "X-Api-Token" = $Token
    }

    $response = Invoke-RestMethod -Method Get -Uri "https://wow.curseforge.com/api/game/versions" -Headers $headers
    $versions = @($response)
    if ($response -is [System.Collections.IDictionary] -and $response.Contains("data")) {
        $versions = @($response.data)
    }

    $matches = @(
        $versions | Where-Object {
            ($_.name -as [string]) -eq $versionName
        }
    )

    if ($matches.Count -eq 0) {
        throw "Could not resolve a CurseForge game version id for interface $InterfaceValue (version $versionName). Set $overrideName as a repository variable to override automatic resolution."
    }
    if ($InterfaceValue -eq "16001" -and $matches.Count -ne 1) {
        throw "Forever version $versionName matched $($matches.Count) CurseForge game versions; set one $overrideName id."
    }

    return @($matches | ForEach-Object { [int]$_.id })
}

$resolvedFilePath = [System.IO.Path]::GetFullPath($FilePath)
if ($Target -eq "Forever" -and $TagName -notmatch '^forever-v\d+\.\d+\.\d+(?:-[0-9A-Za-z\.\-]+)?$') {
    throw "Forever uploads require a Forever version tag."
}
if (-not (Test-Path $resolvedFilePath)) {
    throw "Package file '$resolvedFilePath' does not exist."
}

$resolvedTocPath = [System.IO.Path]::GetFullPath($TocPath)
$interfaceValue = Get-TocInterfaceVersion -Path $resolvedTocPath -ReleaseTarget $Target
$versionIds = Resolve-GameVersionIds -Token $ApiToken -InterfaceValue $interfaceValue -ConfiguredIds $GameVersionIds

$display = if ([string]::IsNullOrWhiteSpace($DisplayName)) { "GBankManager $TagName" } else { $DisplayName }
$changelog = if ($Target -eq "Forever") {
    "First WoW Forever 1.60.1 build: dedicated Forever item database, Classic auction categories, quality-independent item search and displays, and guild-bank balance and Money Log scans without purchased tabs."
} else {
    "Automated $ReleaseType build for $TagName. See the matching GitHub Release for full notes."
}
$metadata = @{
    changelog = $changelog
    changelogType = "markdown"
    displayName = $display
    gameVersions = [object[]]@($versionIds)
    releaseType = $ReleaseType
}

$headers = @{
    "X-Api-Token" = $ApiToken
}

$response = Invoke-RestMethod -Method Post -Uri "https://wow.curseforge.com/api/projects/$ProjectId/upload-file" -Headers $headers -Form @{
    metadata = ($metadata | ConvertTo-Json -Compress -Depth 8)
    file = Get-Item $resolvedFilePath
}

$response | ConvertTo-Json -Depth 8
