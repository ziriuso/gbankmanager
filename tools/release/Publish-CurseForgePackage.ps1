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
    [string]$GameVersionIds = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-TocInterfaceVersion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    foreach ($line in Get-Content -Path $Path) {
        if ($line -match '^## Interface:\s*(\d{6})(?:\s*,\s*\d{6})*\s*$') {
            return $Matches[1]
        }
    }

    throw "Failed to find ## Interface in TOC '$Path'."
}

function Convert-InterfaceToVersionName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Interface
    )

    if ($Interface -notmatch '^\d{6}$') {
        throw "Interface '$Interface' must be a six-digit retail interface value."
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

    if (-not [string]::IsNullOrWhiteSpace($ConfiguredIds)) {
        return ($ConfiguredIds -split '[,\s]+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { [int]$_ })
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
        throw "Could not resolve a CurseForge game version id for interface $InterfaceValue (version $versionName). Set CF_GAME_VERSION_IDS as a repository variable to override automatic resolution."
    }

    return @($matches | ForEach-Object { [int]$_.id })
}

$resolvedFilePath = [System.IO.Path]::GetFullPath($FilePath)
if (-not (Test-Path $resolvedFilePath)) {
    throw "Package file '$resolvedFilePath' does not exist."
}

$resolvedTocPath = [System.IO.Path]::GetFullPath($TocPath)
$interfaceValue = Get-TocInterfaceVersion -Path $resolvedTocPath
$versionIds = Resolve-GameVersionIds -Token $ApiToken -InterfaceValue $interfaceValue -ConfiguredIds $GameVersionIds

$display = if ([string]::IsNullOrWhiteSpace($DisplayName)) { "GBankManager $TagName" } else { $DisplayName }
$metadata = @{
    changelog = "Automated $ReleaseType build for $TagName. See the matching GitHub Release for full notes."
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
