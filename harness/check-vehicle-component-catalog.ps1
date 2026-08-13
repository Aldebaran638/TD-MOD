# Static and deterministic checker for the Gate 3.3 candidate catalog.

param([string]$Path = ".")

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath $Path).Path
$jsonPath = Join-Path $root "docs\generated\cm2-vehicle-definitions-v1.json"
$luaPath = Join-Path $root "docs\generated\cm2-vehicle-catalog-v1.lua"
$hashPath = Join-Path $root "docs\generated\cm2-vehicle-catalog-v1.sha256"
$builder = Join-Path $root "tools\cm2-vehicles\build-generated-vehicle-catalog.ps1"
$issues = New-Object System.Collections.Generic.List[string]
foreach ($required in @($jsonPath, $luaPath, $hashPath, $builder)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { [void]$issues.Add("missing catalog artifact: $required") }
}

if ($issues.Count -eq 0) {
    try { $data = Get-Content -Raw -LiteralPath $jsonPath | ConvertFrom-Json }
    catch { [void]$issues.Add("generated JSON is invalid: $($_.Exception.Message)") }
}

if ($issues.Count -eq 0) {
    if ([string]$data.schemaVersion -ne "cm2.vehicle-catalog/1" -or $data.generated -ne $true) { [void]$issues.Add("catalog schema/generated marker invalid") }
    if ([int]$data.vehicleCount -ne 5 -or @($data.vehicles).Count -ne 5) { [void]$issues.Add("catalog must contain 5 vehicles") }
    if ([int]$data.partCount -ne 5 -or @($data.parts).Count -ne 5) { [void]$issues.Add("catalog must contain one root part for each vehicle") }
    if ([int]$data.mountCount -lt 32 -or @($data.mounts).Count -ne [int]$data.mountCount) { [void]$issues.Add("mount count is incomplete or inconsistent") }
    if ([int]$data.componentCount -lt 26 -or @($data.components).Count -ne [int]$data.componentCount) { [void]$issues.Add("component count is incomplete or inconsistent") }
    if ([int]$data.interceptorCount -ne 3 -or @($data.interceptors).Count -ne 3) { [void]$issues.Add("catalog must contain 3 interceptors") }
    if ([int]$data.targetFilterCount -ne 2 -or @($data.targetFilters).Count -ne 2) { [void]$issues.Add("catalog must contain 2 target filters") }
    if (@($data.unresolved).Count -ne 0) { [void]$issues.Add("catalog unresolved list is not empty") }

    $vehicles = @{}
    $parts = @{}
    $mounts = @{}
    $components = @{}
    $interceptors = @{}
    $filters = @{}
    foreach ($vehicle in $data.vehicles) {
        $id = [string]$vehicle.id
        if ($vehicles.ContainsKey($id)) { [void]$issues.Add("duplicate vehicle ID: $id") } else { $vehicles[$id] = $vehicle }
        if ($id -notmatch '^cm2:vehicle/') { [void]$issues.Add("non-canonical vehicle ID: $id") }
        if ([string]$vehicle.schemaVersion -ne "cm2.vehicle/1" -or [string]$vehicle.kind -ne "vehicle") { [void]$issues.Add("vehicle schema/kind mismatch: $id") }
        $runtime = $vehicle.runtime
        foreach ($field in @("shieldHP", "armorHP", "bodyHP", "shieldRadiusM")) { if ($null -eq $runtime.health.PSObject.Properties[$field]) { [void]$issues.Add("vehicle health field missing: $id/$field") } }
        if ([string]$runtime.flight.coordinateFrame -notmatch 'parent-local') { [void]$issues.Add("vehicle coordinate frame is not parent-local: $id") }
        if ([string]$runtime.mountSetId -notmatch '^cm2:mount-set/') { [void]$issues.Add("vehicle mount set is not canonical: $id") }
        if ($null -ne $runtime.PSObject.Properties["mountProfile"]) { [void]$issues.Add("legacy mountProfile remains: $id") }
        if ([string]$runtime.controlMode -eq "player" -and @($runtime.configurations[0].slotGroups).Count -eq 0) { [void]$issues.Add("player vehicle has no slot groups: $id") }
    }
    foreach ($part in $data.parts) {
        $id = [string]$part.id
        if ($parts.ContainsKey($id)) { [void]$issues.Add("duplicate part ID: $id") } else { $parts[$id] = $part }
        if ($id -notmatch '^cm2:part/') { [void]$issues.Add("non-canonical part ID: $id") }
        if ([string]$part.schemaVersion -ne "cm2.part/1" -or [string]$part.kind -ne "part") { [void]$issues.Add("part schema/kind mismatch: $id") }
        if (-not $vehicles.ContainsKey([string]$part.parentId)) { [void]$issues.Add("part parent is unresolved: $id") }
        if ([string]$part.localTransform.space -ne "parent-local") { [void]$issues.Add("part transform is not parent-local: $id") }
    }
    foreach ($mount in $data.mounts) {
        $id = [string]$mount.id
        if ($mounts.ContainsKey($id)) { [void]$issues.Add("duplicate mount ID: $id") } else { $mounts[$id] = $mount }
        if ($id -notmatch '^cm2:mount/') { [void]$issues.Add("non-canonical mount ID: $id") }
        if ([string]$mount.schemaVersion -ne "cm2.mount/1" -or [string]$mount.kind -ne "mount") { [void]$issues.Add("mount schema/kind mismatch: $id") }
        if (-not $vehicles.ContainsKey([string]$mount.parentId)) { [void]$issues.Add("mount parent is unresolved: $id") }
        if ([string]$mount.localTransform.space -ne "parent-local" -or @($mount.localTransform.position).Count -ne 3) { [void]$issues.Add("mount transform is not canonical: $id") }
        if (@($mount.anchors).Count -lt 1) { [void]$issues.Add("mount has no anchors: $id") }
        if ($null -ne $mount.aliasOf -and -not $mounts.ContainsKey([string]$mount.aliasOf)) { [void]$issues.Add("mount alias is unresolved: $id") }
    }
    foreach ($component in $data.components) {
        $id = [string]$component.id
        if ($components.ContainsKey($id)) { [void]$issues.Add("duplicate component ID: $id") } else { $components[$id] = $component }
        if ($id -notmatch '^cm2:component/') { [void]$issues.Add("non-canonical component ID: $id") }
        if ([string]$component.schemaVersion -ne "cm2.component/1" -or [string]$component.kind -ne "component") { [void]$issues.Add("component schema/kind mismatch: $id") }
        if ([string]$component.runtime.componentId -ne $id) { [void]$issues.Add("component runtime ID mismatch: $id") }
        if ([string]$component.runtime.slotType -notin @("largeUtility", "auxiliary", "reactor", "thruster", "sensor")) { [void]$issues.Add("component slot type invalid: $id") }
        if ([string]$component.editor.englishName -eq "" -or [string]$component.editor.iconPath -eq "") { [void]$issues.Add("component editor metadata incomplete: $id") }
    }
    foreach ($filter in $data.targetFilters) {
        $id = [string]$filter.id
        if ($filters.ContainsKey($id)) { [void]$issues.Add("duplicate target filter ID: $id") } else { $filters[$id] = $filter }
        if ($id -notmatch '^cm2:target-filter/') { [void]$issues.Add("non-canonical target filter ID: $id") }
        if ([string]$filter.schemaVersion -ne "cm2.targetFilter/1") { [void]$issues.Add("target filter schema mismatch: $id") }
    }
    foreach ($interceptor in $data.interceptors) {
        $id = [string]$interceptor.id
        if ($interceptors.ContainsKey($id)) { [void]$issues.Add("duplicate interceptor ID: $id") } else { $interceptors[$id] = $interceptor }
        if ($id -notmatch '^cm2:interceptor/') { [void]$issues.Add("non-canonical interceptor ID: $id") }
        if ([string]$interceptor.schemaVersion -ne "cm2.interceptor/1" -or [string]$interceptor.kind -ne "interceptor") { [void]$issues.Add("interceptor schema/kind mismatch: $id") }
        if (-not $vehicles.ContainsKey([string]$interceptor.vehicleId)) { [void]$issues.Add("interceptor vehicle is unresolved: $id") }
        if ([string]$interceptor.runtime.class -notin @("strike_craft", "missile", "torpedo")) { [void]$issues.Add("interceptor class invalid: $id") }
        if (-not $filters.ContainsKey([string]$interceptor.runtime.targetFilterId)) { [void]$issues.Add("interceptor target filter is unresolved: $id") }
        foreach ($field in @("maxActive", "maxQueriesPerFrame", "maxGuidanceStepsPerFrame")) { if ([double]$interceptor.runtime.budget.$field -le 0) { [void]$issues.Add("interceptor budget invalid: $id/$field") } }
    }
    foreach ($vehicle in $data.vehicles) {
        $id = [string]$vehicle.id
        foreach ($mountId in @($vehicle.runtime.mountIds)) { if (-not $mounts.ContainsKey([string]$mountId)) { [void]$issues.Add("vehicle mount reference unresolved: $id -> $mountId") } }
        foreach ($partId in @($vehicle.runtime.partIds)) { if (-not $parts.ContainsKey([string]$partId)) { [void]$issues.Add("vehicle part reference unresolved: $id -> $partId") } }
        foreach ($componentId in @($vehicle.runtime.componentIds)) { if (-not $components.ContainsKey([string]$componentId)) { [void]$issues.Add("vehicle component reference unresolved: $id -> $componentId") } }
        if (-not $filters.ContainsKey([string]$vehicle.runtime.targetFilterId)) { [void]$issues.Add("vehicle target filter unresolved: $id") }
        if ($null -ne $vehicle.runtime.PSObject.Properties["interceptorId"] -and -not $interceptors.ContainsKey([string]$vehicle.runtime.interceptorId)) { [void]$issues.Add("vehicle interceptor reference unresolved: $id") }
        foreach ($loadout in @($vehicle.runtime.configurations)) { foreach ($property in $loadout.defaultLoadout.PSObject.Properties) { if ([string]$property.Value -notmatch '^cm2:weapon/') { [void]$issues.Add("vehicle default weapon reference is not canonical: $id/$($property.Name)") } } }
    }
    $expectedHash = (Get-Content -Raw -LiteralPath $hashPath).Trim().ToLowerInvariant()
    $actualHash = (Get-FileHash -LiteralPath $luaPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($expectedHash -ne $actualHash) { [void]$issues.Add("vehicle catalog Lua hash sidecar mismatch") }
    $tempDir = Join-Path ([IO.Path]::GetTempPath()) ("cm2-vehicles-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $builder -RepositoryRoot $root -OutputDirectory $tempDir 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { [void]$issues.Add("deterministic vehicle builder failed") }
    else {
        foreach ($name in @("cm2-vehicle-definitions-v1.json", "cm2-vehicle-catalog-v1.lua", "cm2-vehicle-catalog-v1.sha256")) {
            $left = (Get-FileHash -LiteralPath (Join-Path $root "docs\generated\$name") -Algorithm SHA256).Hash
            $right = (Get-FileHash -LiteralPath (Join-Path $tempDir $name) -Algorithm SHA256).Hash
            if ($left -ne $right) { [void]$issues.Add("vehicle catalog is not deterministic: $name") }
        }
    }
    if (Test-Path -LiteralPath $tempDir) { Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue }
}

if ($issues.Count -gt 0) { Write-Error ("Vehicle/component catalog check failed:`n - " + ($issues -join "`n - ")); exit 1 }
Write-Host "Vehicle/component catalog contract passed: 5 vehicles, 32 mounts, 26 components, 3 interceptors, canonical references and deterministic output." -ForegroundColor Green
exit 0
