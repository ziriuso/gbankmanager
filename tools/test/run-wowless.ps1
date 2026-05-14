param(
    [string]$CompanionRepoRoot = "",
    [string]$AddonRoot = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$siblingParent = Split-Path -Parent $repoRoot
if ((Split-Path -Leaf $siblingParent) -eq ".worktrees") {
    $siblingParent = Split-Path -Parent (Split-Path -Parent $siblingParent)
}

if ([string]::IsNullOrWhiteSpace($AddonRoot)) {
    try {
        $gitRoot = git -C $repoRoot rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitRoot)) {
            $AddonRoot = $gitRoot.Trim()
        } else {
            $AddonRoot = $repoRoot
        }
    } catch {
        $AddonRoot = $repoRoot
    }
}

if ([string]::IsNullOrWhiteSpace($CompanionRepoRoot)) {
    $CompanionRepoRoot = Join-Path $siblingParent "GBankManager-wowless-smoke"
}

$script = Join-Path $CompanionRepoRoot "scripts\run-smoke.ps1"
if (-not (Test-Path $script)) {
    throw "Wowless companion repo not found. Expected script at $script"
}

$hostExecutable = if (Get-Command "pwsh" -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
& $hostExecutable -ExecutionPolicy Bypass -File $script -AddonRoot $AddonRoot
exit $LASTEXITCODE
