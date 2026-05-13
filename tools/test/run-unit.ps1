Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$lua = Join-Path $repoRoot "tools\lua\lua.exe"
$script = Join-Path $repoRoot "tests\run_unit.lua"

& $lua $script
exit $LASTEXITCODE
