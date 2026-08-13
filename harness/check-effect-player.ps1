# Static contract checker for EffectPlayer v1.

param([string]$Path = ".\Content Mod 2")

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath $Path).Path
$module = Join-Path $root "script\weapon\client\presentation\effect_player.lua"
$fixture = Join-Path (Split-Path -Parent $root) "harness\data\presentation\effect-player-fixtures.json"
$issues = New-Object System.Collections.Generic.List[string]
if (-not (Test-Path -LiteralPath $module -PathType Leaf)) { $issues.Add("missing EffectPlayer module") }
if (-not (Test-Path -LiteralPath $fixture -PathType Leaf)) { $issues.Add("missing EffectPlayer fixture") }
if ($issues.Count -eq 0) {
    $source = Get-Content -Raw -LiteralPath $module
    foreach ($symbol in @("play", "update", "stop", "destroy", "updateAll", "sceneReload", "getDiagnostics")) {
        if ($source -notmatch "function player\.$symbol\b") { $issues.Add("missing EffectPlayer API: $symbol") }
    }
    foreach ($field in @("effect", "owner", "anchor", "clock", "seed", "lod", "priority", "renderer")) {
        if ($source -notmatch "\b$field\s*=") { $issues.Add("instance field missing: $field") }
    }
    foreach ($token in @("generations", "activeIndices", "free", "densePosition", "ownerLost", "anchorLost", "acquireResource")) {
        if ($source -notmatch [regex]::Escape($token)) { $issues.Add("lifecycle/storage contract missing: $token") }
    }
    if ($source -notmatch 'invariant\s*=\s*state\.activeCount\s*\+\s*#state\.free\s*==\s*state\.capacity') { $issues.Add("active/free invariant missing") }
    if ($source -match 'CreateEntity|ECS|for each particle') { $issues.Add("EffectPlayer must not create a generic ECS entity") }
    $data = Get-Content -Raw -LiteralPath $fixture | ConvertFrom-Json
    if ([int]$data.capacity -ne 128 -or [int]$data.criticalBurst -ne 100) { $issues.Add("fixture capacity/burst does not match contract") }
    foreach ($operation in @("play", "update", "fade", "stop", "destroy", "owner-lost", "scene-reload")) {
        if (@($data.operations) -notcontains $operation) { $issues.Add("fixture missing operation: $operation") }
    }
}
if ($issues.Count -gt 0) { Write-Error ("EffectPlayer check failed:`n - " + ($issues -join "`n - ")); exit 1 }
Write-Host "EffectPlayer contract passed: generation handles, dense/free storage, lifecycle and invariant fixture." -ForegroundColor Green
exit 0
