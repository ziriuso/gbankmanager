[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PackagePath,
    [Parameter(Mandatory = $true)]
    [string]$TagName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($TagName -notmatch '^forever-v(?<version>\d+\.\d+\.\d+(?:-[0-9A-Za-z\.\-]+)?)$') {
    throw "Tag '$TagName' is not a Forever version tag."
}
$version = $Matches.version
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$package = (Resolve-Path -LiteralPath $PackagePath).Path

$sources = @(
    @{ Path = (Join-Path $repoRoot "GBankManager"); Folder = "GBankManager" },
    @{ Path = (Join-Path $repoRoot "Forever\GBankManager_ItemData"); Folder = "GBankManager_ItemData" }
)
$expected = [System.Collections.Generic.Dictionary[string, string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($source in $sources) {
    foreach ($file in Get-ChildItem -LiteralPath $source.Path -Recurse -File) {
        $relative = [System.IO.Path]::GetRelativePath($source.Path, $file.FullName).Replace('\', '/')
        $expected.Add("$($source.Folder)/$relative", $file.FullName)
    }
}

Add-Type -AssemblyName System.IO.Compression
$zip = [System.IO.Compression.ZipFile]::OpenRead($package)
$sha = [System.Security.Cryptography.SHA256]::Create()
try {
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $tocText = @{}
    foreach ($entry in $zip.Entries) {
        if ($entry.FullName.EndsWith('/')) {
            continue
        }
        $name = $entry.FullName.Replace('\', '/')
        if (-not $expected.ContainsKey($name) -or -not $seen.Add($name)) {
            throw "Unexpected or duplicate package file '$name'."
        }

        $stream = $entry.Open()
        try {
            if ($name -eq "GBankManager/GBankManager.toc" -or $name -eq "GBankManager_ItemData/GBankManager_ItemData.toc") {
                $reader = [System.IO.StreamReader]::new($stream)
                $tocText[$name] = $reader.ReadToEnd()
                if ($name -eq "GBankManager_ItemData/GBankManager_ItemData.toc" -and
                    $tocText[$name] -ne [System.IO.File]::ReadAllText($expected[$name])) {
                    throw "Package item data TOC differs from Forever source."
                }
            } else {
                $actualHash = [Convert]::ToHexString($sha.ComputeHash($stream))
                $sourceHash = (Get-FileHash -LiteralPath $expected[$name] -Algorithm SHA256).Hash
                if ($actualHash -ne $sourceHash) {
                    throw "Package file differs from Forever source: $name."
                }
            }
        } finally {
            $stream.Dispose()
        }
    }

    if ($seen.Count -ne $expected.Count) {
        $missing = @($expected.Keys | Where-Object { -not $seen.Contains($_) })
        throw "Forever package is missing $($missing.Count) files: $($missing -join ', ')."
    }

    $mainToc = $tocText["GBankManager/GBankManager.toc"]
    $dataToc = $tocText["GBankManager_ItemData/GBankManager_ItemData.toc"]
    if ($mainToc -notmatch '(?m)^## Interface: 16001\r?$' -or $dataToc -notmatch '(?m)^## Interface: 16001\r?$') {
        throw "Both packaged TOCs must target only Forever interface 16001."
    }
    if ($mainToc -notmatch "(?m)^## Version: $([regex]::Escape($version))\r?$" -or
        $mainToc -notmatch "(?m)^## X-Release-Tag: $([regex]::Escape($TagName))\r?$") {
        throw "The packaged main TOC does not match $TagName."
    }

    [pscustomobject]@{
        package = $package
        target = "Forever"
        tag = $TagName
        files = $seen.Count
        itemDataFiles = @($seen | Where-Object { $_.StartsWith('GBankManager_ItemData/') }).Count
    } | ConvertTo-Json -Compress
} finally {
    $sha.Dispose()
    $zip.Dispose()
}
