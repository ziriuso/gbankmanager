param(
    [Parameter()]
    [ValidateSet("Retail", "PTR", "Beta")]
    [string]$Target = "Retail",

    [Parameter()]
    [string]$WoWRoot,

    [Parameter()]
    [string]$ClientDirectory,

    [Parameter()]
    [string]$Locale = "en_US",

    [Parameter()]
    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-TargetDefinition {
    param([string]$Name)

    $definitions = @{
        Retail = [pscustomobject]@{
            Target = "Retail"
            Product = "wow"
            ClientFolder = "_retail_"
        }
        PTR = [pscustomobject]@{
            Target = "PTR"
            Product = "wowt"
            ClientFolder = "_ptr_"
        }
        Beta = [pscustomobject]@{
            Target = "Beta"
            Product = "wow_beta"
            ClientFolder = "_beta_"
        }
    }

    return $definitions[$Name]
}

function Get-DefaultWoWRoots {
    $candidates = New-Object System.Collections.Generic.List[string]
    $maybeAdd = {
        param([string]$Path)

        if ([string]::IsNullOrWhiteSpace($Path)) {
            return
        }

        if (-not $candidates.Contains($Path)) {
            $candidates.Add($Path)
        }
    }

    $envCandidates = [Environment]::GetEnvironmentVariable("GBM_WOW_DEFAULT_ROOTS")
    if (-not [string]::IsNullOrWhiteSpace($envCandidates)) {
        foreach ($candidate in ($envCandidates -split ";")) {
            & $maybeAdd $candidate
        }
    }

    $disableFallbackRoots = [Environment]::GetEnvironmentVariable("GBM_WOW_DISABLE_FALLBACK_ROOTS")
    if ($disableFallbackRoots -ne "1") {
        if (-not [string]::IsNullOrWhiteSpace(${env:ProgramFiles(x86)})) {
            & $maybeAdd (Join-Path ${env:ProgramFiles(x86)} "World of Warcraft")
        }

        if (-not [string]::IsNullOrWhiteSpace($env:ProgramFiles)) {
            & $maybeAdd (Join-Path $env:ProgramFiles "World of Warcraft")
        }

        & $maybeAdd "C:\Gaming\World of Warcraft"
        & $maybeAdd "C:\Games\World of Warcraft"
        & $maybeAdd "D:\Games\World of Warcraft"
        & $maybeAdd "E:\Games\World of Warcraft"
    }

    return $candidates.ToArray()
}

function Resolve-InstallRoot {
    param(
        [string]$RequestedRoot,
        [string]$ClientFolder
    )

    if (-not [string]::IsNullOrWhiteSpace($RequestedRoot)) {
        return [pscustomobject]@{
            WoWRoot = [System.IO.Path]::GetFullPath($RequestedRoot)
            Source = "override"
        }
    }

    foreach ($candidate in Get-DefaultWoWRoots) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath (Join-Path $candidate $ClientFolder))) {
            return [pscustomobject]@{
                WoWRoot = [System.IO.Path]::GetFullPath($candidate)
                Source = "detected"
            }
        }
    }

    throw "Unable to locate a World of Warcraft install for target '$ClientFolder'. Pass -WoWRoot or set GBM_WOW_DEFAULT_ROOTS."
}

function Resolve-ClientDirectory {
    param(
        [string]$RequestedClientDirectory,
        [pscustomobject]$InstallRoot,
        [pscustomobject]$TargetDefinition
    )

    if (-not [string]::IsNullOrWhiteSpace($RequestedClientDirectory)) {
        return [pscustomobject]@{
            ClientDirectory = [System.IO.Path]::GetFullPath($RequestedClientDirectory)
            WoWRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $RequestedClientDirectory))
            InstallRootSource = "client-override"
        }
    }

    return [pscustomobject]@{
        ClientDirectory = [System.IO.Path]::GetFullPath((Join-Path $InstallRoot.WoWRoot $TargetDefinition.ClientFolder))
        WoWRoot = $InstallRoot.WoWRoot
        InstallRootSource = $InstallRoot.Source
    }
}

$targetDefinition = Get-TargetDefinition -Name $Target
if ($null -eq $targetDefinition) {
    throw "Unsupported target: $Target"
}

$installRoot = Resolve-InstallRoot -RequestedRoot $WoWRoot -ClientFolder $targetDefinition.ClientFolder
$clientResolution = Resolve-ClientDirectory -RequestedClientDirectory $ClientDirectory -InstallRoot $installRoot -TargetDefinition $targetDefinition

$result = [pscustomobject]@{
    target = $targetDefinition.Target
    product = $targetDefinition.Product
    locale = $Locale
    wowRoot = $clientResolution.WoWRoot
    clientDirectory = $clientResolution.ClientDirectory
    dataDirectory = Join-Path $clientResolution.ClientDirectory "Data"
    localeDirectory = Join-Path $clientResolution.ClientDirectory (Join-Path "Data" $Locale)
    installRootSource = $clientResolution.InstallRootSource
}

if ($Json) {
    $result | ConvertTo-Json -Depth 4 -Compress
    return
}

$result
