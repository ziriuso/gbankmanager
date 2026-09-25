[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TagName,
    [ValidateSet("Retail", "Forever")]
    [string]$Target = "Retail",
    [string]$OutputDirectory = ".\artifacts\release"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-ReleaseMetadata {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Tag,
        [Parameter(Mandatory = $true)]
        [string]$ReleaseTarget
    )

    $prefix = if ($ReleaseTarget -eq "Forever") { "forever-v" } else { "v" }
    if (-not ($Tag -match "^$prefix(?<version>\d+\.\d+\.\d+(?:-[0-9A-Za-z\.\-]+)?)$")) {
        throw "Tag '$Tag' must start with '$prefix' and contain a semantic version for $ReleaseTarget."
    }

    $version = $Matches.version
    $normalized = $version.ToLowerInvariant()
    $releaseType = "release"
    if ($normalized.Contains("-alpha")) {
        $releaseType = "alpha"
    } elseif ($normalized.Contains("-beta")) {
        $releaseType = "beta"
    }

    [pscustomobject]@{
        Version = $version
        ReleaseType = $releaseType
        IsPrerelease = ($releaseType -ne "release")
        FileName = if ($ReleaseTarget -eq "Forever") { "GBankManager-Forever-$version.zip" } else { "GBankManager-$version.zip" }
        ReleaseName = if ($ReleaseTarget -eq "Forever") { "GBankManager Forever v$version" } else { "GBankManager $Tag" }
    }
}

function Set-GitHubOutputs {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Values
    )

    if (-not $env:GITHUB_OUTPUT) {
        return
    }

    foreach ($entry in $Values.GetEnumerator()) {
        "$($entry.Key)=$($entry.Value)" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
    }
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$metadata = Get-ReleaseMetadata -Tag $TagName -ReleaseTarget $Target

$resolvedOutputDirectory = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $OutputDirectory))
$stagingRoot = Join-Path $resolvedOutputDirectory "staging"
$packageRoot = Join-Path $stagingRoot "package"
$packagePath = Join-Path $resolvedOutputDirectory $metadata.FileName

New-Item -ItemType Directory -Force -Path $resolvedOutputDirectory | Out-Null
if (Test-Path $stagingRoot) {
    Remove-Item -Recurse -Force $stagingRoot
}
New-Item -ItemType Directory -Force -Path $packageRoot | Out-Null

$addonSources = @(
    @{ Source = "GBankManager"; Destination = "GBankManager" },
    @{ Source = $(if ($Target -eq "Forever") { "Forever/GBankManager_ItemData" } else { "GBankManager_ItemData" }); Destination = "GBankManager_ItemData" }
)

foreach ($addon in $addonSources) {
    $sourcePath = Join-Path $repoRoot $addon.Source
    if (-not (Test-Path $sourcePath)) {
        throw "Required addon folder '$($addon.Source)' was not found under $repoRoot."
    }

    Copy-Item -Recurse -Force -Path $sourcePath -Destination (Join-Path $packageRoot $addon.Destination)
}

if ($Target -eq "Forever") {
    $tocPath = Join-Path $packageRoot "GBankManager/GBankManager.toc"
    $toc = [System.IO.File]::ReadAllText($tocPath)
    if ($toc -notmatch '(?m)^## Interface:[^\r\n]*') {
        throw "Missing main addon interface in $tocPath."
    }
    $toc = $toc -replace '(?m)^## Interface:[^\r\n]*', '## Interface: 16001'
    $toc = $toc -replace '(?m)^## Version:[^\r\n]*', "## Version: $($metadata.Version)"
    $toc = $toc -replace '(?m)^## X-Release-Tag:[^\r\n]*', "## X-Release-Tag: $TagName"
    [System.IO.File]::WriteAllText($tocPath, $toc, [System.Text.UTF8Encoding]::new($false))
}

if (Test-Path $packagePath) {
    Remove-Item -Force $packagePath
}

Compress-Archive -Path (Join-Path $packageRoot "*") -DestinationPath $packagePath -CompressionLevel Optimal

$result = [pscustomobject]@{
    tag = $TagName
    target = $Target
    version = $metadata.Version
    releaseType = $metadata.ReleaseType
    isPrerelease = $metadata.IsPrerelease
    releaseName = $metadata.ReleaseName
    packageName = $metadata.FileName
    packagePath = $packagePath
}

Set-GitHubOutputs -Values @{
    version = $result.version
    release_type = $result.releaseType
    is_prerelease = $result.isPrerelease.ToString().ToLowerInvariant()
    release_name = $result.releaseName
    package_name = $result.packageName
    package_path = $result.packagePath
}

$result | ConvertTo-Json -Depth 4
