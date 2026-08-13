# Gate 3.5 manifest, generated-header/hash and ownership checker.

param([string]$Path = ".")

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath $Path).Path
$manifestPath = Join-Path $root "docs\generated\cm2-generated-catalog-manifest-v1.json"
$luaPath = Join-Path $root "docs\generated\cm2-generated-catalog-v1.lua"
$hashPath = Join-Path $root "docs\generated\cm2-generated-catalog-v1.sha256"
$builder = Join-Path $root "tools\cm2-compiler\build-generated-catalog-manifest-v1.ps1"
$issues = New-Object System.Collections.Generic.List[string]
foreach ($required in @($manifestPath, $luaPath, $hashPath, $builder)) { if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { [void]$issues.Add("missing generated manifest artifact: $required") } }

if ($issues.Count -eq 0) {
    try { $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json }
    catch { [void]$issues.Add("manifest JSON is invalid: $($_.Exception.Message)") }
}
if ($issues.Count -eq 0) {
    if ([string]$manifest.schemaVersion -ne "cm2.generated-catalog-manifest/1" -or $manifest.generated -ne $true) { [void]$issues.Add("manifest schema/generated marker invalid") }
    if (@($manifest.catalogs).Count -ne 2) { [void]$issues.Add("manifest must contain weapon and vehicle catalogs") }
    if ([int]$manifest.references.unresolvedCount -ne 0) { [void]$issues.Add("manifest reports unresolved references") }
    if ([string]$manifest.ownership.runtimePolicy -ne "legacy-active" -or [string]$manifest.ownership.mode -ne "shadow" -or $manifest.ownership.promotionAllowed -ne $false) { [void]$issues.Add("runtime ownership is not an explicit legacy-safe shadow gate") }
    if ([string]$manifest.entryClosure.status -ne "required-pass" -or @($manifest.entryClosure.entries).Count -lt 2) { [void]$issues.Add("entry closure evidence is incomplete") }
    if ([string]$manifest.effectProfiles.schemaVersion -ne "cm2.effect-profile-source/1" -or [int]$manifest.effectProfiles.profileCount -lt 108 -or [int]$manifest.effectProfiles.unresolvedCount -ne 0) { [void]$issues.Add("effect profile source is incomplete in the manifest") }
    $manifestLuaHash = (Get-FileHash -LiteralPath $luaPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $sidecarHash = ((Get-Content -Raw -LiteralPath $hashPath).Trim() -split '\s+')[0].ToLowerInvariant()
    if ($manifestLuaHash -ne $sidecarHash -or [string]$manifest.buildOutput.outputHash -ne $manifestLuaHash) { [void]$issues.Add("aggregate Lua hash/manifest outputHash mismatch") }
    $lua = Get-Content -Raw -LiteralPath $luaPath
    if ($lua -notmatch '^-- CM2 GENERATED FILE; DO NOT EDIT\.' -or $lua -notmatch 'runtimePolicy = "legacy-active"' -or $lua -notmatch 'mode = "shadow"' -or $lua -notmatch 'promotionAllowed = false') { [void]$issues.Add("aggregate Lua generated header or shadow gate is missing") }
    foreach ($catalog in $manifest.catalogs) {
        $jsonPath = Join-Path $root ([string]$catalog.jsonPath -replace '/', '\')
        $catalogLuaPath = Join-Path $root ([string]$catalog.luaPath -replace '/', '\')
        $catalogHashPath = Join-Path $root ([string]$catalog.hashPath -replace '/', '\')
        foreach ($pathToCheck in @($jsonPath, $catalogLuaPath, $catalogHashPath)) { if (-not (Test-Path -LiteralPath $pathToCheck -PathType Leaf)) { [void]$issues.Add("manifest catalog path missing: $pathToCheck") } }
        if (Test-Path -LiteralPath $catalogLuaPath -PathType Leaf) {
            if ((Get-Content -Raw -LiteralPath $catalogLuaPath) -notmatch '^-- CM2 GENERATED FILE; DO NOT EDIT\.') { [void]$issues.Add("catalog generated header missing: $($catalog.kind)") }
            if ([string]$catalog.luaSha256 -ne (Get-FileHash -LiteralPath $catalogLuaPath -Algorithm SHA256).Hash.ToLowerInvariant()) { [void]$issues.Add("catalog hash mismatch: $($catalog.kind)") }
        }
        if (Test-Path -LiteralPath $jsonPath -PathType Leaf) {
            $catalogJson = Get-Content -Raw -LiteralPath $jsonPath | ConvertFrom-Json
            if ([int]$catalog.unresolvedCount -ne 0 -or @($catalogJson.unresolved).Count -ne 0) { [void]$issues.Add("catalog unresolved references: $($catalog.kind)") }
            if ([int]$catalog.definitionCount -le 0) { [void]$issues.Add("catalog definition count is empty: $($catalog.kind)") }
            if ([string]$catalog.ownership -ne "generated-candidate-only") { [void]$issues.Add("catalog ownership is not candidate-only: $($catalog.kind)") }
        }
    }
    foreach ($entry in @($manifest.entryClosure.entries)) {
        if (-not (Test-Path -LiteralPath (Join-Path $root ([string]$entry -replace '/', '\')) -PathType Leaf)) { [void]$issues.Add("manifest entry missing: $entry") }
    }
    $included = & rg -n --fixed-strings "cm2-generated-catalog-v1.lua" (Join-Path $root "Content Mod 2\script") 2>$null
    if ($LASTEXITCODE -eq 0 -and $included) { [void]$issues.Add("candidate aggregate catalog is included before promotion gate") }
    $tempDir = Join-Path ([IO.Path]::GetTempPath()) ("cm2-manifest-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $builder -RepositoryRoot $root -OutputDirectory $tempDir 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { [void]$issues.Add("manifest builder failed during determinism check") }
    else {
        foreach ($name in @("cm2-generated-catalog-manifest-v1.json", "cm2-generated-catalog-v1.lua", "cm2-generated-catalog-v1.sha256")) {
            $left = (Get-FileHash -LiteralPath (Join-Path $root "docs\generated\$name") -Algorithm SHA256).Hash
            $right = (Get-FileHash -LiteralPath (Join-Path $tempDir $name) -Algorithm SHA256).Hash
            if ($left -ne $right) { [void]$issues.Add("generated manifest is stale/non-deterministic: $name") }
        }
    }
    if (Test-Path -LiteralPath $tempDir) { Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue }
}
if ($issues.Count -gt 0) { Write-Error ("Generated catalog manifest check failed:`n - " + ($issues -join "`n - ")); exit 1 }
Write-Host "Generated catalog manifest contract passed: headers, hashes, manifest, entry references, namespace/reference gate and legacy-safe shadow ownership are consistent." -ForegroundColor Green
exit 0
