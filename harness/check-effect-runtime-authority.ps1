# Static contract checker for Effect Runtime authority cutover.

param([string]$Path = ".\Content Mod 2")

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath $Path).Path
$repositoryRoot = Split-Path -Parent $root
$module = Join-Path $root "script\net\effect_runtime_authority.lua"
$fixture = Join-Path $repositoryRoot "harness\data\presentation\effect-runtime-authority-fixtures.json"
$docs = Join-Path $repositoryRoot "docs\effect-runtime-cutover-v1.md"
$issues = New-Object System.Collections.Generic.List[string]
if (-not (Test-Path -LiteralPath $module -PathType Leaf)) { $issues.Add("missing authority module") }
if (-not (Test-Path -LiteralPath $fixture -PathType Leaf)) { $issues.Add("missing authority fixture") }
if (-not (Test-Path -LiteralPath $docs -PathType Leaf)) { $issues.Add("missing cutover documentation") }
if ($issues.Count -eq 0) {
    $source = Get-Content -Raw -LiteralPath $module
    foreach ($symbol in @("init", "isLegacy", "isEventV1", "recordLegacyAdapterCall", "recordCandidateCall", "getReport")) {
        if ($source -notmatch "function authority\.$symbol\b") { $issues.Add("missing authority API: $symbol") }
    }
    foreach ($token in @("legacyDispatchEnabled", "candidateDispatchEnabled", "dualPlaybackRejected", "effectRuntime")) {
        if ($source -notmatch [regex]::Escape($token)) { $issues.Add("authority token missing: $token") }
    }
    if ($source -notmatch 'selected\s*~=\s*"legacy"\s*and\s*selected\s*~=\s*"event-v1"') { $issues.Add("invalid mode fallback missing") }
    $data = Get-Content -Raw -LiteralPath $fixture | ConvertFrom-Json
    if (@($data.modes).Count -ne 2 -or [string]$data.dualPlayback -ne "reject-and-count") { $issues.Add("authority fixture is incomplete") }
    $client = Get-Content -Raw -LiteralPath (Join-Path $root "script\client.lua")
    if ($client -notmatch 'cm2EffectRuntimeAuthority\.init\(\)') { $issues.Add("client authority init missing") }
    $ship = Get-Content -Raw -LiteralPath (Join-Path $root "script\shipMain.lua")
    if ($ship -notmatch 'cm2EffectRuntimeAuthority\.init\(\)') { $issues.Add("ship authority init missing") }
    $dispatch = Get-Content -Raw -LiteralPath (Join-Path $root "script\weapon\client\presentation\visual\runtime\registry\effect_dispatch.lua")
    if ($dispatch -match 'function client\.weaponFxTickAll[\s\S]*?weaponFxBudgetBeginFrame') { $issues.Add("duplicate budget owner remains") }
}
if ($issues.Count -gt 0) { Write-Error ("Effect Runtime authority check failed:`n - " + ($issues -join "`n - ")); exit 1 }
Write-Host "Effect Runtime authority contract passed: legacy/event-v1 mutual exclusion, init gates, first-batch cleanup and rollback fixture." -ForegroundColor Green
exit 0
