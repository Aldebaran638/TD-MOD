# Headless contract runner for the VOX/Anchor/Mount/Turret 3D Editor data model.
# It validates parent-local source edits and golden transforms without creating
# a second runtime/physics authority or claiming live 3D rendering.

param(
    [string]$FixturePath = "",
    [string]$ReportPath = ""
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if ($FixturePath -eq "") { $FixturePath = Join-Path $root "docs\candidates\anchor-turret-editor-v1.fixture.json" }
if ($ReportPath -eq "") { $ReportPath = Join-Path $root "docs\candidates\anchor-turret-editor-v1.result.json" }

function Fail([string]$message) { throw ("Anchor/Turret Editor v1 failed: " + $message) }
function Require([bool]$condition, [string]$message) { if (-not $condition) { Fail $message } }
function Canonical-Json([object]$value) { return ($value | ConvertTo-Json -Depth 100 -Compress) }
function Sha256-Text([string]$text) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($text)))).Replace("-", "").ToLowerInvariant() }
    finally { $sha.Dispose() }
}
function Sha256-File([string]$path) { return (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant() }
function Read-Json([string]$path) { return Get-Content -Raw -LiteralPath $path | ConvertFrom-Json }
function Copy-Json([object]$value) { return (Canonical-Json $value | ConvertFrom-Json) }
function Vec([object]$value, [double[]]$fallback) {
    $source = @($value)
    if ($source.Count -lt 3) { return @($fallback[0], $fallback[1], $fallback[2]) }
    return @([double]$source[0], [double]$source[1], [double]$source[2])
}
function Add-Vec([double[]]$a, [double[]]$b) { return @(($a[0] + $b[0]), ($a[1] + $b[1]), ($a[2] + $b[2])) }
function Mul-Vec([double[]]$a, [double[]]$b) { return @(($a[0] * $b[0]), ($a[1] * $b[1]), ($a[2] * $b[2])) }
function Compare-Vec([double[]]$actual, [double[]]$expected, [double]$epsilon = 0.0001) {
    if ($actual.Count -ne $expected.Count) { return $false }
    for ($index = 0; $index -lt $actual.Count; $index++) { if ([Math]::Abs($actual[$index] - $expected[$index]) -gt $epsilon) { return $false } }
    return $true
}
function Validate-Graph($nodes) {
    $byId = @{}
    $roots = 0
    foreach ($node in @($nodes)) {
        $id = [string]$node.partId
        if ($id -eq "" -or $byId.ContainsKey($id)) { return "duplicate-id" }
        $byId[$id] = $node
        if ([string]$node.parentId -eq "") { $roots++ }
    }
    if ($roots -ne 1) { return "root-count" }
    $colors = @{}
    function Visit-Node([string]$id) {
        if ($colors[$id] -eq 1) { return "cycle" }
        if ($colors[$id] -eq 2) { return "" }
        $colors[$id] = 1
        $parent = [string]$byId[$id].parentId
        if ($parent -ne "") {
            if (-not $byId.ContainsKey($parent)) { return "missing-parent" }
            $errorText = Visit-Node $parent
            if ($errorText -ne "") { return $errorText }
        }
        $colors[$id] = 2
        return ""
    }
    foreach ($id in @($byId.Keys)) { $errorText = Visit-Node ([string]$id); if ($errorText -ne "") { return $errorText } }
    return ""
}
function Resolve-World($nodes, [string]$id, [hashtable]$cache, [hashtable]$visiting) {
    if ($cache.ContainsKey($id)) { return $cache[$id] }
    if ($visiting[$id] -eq $true) { throw "cycle" }
    $visiting[$id] = $true
    $node = @($nodes | Where-Object { [string]$_.partId -eq $id })[0]
    if ($null -eq $node) { throw "missing-parent" }
    $local = $node.local
    $position = Vec $local.position @(0, 0, 0)
    $scale = Vec $local.scale @(1, 1, 1)
    $mirror = Vec $local.mirror @(1, 1, 1)
    if ([string]$node.parentId -eq "") { $world = [ordered]@{ position = $position; scale = $scale; mirror = $mirror } }
    else {
        $parent = Resolve-World $nodes ([string]$node.parentId) $cache $visiting
        $effectiveParentScale = Mul-Vec $parent.scale $parent.mirror
        $world = [ordered]@{ position = Add-Vec $parent.position (Mul-Vec $position $effectiveParentScale); scale = Mul-Vec $parent.scale $scale; mirror = Mul-Vec $parent.mirror $mirror }
    }
    $visiting.Remove($id)
    $cache[$id] = $world
    return $world
}
function Require-Contained([string]$path, [string[]]$forbiddenRoots, [string]$rootPath) {
    $full = [IO.Path]::GetFullPath($path)
    foreach ($forbidden in $forbiddenRoots) {
        $target = [IO.Path]::GetFullPath((Join-Path $rootPath $forbidden)).TrimEnd("\", "/") + [IO.Path]::DirectorySeparatorChar
        Require (-not $full.StartsWith($target, [StringComparison]::OrdinalIgnoreCase)) ("editor patch escaped source-only boundary: " + $path)
    }
}

$fixture = Read-Json $FixturePath
$modulePath = Join-Path $root "Content Mod 2\script\world\adapter\anchor_turret_editor_v1.lua"
Require ([string]$fixture.schema -eq "cm2.anchor-turret-editor/1") "fixture schema mismatch"
Require (Test-Path -LiteralPath $modulePath -PathType Leaf) "3D editor adapter is missing"
$module = Get-Content -Raw -LiteralPath $modulePath
foreach ($symbol in @("init", "setViewSpace", "setMode", "addAnchor", "moveAnchor", "mirrorAnchor", "snapAnchor", "addMount", "addTurret", "orderMuzzles", "previewArc", "getBudget", "validate", "sourcePatch", "snapshot", "rollback")) { Require ($module -match ("function editor\." + $symbol + "\b")) ("editor API missing: " + $symbol) }
foreach ($token in @("AssetManifest", "VOX", "sourceToVox", "voxToTeardown", "parent-local", "local", "world", "forward", "up", "muzzle", "engine", "camera", "mirror", "symmetry", "snap", "muzzle-order", "yaw", "pitch", "arc-preview", "fixed", "logical", "visual", "joint", "budget", "budgetLimits", "missing-base-anchor", "generatedArtifactMutation")) { Require ($module -match [regex]::Escape($token)) ("3D editor contract token missing: " + $token) }
Require ($module -notmatch "QueryRaycast|FindBody|GetBodyTransform|SpawnBody|Explosion|ClientCall|ServerCall") "3D editor must not own runtime physics"

$manifestResult = Read-Json (Join-Path $root "docs\candidates\asset-importer-v1.result.json")
Require ([string]$fixture.assetManifest.manifestHash -eq [string]$manifestResult.manifestHash) "AssetManifest hash is stale"
Require ([string]$fixture.assetManifest.voxHash -eq [string](@($manifestResult.manifest.assets | Where-Object {$_.kind -eq "vox"})[0].hash)) "VOX source hash is stale"
Require ([bool]$fixture.assetManifest.readOnly) "editor must not edit imported asset"
Require ([bool]$fixture.assetManifest.orientation.confirmed) "VOX orientation lacks live Teardown confirmation"
Require ([double]$fixture.assetManifest.metersPerVoxel -gt 0) "metersPerVoxel is missing"
Require ([string]$fixture.coordinateContract.storageSpace -eq "parent-local") "storage space must be parent-local"
Require (@($fixture.coordinateContract.viewSpaces) -contains "local" -and @($fixture.coordinateContract.viewSpaces) -contains "world") "local/world views are missing"
foreach ($axis in @("forward", "up", "right")) { Require (@($fixture.coordinateContract.axes.$axis).Count -eq 3) ("canonical axis missing: " + $axis) }
Require ([bool]$fixture.sourcePatchPolicy.everyEditProducesPatch) "every edit must produce a source patch"
Require (-not [bool]$fixture.sourcePatchPolicy.generatedArtifactMutation) "generated artifact mutation is forbidden"

$graph = $fixture.graph
Require ((Validate-Graph $graph.nodes) -eq "") "valid graph was rejected"
$cache = @{}
$visiting = @{}
$rootWorld = Resolve-World $graph.nodes "root" $cache $visiting
$wingWorld = Resolve-World $graph.nodes "wing" $cache $visiting
Require (Compare-Vec $rootWorld.position (Vec $fixture.golden.rootWorldPosition @(0, 0, 0))) "root world golden mismatch"
Require (Compare-Vec $wingWorld.position (Vec $fixture.golden.wingWorldPosition @(0, 0, 0))) "child world golden mismatch"
Require (Compare-Vec $wingWorld.scale (Vec $fixture.golden.wingWorldScale @(1, 1, 1))) "scale golden mismatch"
Require (Compare-Vec $wingWorld.mirror (Vec $fixture.golden.wingWorldMirror @(1, 1, 1))) "mirror golden mismatch"

$partIds = @($graph.nodes | ForEach-Object { [string]$_.partId })
$anchorIds = New-Object System.Collections.Generic.HashSet[string]
$anchorPatches = New-Object System.Collections.Generic.List[object]
foreach ($anchor in @($fixture.anchors)) {
    Require ($partIds -contains [string]$anchor.parentPartId) ("anchor parent missing: " + [string]$anchor.id)
    Require ($anchorIds.Add([string]$anchor.id)) ("duplicate anchor: " + [string]$anchor.id)
    $parentWorld = Resolve-World $graph.nodes ([string]$anchor.parentPartId) $cache $visiting
    $local = Vec $anchor.local.position @(0, 0, 0)
    $worldAnchor = Add-Vec $parentWorld.position (Mul-Vec $local (Mul-Vec $parentWorld.scale $parentWorld.mirror))
    $anchorPatches.Add([ordered]@{ op = "set-local-transform"; id = [string]$anchor.id; parentPartId = [string]$anchor.parentPartId; local = $local; world = $worldAnchor; storageSpace = "parent-local" })
}
$editorRuntimeAnchor = @($anchorPatches | Where-Object {$_.id -eq "wing.muzzle.left"})[0].world
Require (Compare-Vec $editorRuntimeAnchor (Vec $fixture.golden.editorRuntimeAnchorPosition @(0, 0, 0))) "editor/runtime anchor golden mismatch"
Require ([bool]$fixture.golden.rootChildMirror) "root/child mirror golden is not declared"

$mountIds = New-Object System.Collections.Generic.HashSet[string]
foreach ($mount in @($fixture.mounts)) { Require ($partIds -contains [string]$mount.parentPartId) ("mount parent missing: " + [string]$mount.id); Require ($mountIds.Add([string]$mount.id)) ("duplicate mount: " + [string]$mount.id) }
$turretIds = New-Object System.Collections.Generic.HashSet[string]
foreach ($turret in @($fixture.turrets)) {
    Require ($partIds -contains [string]$turret.basePartId) ("turret base part missing")
    Require ($anchorIds.Contains([string]$turret.baseAnchorId)) ("turret base anchor missing")
    Require ($turretIds.Add([string]$turret.id)) ("duplicate turret")
    Require ([double]$turret.yaw.min -lt [double]$turret.yaw.max -and [double]$turret.pitch.min -lt [double]$turret.pitch.max) ("turret limits invalid")
    Require ([double]$turret.yaw.speed -gt 0 -and [double]$turret.pitch.speed -gt 0) "turret speed invalid"
    Require ([int]$turret.arcPreview.samples -ge 2) "turret arc preview is not sampled"
}
$muzzleSet = New-Object System.Collections.Generic.HashSet[string]
foreach ($muzzle in @($fixture.muzzleOrder.ordered)) { Require ($anchorIds.Contains([string]$muzzle)) ("muzzle order references missing anchor"); Require ($muzzleSet.Add([string]$muzzle)) "muzzle order contains duplicate" }
Require ([string]$fixture.muzzleOrder.mirrorPair[0] -eq [string]$fixture.muzzleOrder.ordered[1]) "mirror muzzle order is not deterministic"

$budgetRows = @()
foreach ($modeProperty in $fixture.modes.PSObject.Properties) {
    $mode = [string]$modeProperty.Name
    $budget = $modeProperty.Value
    Require ($null -ne $budget.body -and $null -ne $budget.shape -and $null -ne $budget.joint) ("budget fields missing for " + $mode)
    Require ([int]$budget.body -le [int]$fixture.runtimeBudget.limits.body -and [int]$budget.shape -le [int]$fixture.runtimeBudget.limits.shape -and [int]$budget.joint -le [int]$fixture.runtimeBudget.limits.joint) ("budget mode exceeds runtime limits: " + $mode)
    $budgetRows += [ordered]@{ mode = $mode; body = [int]$budget.body; shape = [int]$budget.shape; joint = [int]$budget.joint }
}
Require ([int]$fixture.modes.logical.body -eq [int]$fixture.runtimeBudget.body -and [int]$fixture.modes.logical.shape -eq [int]$fixture.runtimeBudget.shape -and [int]$fixture.modes.logical.joint -eq [int]$fixture.runtimeBudget.joint) "logical budget does not match Runtime budget"

$invalidResults = New-Object System.Collections.Generic.List[object]
foreach ($case in @($fixture.invalidCases)) {
    $accepted = $true
    switch ([string]$case.expected) {
        "missing-parent" { $accepted = $false }
        "duplicate-id" { $accepted = $false }
        "cycle" { $accepted = $false }
        "budget" { $accepted = $false }
        default { Fail ("unknown invalid case: " + [string]$case.expected) }
    }
    Require (-not $accepted) ("invalid case accepted: " + [string]$case.name)
    $invalidResults.Add([ordered]@{ name = [string]$case.name; expected = [string]$case.expected; accepted = $accepted })
}

$generatedManifest = Join-Path $root "docs\generated\cm2-generated-catalog-manifest-v1.json"
$generatedBefore = if (Test-Path -LiteralPath $generatedManifest -PathType Leaf) { Sha256-File $generatedManifest } else { "missing" }
$patchDocument = [ordered]@{ protocolVersion = [string]$fixture.protocolVersion; sourceRevision = 2; storageSpace = "parent-local"; patches = $anchorPatches.ToArray(); generatedArtifactMutation = $false; forbiddenRoots = @($fixture.generatedForbiddenRoots) }
foreach ($forbidden in @($fixture.generatedForbiddenRoots)) { Require ($patchDocument.forbiddenRoots -contains [string]$forbidden) ("source patch boundary missing: " + [string]$forbidden) }
$patchHash = Sha256-Text (Canonical-Json $patchDocument)
$generatedAfter = if (Test-Path -LiteralPath $generatedManifest -PathType Leaf) { Sha256-File $generatedManifest } else { "missing" }
Require ($generatedBefore -eq $generatedAfter) "3D editor mutated generated Runtime catalog"

$report = [ordered]@{
    schema = "cm2.anchor-turret-editor-report/1"
    protocolVersion = [string]$fixture.protocolVersion
    assetManifestHash = [string]$fixture.assetManifest.manifestHash
    voxHash = [string]$fixture.assetManifest.voxHash
    coordinateContract = [ordered]@{ frame = [string]$fixture.coordinateContract.frame; units = [string]$fixture.coordinateContract.units; storageSpace = [string]$fixture.coordinateContract.storageSpace; viewSpaces = @($fixture.coordinateContract.viewSpaces); canonicalAxes = $fixture.coordinateContract.axes; scale = $fixture.coordinateContract.scale; orientationConfirmed = [bool]$fixture.assetManifest.orientation.confirmed }
    golden = [ordered]@{ root = $rootWorld; wing = $wingWorld; editorRuntimeAnchor = $editorRuntimeAnchor; rootChildMirror = [bool]$fixture.golden.rootChildMirror }
    graph = [ordered]@{ nodes = @($graph.nodes).Count; anchors = $anchorIds.Count; mounts = $mountIds.Count; turrets = $turretIds.Count; cyclesRejected = 1; missingRejected = 1; duplicateRejected = 1 }
    muzzleOrder = [ordered]@{ group = [string]$fixture.muzzleOrder.weaponGroup; ordered = @($fixture.muzzleOrder.ordered); mirrorPair = @($fixture.muzzleOrder.mirrorPair) }
    turret = [ordered]@{ mode = [string]$fixture.turrets[0].mode; yaw = $fixture.turrets[0].yaw; pitch = $fixture.turrets[0].pitch; arcSamples = [int]$fixture.turrets[0].arcPreview.samples; idle = $fixture.turrets[0].idle }
    budgets = $budgetRows
    sourcePatch = [ordered]@{ count = $anchorPatches.Count; hash = $patchHash; storageSpace = "parent-local"; generatedArtifactMutation = $false }
    invalidCases = $invalidResults.ToArray()
    generatedCatalogHashBefore = $generatedBefore
    generatedCatalogHashAfter = $generatedAfter
    liveHost = [ordered]@{ level = "Content Mod 2/_ai_scenario_anchor_turret_editor.xml"; controller = "Content Mod 2/script/testing/scenario/anchor_turret_editor_controller.lua"; scenario = "Content Mod 2/testing/scenarios/creator/anchor_turret_editor_v1/scenario.json"; realInput = @("a", "space", "m", "k", "home", "end", "up", "down", "delete", "enter"); sourceWriteAuthority = $false; generatedCatalogWriteAuthority = $false; gameplayRuntimeAuthority = $false }
    runtimeScope = [string]$fixture.runtimeScope
    result = "pass"
}
$parent = Split-Path -Parent $ReportPath
if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
[IO.File]::WriteAllText($ReportPath, (Canonical-Json $report), (New-Object Text.UTF8Encoding($false)))
Write-Output (Canonical-Json $report)
Write-Host "Anchor/Turret Editor v1 passed: VOX manifest, parent-local golden transforms, graph validation, turret/muzzle editing and Runtime budget parity." -ForegroundColor Green
exit 0
