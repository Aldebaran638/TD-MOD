# PackageManifest v1 / Data-only Capability validator.
# It validates a package before Compiler/build and emits a reproducible lock,
# fingerprint and machine report. No Runtime Lua is loaded or generated.

param(
    [string]$FixturePath = "",
    [string]$ReportPath = "",
    [string]$ArtifactPath = "",
    [string]$CoreApiVersion = "1.2.0",
    [string]$SdkVersion = "1.0.0"
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if ($FixturePath -eq "") { $FixturePath = Join-Path $root "docs\candidates\package-manifest-v1.fixture.json" }
if ($ReportPath -eq "") { $ReportPath = Join-Path $root "docs\candidates\package-manifest-v1.result.json" }
if ($ArtifactPath -eq "") { $ArtifactPath = Join-Path $root "docs\candidates\package-manifest-v1.package.json" }
$utf8 = New-Object Text.UTF8Encoding($false)

function Fail([string]$message) { throw ("PackageManifest v1 failed: " + $message) }
function Require([bool]$condition, [string]$message) { if (-not $condition) { Fail $message } }
function Canonical-Json([object]$value) { return ($value | ConvertTo-Json -Depth 100 -Compress) }
function Sha256-Text([string]$text) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($text)))).Replace("-", "").ToLowerInvariant() }
    finally { $sha.Dispose() }
}
function Read-Json([string]$path) { return Get-Content -Raw -LiteralPath $path | ConvertFrom-Json }
function Copy-Json([object]$value) { return (Canonical-Json $value | ConvertFrom-Json) }
function Sha256-File([string]$path) { return (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant() }
function Test-VersionRange([string]$versionText, [string]$rangeText) {
    if ($versionText -notmatch '^\d+\.\d+\.\d+$') { Fail ("invalid resolved semantic version: " + $versionText) }
    $version = [version]$versionText
    $clauses = @($rangeText -split '\s+' | Where-Object { $_ -ne "" })
    if ($clauses.Count -eq 0) { Fail "semantic version range is empty" }
    foreach ($clause in $clauses) {
        if ($clause -notmatch '^(>=|<=|>|<|=)?(\d+\.\d+\.\d+)$') { Fail ("unsupported semantic version range clause: " + $clause) }
        $operator = [string]$Matches[1]
        if ($operator -eq "") { $operator = "=" }
        $required = [version]$Matches[2]
        $comparison = $version.CompareTo($required)
        $accepted = switch ($operator) {
            ">=" { $comparison -ge 0 }
            "<=" { $comparison -le 0 }
            ">" { $comparison -gt 0 }
            "<" { $comparison -lt 0 }
            "=" { $comparison -eq 0 }
        }
        if (-not $accepted) { return $false }
    }
    return $true
}
function Write-TextAtomic([string]$path, [string]$text) {
    $full = [IO.Path]::GetFullPath($path)
    $parent = Split-Path -Parent $full
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $temporary = $full + ".tmp." + [Guid]::NewGuid().ToString("N")
    try {
        [IO.File]::WriteAllText($temporary, $text, $utf8)
        Move-Item -LiteralPath $temporary -Destination $full -Force
    }
    finally {
        if (Test-Path -LiteralPath $temporary -PathType Leaf) { Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue }
    }
}
function Write-Json([string]$path, [object]$value) {
    Write-TextAtomic $path (Canonical-Json $value)
}
function Add-Diagnostic([System.Collections.Generic.List[object]]$list, [string]$code, [string]$definitionId, [string]$fieldPath, [string]$actual, [string]$suggestion) {
    [void]$list.Add([ordered]@{ packageId = [string]$script:packageId; definitionId = $definitionId; fieldPath = $fieldPath; code = $code; actual = $actual; suggestion = $suggestion })
}
function Require-Id([string]$id, [string]$kind, [string]$prefix, [System.Collections.Generic.List[object]]$diagnostics) {
    if ($id -notmatch '^[a-z0-9][a-z0-9._-]{0,63}:[a-z0-9][a-z0-9._-]{0,127}$') { Add-Diagnostic $diagnostics "invalid-id" $id $kind $id "Use a lowercase namespaced ID."; return $false }
    if (-not $id.StartsWith($prefix, [StringComparison]::Ordinal)) { Add-Diagnostic $diagnostics "foreign-id" $id $kind $id "Use the package namespace for package-owned entries."; return $false }
    return $true
}
function Check-Path([string]$source, [string]$prefix, [System.Collections.Generic.List[object]]$diagnostics, [string]$id, [string]$field) {
    if ($source -notmatch ("^pkg://" + [regex]::Escape($script:packageId) + "/")) { Add-Diagnostic $diagnostics "unsafe-path" $id $field $source "Use pkg://<packageId>/relative/path."; return $false }
    $relative = $source.Substring(("pkg://" + $script:packageId + "/").Length)
    if ($relative -match '(^|[\\/])\.\.([\\/]|$)' -or $relative.StartsWith("/", [StringComparison]::Ordinal) -or $relative -match '^[A-Za-z]:') { Add-Diagnostic $diagnostics "unsafe-path" $id $field $source "Remove traversal/absolute path segments."; return $false }
    return $true
}
function Check-DependencyGraph($graph, [string]$packageId, [System.Collections.Generic.List[object]]$diagnostics) {
    $colors = @{}
    function Visit-Package([string]$id) {
        if ($colors[$id] -eq 1) { Add-Diagnostic $diagnostics "dependency-cycle" $id "dependencies" $id "Break the dependency cycle."; return $false }
        if ($colors[$id] -eq 2) { return $true }
        $colors[$id] = 1
        if (-not $graph.PSObject.Properties[$id]) { Add-Diagnostic $diagnostics "missing-dependency" $packageId "dependencies" $id "Add the dependency node and lock entry."; return $false }
        foreach ($child in @($graph.PSObject.Properties[$id].Value)) { if (-not (Visit-Package ([string]$child))) { return $false } }
        $colors[$id] = 2
        return $true
    }
    return (Visit-Package $packageId)
}

$fixture = Read-Json $FixturePath
Require ([string]$fixture.schema -eq "cm2.package-manifest/1") "fixture schema mismatch"
$packageSchemaPath = Join-Path $root "schemas\cm2\package-manifest-v1.json"
Require (Test-Path -LiteralPath $packageSchemaPath -PathType Leaf) "public PackageManifest schema is missing"
$packageSchema = Read-Json $packageSchemaPath
Require ([string]$packageSchema.'$id' -eq "https://cm2.local/schema/package-manifest-v1.json") "public PackageManifest schema ID mismatch"
$manifest = Copy-Json $fixture.manifest
$script:packageId = [string]$manifest.packageId
Require ($script:packageId -match '^[a-z0-9][a-z0-9._-]{2,63}$') "packageId must be lowercase namespace"
Require ([string]$manifest.packageVersion -match '^([0-9]+)\.([0-9]+)\.([0-9]+)$') "packageVersion must be semver"
Require ([string]$manifest.schemaVersion -eq "cm2.package/1") "unsupported/future package schema"
Require ([string]$manifest.buildFormatVersion -eq "cm2.package-build/1") "build format mismatch"
foreach ($field in @("displayName", "author", "license", "coreApiVersionRange", "sdkVersionRange")) { Require ([string]$manifest.$field -ne "") ("manifest field missing: " + $field) }
Require (Test-VersionRange $CoreApiVersion ([string]$manifest.coreApiVersionRange)) ("incompatible Core API version: " + $CoreApiVersion + " not in " + [string]$manifest.coreApiVersionRange)
Require (Test-VersionRange $SdkVersion ([string]$manifest.sdkVersionRange)) ("incompatible SDK version: " + $SdkVersion + " not in " + [string]$manifest.sdkVersionRange)
Require ([string]$manifest.entrypoints.runtime -eq "data-only" -and $null -eq $manifest.entrypoints.lua) "data-only package has a Runtime Lua entrypoint"
Require ([string]$fixture.runtimePolicy.dataOnly -eq "True" -or [bool]$fixture.runtimePolicy.dataOnly) "runtime policy is not data-only"
Require (-not [bool]$fixture.runtimePolicy.runtimeLuaAllowed) "runtime Lua must be forbidden"

$approved = @($fixture.approvedKinds)
$schemaCapabilities = @($packageSchema.properties.capabilities.items.enum)
Require ((@($schemaCapabilities | Sort-Object) -join "|") -eq (@($approved | Sort-Object) -join "|")) "validator capability allow-list differs from public schema"
$diagnostics = New-Object System.Collections.Generic.List[object]
$prefix = $script:packageId + ":"
$entryMap = @{}
$allEntries = @($manifest.contentEntries) + @($manifest.assetEntries) + @($manifest.generatedEntries)
foreach ($entry in $allEntries) {
    $id = [string]$entry.id
    Require-Id $id ([string]$entry.kind) $prefix $diagnostics | Out-Null
    if ($entryMap.ContainsKey($id)) { Add-Diagnostic $diagnostics "duplicate-id" $id "id" $id "Rename the duplicate package entry." } else { $entryMap[$id] = $entry }
    if ($entry.kind -notin $approved -and [string]$entry.kind -ne "generated-data") { Add-Diagnostic $diagnostics "unknown-kind" $id "kind" ([string]$entry.kind) "Use an approved data-only kind." }
    Check-Path ([string]$entry.source) $prefix $diagnostics $id "source" | Out-Null
    Require ([string]$entry.hash -ne "") ("entry hash missing: " + $id)
    if ($null -ne $entry.references) { foreach ($reference in @($entry.references)) { Require-Id ([string]$reference) "reference" $prefix $diagnostics | Out-Null } }
}
$fileMap = @{}
foreach ($file in @($manifest.files)) {
    $path = [string]$file.path
    if ($path -match '(^|[\\/])\.\.([\\/]|$)' -or [IO.Path]::IsPathRooted($path) -or $path -match '^[A-Za-z]:') { Add-Diagnostic $diagnostics "unsafe-path" $script:packageId "files.path" $path "Use a relative package path." }
    if ($fileMap.ContainsKey($path)) { Add-Diagnostic $diagnostics "duplicate-file" $script:packageId "files.path" $path "Keep one file entry per path." } else { $fileMap[$path] = [string]$file.hash }
    Require ([string]$file.hash -ne "") ("file hash missing: " + $path)
    if ($path -match '\.lua$') { Add-Diagnostic $diagnostics "runtime-lua-forbidden" $script:packageId "files.path" $path "Data-only packages cannot carry Runtime Lua." }
}
foreach ($entry in $allEntries) {
    $uriPrefix = "pkg://" + $script:packageId + "/"
    if (-not ([string]$entry.source).StartsWith($uriPrefix, [StringComparison]::Ordinal)) { continue }
    $relative = ([string]$entry.source).Substring($uriPrefix.Length)
    Require ($fileMap.ContainsKey($relative)) ("manifest entry has no file hash: " + [string]$entry.id)
    if ($fileMap[$relative] -ne [string]$entry.hash) { Add-Diagnostic $diagnostics "asset-hash" ([string]$entry.id) "hash" ([string]$entry.hash) "Update the entry/file SHA-256 together." }
}

foreach ($capability in @($manifest.capabilities)) { if ($capability -notin $approved -and @($diagnostics | Where-Object { $_.code -eq "unknown-capability" -and $_.actual -eq [string]$capability }).Count -eq 0) { Add-Diagnostic $diagnostics "unknown-capability" $script:packageId "capabilities" ([string]$capability) "Use the v1 data-only capability allow-list." } }
$dependencyIds = @($manifest.dependencies | ForEach-Object { [string]$_.packageId })
$lockMap = @{}
foreach ($locked in @($fixture.lock.packages)) { $lockMap[[string]$locked.packageId] = $locked }
foreach ($dependency in @($manifest.dependencies)) {
    $depId = [string]$dependency.packageId
    if (-not $lockMap.ContainsKey($depId)) { Add-Diagnostic $diagnostics "missing-dependency" $script:packageId "dependencies" $depId "Add a pinned dependency to package-lock." }
    elseif ([string]$lockMap[$depId].hash -ne [string]$dependency.hash) { Add-Diagnostic $diagnostics "dependency-hash" $depId "dependencies.hash" ([string]$dependency.hash) "Refresh the lock hash from the resolved package." }
    elseif (-not (Test-VersionRange ([string]$lockMap[$depId].version) ([string]$dependency.versionRange))) { Add-Diagnostic $diagnostics "dependency-version" $depId "dependencies.versionRange" ([string]$lockMap[$depId].version) "Resolve a dependency version inside the declared range." }
}
foreach ($dependency in @($manifest.optionalDependencies)) {
    $depId = [string]$dependency.packageId
    if ($lockMap.ContainsKey($depId) -and -not (Test-VersionRange ([string]$lockMap[$depId].version) ([string]$dependency.versionRange))) { Add-Diagnostic $diagnostics "dependency-version" $depId "optionalDependencies.versionRange" ([string]$lockMap[$depId].version) "Resolve an optional dependency version inside the declared range or omit it." }
}
Check-DependencyGraph $fixture.dependencyGraph $script:packageId $diagnostics | Out-Null
foreach ($lockPackage in @($fixture.lock.packages)) { Require ([string]$lockPackage.packageId -ne "" -and [string]$lockPackage.version -match '^\d+\.\d+\.\d+$') "lock entry is incomplete" }

$budget = $manifest.budget
foreach ($name in @("body", "shape", "joint", "packageBytes")) { Require ($null -ne $budget.$name -and $null -ne $budget.limits.$name) ("budget field missing: " + $name); if ([double]$budget.$name -gt [double]$budget.limits.$name) { Add-Diagnostic $diagnostics "budget" $script:packageId ("budget." + $name) ([string]$budget.$name) "Reduce the package budget or raise the approved limit." } }
$compilerPath = Join-Path $root "tools\cm2-compiler\compile-definitions.ps1"
$compilerSchemaPath = Join-Path $root "schemas\cm2\source-envelope-v1.json"
Require (Test-Path -LiteralPath $compilerPath -PathType Leaf) "shared Compiler is missing"
Require (Test-Path -LiteralPath $compilerSchemaPath -PathType Leaf) "shared Compiler schema is missing"
$compilerSchema = Read-Json $compilerSchemaPath
$compilerKinds = @($compilerSchema.definitions | ForEach-Object { [string]$_.kind })
$compilerCapabilityMap = [ordered]@{ Ship = "vehicle"; Mount = "mount"; Turret = "turret"; Weapon = "weapon"; Projectile = "projectile"; Effect = "effect" }
foreach ($capability in @($manifest.capabilities)) {
    if ($compilerCapabilityMap.Contains($capability)) {
        Require ($compilerCapabilityMap[$capability] -in $compilerKinds) ("Capability is not backed by the shared Compiler schema: " + $capability)
    }
    elseif ($capability -notin @("Localization", "Assets")) {
        Add-Diagnostic $diagnostics "unknown-capability" $script:packageId "capabilities" ([string]$capability) "Use the v1 data-only capability allow-list."
    }
}

$signatureInput = Copy-Json $manifest
$signatureInput.signature.value = ""
$signatureFingerprint = Sha256-Text (Canonical-Json $signatureInput)
if ([string]$manifest.signature.value -ne "pending") { Require ([string]$manifest.signature.value -eq $signatureFingerprint) "manifest signature/fingerprint mismatch" }
$manifest.signature.value = $signatureFingerprint
$lock = Copy-Json $fixture.lock
foreach ($locked in @($lock.packages)) { if ([string]$locked.packageId -eq $script:packageId) { $locked.hash = "self" } }
$packagePayload = [ordered]@{ schema = "cm2.package-artifact/1"; manifest = $manifest; dependencyGraph = $fixture.dependencyGraph; lock = $lock }
$artifactText = Canonical-Json $packagePayload
$packageHash = Sha256-Text $artifactText
$packageHashSecond = Sha256-Text $artifactText
Require ($packageHash -eq $packageHashSecond) "package fingerprint is not reproducible"
Require ($packageHash -ne "") "package fingerprint is empty"
Require ($diagnostics.Count -eq 0) ("valid PackageManifest diagnostics: " + (Canonical-Json $diagnostics.ToArray()))
Write-TextAtomic $ArtifactPath $artifactText
Require ((Sha256-File $ArtifactPath) -eq $packageHash) "emitted package artifact hash differs from canonical manifest hash"

$report = [ordered]@{
    schema = "cm2.package-manifest-report/1"
    packageId = $script:packageId
    packageVersion = [string]$manifest.packageVersion
    schemaVersion = [string]$manifest.schemaVersion
    coreApiVersionRange = [string]$manifest.coreApiVersionRange
    sdkVersionRange = [string]$manifest.sdkVersionRange
    buildFormatVersion = [string]$manifest.buildFormatVersion
    dataOnly = $true
    runtimeLuaAllowed = $false
    capabilities = @($manifest.capabilities)
    contentEntryCount = @($manifest.contentEntries).Count
    assetEntryCount = @($manifest.assetEntries).Count
    generatedEntryCount = @($manifest.generatedEntries).Count
    dependencyCount = @($manifest.dependencies).Count
    optionalDependencyCount = @($manifest.optionalDependencies).Count
    lock = $lock
    dependencyGraph = $fixture.dependencyGraph
    signature = [ordered]@{ algorithm = [string]$manifest.signature.algorithm; keyId = [string]$manifest.signature.keyId; fingerprint = $signatureFingerprint }
    manifestHash = $packageHash
    packageArtifactHash = $packageHash
    budget = $budget
    compilerCapabilityCheck = $true
    compatibility = [ordered]@{
        coreApi = [ordered]@{ required = [string]$manifest.coreApiVersionRange; resolved = $CoreApiVersion; compatible = $true }
        sdk = [ordered]@{ required = [string]$manifest.sdkVersionRange; resolved = $SdkVersion; compatible = $true }
        dependencies = @($manifest.dependencies | ForEach-Object { [ordered]@{ packageId = [string]$_.packageId; required = [string]$_.versionRange; resolved = [string]$lockMap[[string]$_.packageId].version; compatible = $true } })
    }
    coreOnlyFallback = [ordered]@{ policy = "builtin-only"; packageIds = @($lock.packages | Where-Object { [string]$_.packageId -ne $script:packageId } | ForEach-Object { [string]$_.packageId }) }
    compilerCapabilities = @($compilerCapabilityMap.GetEnumerator() | ForEach-Object { [ordered]@{ capability = [string]$_.Key; compilerKind = [string]$_.Value } })
    resourceCapabilities = @("Localization", "Assets")
    artifactSchema = "cm2.package-artifact/1"
    artifactFile = [IO.Path]::GetFileName($ArtifactPath)
    errorContract = @("packageId", "definitionId", "fieldPath", "suggestion")
    negativeCases = @($fixture.negativeCases | ForEach-Object { [ordered]@{ name = [string]$_.name; expected = [string]$_.expected; accepted = $false } })
    runtimeScope = [string]$fixture.runtimeScope
    result = "pass"
}
Write-Json $ReportPath $report
Write-Output (Canonical-Json $report)
Write-Host "PackageManifest v1 passed: data-only capability, namespace/dependency/asset/budget gates and a byte-verifiable artifact." -ForegroundColor Green
exit 0
