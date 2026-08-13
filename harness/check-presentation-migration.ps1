# Static checker for the batched presentation migration ledger.

param([string]$Path = ".\Content Mod 2")

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath $Path).Path
$repositoryRoot = Split-Path -Parent $root
$manifestPath = Join-Path $repositoryRoot "docs\presentation-migration-batches.json"
$issues = New-Object System.Collections.Generic.List[string]
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { $issues.Add("missing presentation migration manifest") }
if ($issues.Count -eq 0) {
    $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
    if ([string]$manifest.schemaVersion -ne "cm2.presentation-migration/1") { $issues.Add("manifest schema version mismatch") }
    if (@($manifest.batches).Count -ne 4) { $issues.Add("manifest must contain four ordered batches") }
    $ids = @($manifest.batches | ForEach-Object { [string]$_.id })
    if (($ids | Sort-Object -Unique).Count -ne 4) { $issues.Add("batch IDs must be unique") }
    foreach ($batch in $manifest.batches) {
        foreach ($field in @("id", "scope", "owner", "rendererId", "rendererVersion", "declaredWorstCaseCost", "status", "eventSource", "fallback")) {
            if ($null -eq $batch.PSObject.Properties[$field] -or [string]$batch.$field -eq "") { $issues.Add("batch $($batch.id) missing $field") }
        }
        foreach ($cost in @("particles", "sprites", "lines", "lights", "voices")) {
            if ($null -eq $batch.declaredWorstCaseCost.PSObject.Properties[$cost]) { $issues.Add("batch $($batch.id) missing cost $cost") }
        }
        $scope = [string]$batch.scope
        $relativeRoot = $scope -replace '/\*\*$', ''
        if (-not (Test-Path -LiteralPath (Join-Path $root ($relativeRoot -replace '/', '\')) -PathType Container)) { $issues.Add("batch scope directory missing: $scope") }
    }
    if (@($manifest.batchOrder).Count -ne 4) { $issues.Add("batch order must cover all four batches") }
    if ([string]$manifest.eventSourceRule -notmatch 'never simultaneous') { $issues.Add("single event source rule missing") }

    $scopedRoots = @(
        (Join-Path $root "script\weapon\client\presentation"),
        (Join-Path $root "script\ship\common\client\effects")
    )
    $primitivePattern = '\b(SpawnParticle|PointLight|DrawSprite|DrawLine|PlaySound)\s*\('
    foreach ($scopeRoot in $scopedRoots) {
        if (-not (Test-Path -LiteralPath $scopeRoot -PathType Container)) { continue }
        Get-ChildItem -LiteralPath $scopeRoot -Recurse -Filter *.lua | ForEach-Object {
            $relative = $_.FullName.Substring($root.Length + 1).Replace('\', '/')
            $text = Get-Content -Raw -LiteralPath $_.FullName
            if ($text -cmatch $primitivePattern -and $_.Name -notin @("presentation_budget.lua", "effect_budget.lua")) {
                $matches = @($manifest.batches | Where-Object {
                    $prefixes = @(([string]$_.scope -replace '/\*\*$', ''))
                    $prefixes += @($_.additionalScopes | ForEach-Object { ([string]$_ -replace '/\*\*$', '') })
                    @($prefixes | Where-Object { $relative.StartsWith($_ + '/') }).Count -gt 0
                })
                if ($matches.Count -ne 1) { $issues.Add("direct primitive has no unique migration batch: $relative") }
            }
        }
    }
    $destroyed = Get-Content -Raw -LiteralPath (Join-Path $root "script\ship\common\client\effects\ship_destroyed_fx.lua")
    $thruster = Get-Content -Raw -LiteralPath (Join-Path $root "script\ship\common\client\effects\engine_thruster_fx.lua")
    $sound = Get-Content -Raw -LiteralPath (Join-Path $root "script\weapon\client\presentation\audio\sound_service.lua")
    foreach ($text in @($destroyed, $thruster, $sound)) {
        if ($text -cmatch $primitivePattern) { $issues.Add("facade-migrated high-risk file still directly calls primitive") }
        if ($text -notmatch 'presentationBudget\.') { $issues.Add("high-risk file is not facade-backed") }
    }
}
if ($issues.Count -gt 0) { Write-Error ("Presentation migration check failed:`n - " + ($issues -join "`n - ")); exit 1 }
Write-Host "Presentation migration contract passed: four batches, scoped renderer ownership, single event source and facade-backed high-risk effects." -ForegroundColor Green
exit 0
