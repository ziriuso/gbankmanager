Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$guide = Join-Path $repoRoot "docs\testing.md"

Write-Host "Live retail smoke is an explicit post-pass step."
Write-Host "After unit, UI, and integration are green, launch Retail and run: /gbm test smoke"
Write-Host "If a smoke check fails, review the persisted result in GBankManagerDB.testing.liveSmoke."
Write-Host "Full smoke recipe: $guide"
