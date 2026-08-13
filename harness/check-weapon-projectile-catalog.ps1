# Static/deterministic checker for the candidate Weapon + Projectile Catalog v1.

param([string]$Path = ".")

$ErrorActionPreference = "Stop"
$repositoryRoot = (Resolve-Path -LiteralPath $Path).Path
$jsonPath = Join-Path $repositoryRoot "docs\generated\cm2-weapon-definitions-v1.json"
$luaPath = Join-Path $repositoryRoot "docs\generated\cm2-weapon-catalog-v1.lua"
$hashPath = Join-Path $repositoryRoot "docs\generated\cm2-weapon-catalog-v1.sha256"
$builder = Join-Path $repositoryRoot "tools\cm2-weapons\build-generated-weapon-catalog.ps1"
$issues = New-Object System.Collections.Generic.List[string]
foreach ($required in @($jsonPath, $luaPath, $hashPath, $builder)) { if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { $issues.Add("missing catalog artifact: $required") } }
if ($issues.Count -eq 0) {
    $data = Get-Content -Raw -LiteralPath $jsonPath | ConvertFrom-Json
    if ([string]$data.schemaVersion -ne "cm2.weapon-catalog/1" -or $data.generated -ne $true) { $issues.Add("catalog schema/generated marker invalid") }
    if ([int]$data.weaponCount -ne 109 -or @($data.weapons).Count -ne 109) { $issues.Add("catalog must contain 109 weapons") }
    if ([int]$data.projectileCount -ne @($data.projectiles).Count -or [int]$data.projectileCount -lt 1) { $issues.Add("projectile count mismatch") }
    if (@($data.unresolved).Count -ne 0) { $issues.Add("catalog unresolved list is not empty") }
    $ids = @($data.weapons | ForEach-Object {[string]$_.id})
    if (($ids | Sort-Object -Unique).Count -ne 109) { $issues.Add("weapon IDs are not unique") }
    foreach ($weapon in $data.weapons) {
        if ([string]$weapon.id -notmatch '^cm2:weapon/') { $issues.Add("weapon ID is not namespaced: $($weapon.id)") }
        if ([string]$weapon.schemaVersion -ne "cm2.weapon/1") { $issues.Add("weapon schema mismatch: $($weapon.id)") }
        if ($null -ne $weapon.PSObject.Properties["mountProfile"]) { $issues.Add("legacy mountProfile remains: $($weapon.id)") }
        if (@($weapon.capabilityTags).Count -lt 2) { $issues.Add("capability tags incomplete: $($weapon.id)") }
        if ($null -ne $weapon.PSObject.Properties["effects"] -and $null -ne $weapon.effects) {
            foreach ($effectProperty in $weapon.effects.PSObject.Properties) {
                if ($null -ne $effectProperty.Value -and [string]$effectProperty.Value -notmatch '^cm2:') {
                    $issues.Add("non-canonical reference: $($weapon.id)/effects/$($effectProperty.Name)")
                }
            }
        }
        if ($null -ne $weapon.PSObject.Properties["sound"] -and $null -ne $weapon.sound -and [string]$weapon.sound -notmatch '^cm2:') {
            $issues.Add("non-canonical reference: $($weapon.id)/sound")
        }
    }
    foreach ($projectile in $data.projectiles) {
        foreach ($field in @("id", "schemaVersion", "simulationMode", "speed", "lifetime", "radius", "guidance", "collision", "network", "budget")) {
            if ($null -eq $projectile.PSObject.Properties[$field]) { $issues.Add("projectile missing ${field}: $($projectile.id)") }
        }
        if ([string]$projectile.schemaVersion -ne "cm2.projectile/1") { $issues.Add("projectile schema mismatch: $($projectile.id)") }
    }
    $expectedHash = (Get-Content -Raw -LiteralPath $hashPath).Trim().ToLowerInvariant()
    $actualHash = (Get-FileHash -LiteralPath $luaPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($expectedHash -ne $actualHash) { $issues.Add("catalog Lua hash sidecar mismatch") }
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("cm2-weapons-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $builder -RepositoryRoot $repositoryRoot -OutputDirectory $tempDir 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { $issues.Add("deterministic weapon builder failed") }
    else {
        foreach ($name in @("cm2-weapon-definitions-v1.json", "cm2-weapon-catalog-v1.lua", "cm2-weapon-catalog-v1.sha256")) {
            if ((Get-FileHash -LiteralPath (Join-Path $repositoryRoot "docs\generated\$name") -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath (Join-Path $tempDir $name) -Algorithm SHA256).Hash) { $issues.Add("catalog is not deterministic: $name") }
        }
    }
    if (Test-Path -LiteralPath $tempDir) { Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue }
}
if ($issues.Count -gt 0) { Write-Error ("Weapon/projectile catalog check failed:`n - " + ($issues -join "`n - ")); exit 1 }
Write-Host "Weapon/projectile catalog contract passed: 109 weapons, 75 projectiles, canonical refs, no mountProfile, deterministic output." -ForegroundColor Green
exit 0
