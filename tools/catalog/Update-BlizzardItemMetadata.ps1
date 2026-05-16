param(
    [string]$ManifestPath = ".\\tools\\catalog\\runtime\\item-catalog-input.json",
    [string]$Region = "us",
    [string]$Namespace = "static-us",
    [string]$Locale = "en_US",
    [int]$Limit = 200,
    [switch]$BuildAddonData
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-EnvOrThrow {
    param([string]$Name)

    $value = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "Missing required environment variable: $Name"
    }

    return $value
}

function ConvertTo-BasicAuthHeader {
    param(
        [string]$ClientId,
        [string]$ClientSecret
    )

    $bytes = [Text.Encoding]::ASCII.GetBytes("$ClientId`:$ClientSecret")
    return "Basic " + [Convert]::ToBase64String($bytes)
}

function Get-ManifestObject {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Manifest not found: $Path"
    }

    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Set-ManifestObject {
    param(
        [string]$Path,
        [object]$Manifest
    )

    $Manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path
}

$clientId = Get-EnvOrThrow "GBM_BNET_CLIENT_ID"
$clientSecret = Get-EnvOrThrow "GBM_BNET_CLIENT_SECRET"
$authHeader = ConvertTo-BasicAuthHeader -ClientId $clientId -ClientSecret $clientSecret
$tokenResponse = Invoke-RestMethod -Method Post -Uri "https://oauth.battle.net/token" -Headers @{
    Authorization = $authHeader
} -Body @{
    grant_type = "client_credentials"
}

$accessToken = [string]$tokenResponse.access_token
if ([string]::IsNullOrWhiteSpace($accessToken)) {
    throw "Failed to acquire Battle.net access token."
}

$manifest = Get-ManifestObject -Path $ManifestPath
$items = @($manifest.items)
$updatedCount = 0

foreach ($item in $items) {
    if ($updatedCount -ge $Limit) {
        break
    }

    $status = [string]$item.status
    if ($status -eq "confirmed") {
        continue
    }

    $itemID = [int]$item.itemID
    $itemUrl = "https://${Region}.api.blizzard.com/data/wow/item/${itemID}?namespace=$Namespace&locale=$Locale&access_token=$accessToken"
    try {
        $response = Invoke-RestMethod -Method Get -Uri $itemUrl
        $item.name = [string]$response.name
        if ($response.quality) {
            $item.quality = $response.quality.type
            $item.qualityName = $response.quality.name
        }
        $item.status = "confirmed"
        $item.source = "blizzard_item_api"
        $item.lastVerifiedAt = (Get-Date).ToString("yyyy-MM-dd")
        $item.unresolved = $false
        $updatedCount += 1
    }
    catch {
        if (-not $item.name) {
            $item.name = "Item $itemID"
        }
        if (-not $item.status) {
            $item.status = "unresolved"
        }
    }
}

$manifest.generatedAt = (Get-Date).ToString("yyyy-MM-dd")
$manifest.itemCount = @($items).Count
$manifest.unresolvedCount = (@($items | Where-Object { [string]$_.status -ne "confirmed" })).Count
Set-ManifestObject -Path $ManifestPath -Manifest $manifest
Write-Host "Updated manifest metadata for $updatedCount item(s)."

if ($BuildAddonData) {
    $buildScript = Join-Path $PSScriptRoot "Build-ItemDataAddon.ps1"
    & $buildScript -ManifestPath $ManifestPath
}
