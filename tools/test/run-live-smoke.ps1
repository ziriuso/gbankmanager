Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$guide = Join-Path $repoRoot "docs\testing.md"

Write-Host "Live retail smoke is an explicit post-pass step."
Write-Host "Follow the smoke recipe in $guide after unit, UI, and integration lanes are green."
