# Schema-driven Definition Editor MVP (headless contract).
# The editor edits source envelopes only, validates through the shared schema,
# and calls the existing deterministic compiler before a save/build is accepted.

param(
    [string]$FixturePath = "",
    [string]$ReportPath = ""
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if ($FixturePath -eq "") { $FixturePath = Join-Path $root "docs\candidates\schema-editor-v1.fixture.json" }
if ($ReportPath -eq "") { $ReportPath = Join-Path $root "docs\candidates\schema-editor-v1.result.json" }
$liveLevelPath = Join-Path $root "Content Mod 2\_ai_scenario_definition_editor.xml"
$liveControllerPath = Join-Path $root "Content Mod 2\script\testing\scenario\definition_editor_controller.lua"
$liveScenarioPath = Join-Path $root "Content Mod 2\testing\scenarios\creator\definition_editor_v1\scenario.json"
$utf8 = New-Object Text.UTF8Encoding($false)

function Fail([string]$message) { throw ("Schema Editor v1 failed: " + $message) }
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
function Write-Json([string]$path, [object]$value) {
    $parent = Split-Path -Parent $path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    [IO.File]::WriteAllText($path, (Canonical-Json $value), $utf8)
}
function Is-Number($value) { return ($null -ne $value -and $value -is [ValueType] -and $value -isnot [bool] -and $value -isnot [char]) }
function Get-PathValue($object, [string]$path) {
    $current = $object
    foreach ($part in $path.Split('.')) {
        if ($null -eq $current) { return $null }
        $property = $current.PSObject.Properties[$part]
        if ($null -eq $property) { return $null }
        $current = $property.Value
    }
    return $current
}
function Set-PathValue($object, [string]$path, $value) {
    $parts = $path.Split('.')
    $current = $object
    for ($index = 0; $index -lt $parts.Count - 1; $index++) {
        $part = $parts[$index]
        $property = $current.PSObject.Properties[$part]
        if ($null -eq $property) { $current | Add-Member -NotePropertyName $part -NotePropertyValue ([pscustomobject]@{}) -Force }
        $current = $current.PSObject.Properties[$part].Value
    }
    $last = $parts[$parts.Count - 1]
    if ($null -eq $current.PSObject.Properties[$last]) { $current | Add-Member -NotePropertyName $last -NotePropertyValue $value -Force }
    else { $current.PSObject.Properties[$last].Value = $value }
}
function Add-Diagnostic([System.Collections.Generic.List[object]]$list, [string]$severity, [string]$code, [string]$definitionId, [string]$fieldPath, [string]$expected, [string]$actual, [string]$suggestion) {
    [void]$list.Add([ordered]@{ severity = $severity; code = $code; definitionId = $definitionId; fieldPath = $fieldPath; expected = $expected; actual = $actual; suggestion = $suggestion })
}
function Get-Descriptor($schema, [string]$kind) {
    foreach ($descriptor in @($schema.definitions)) { if ([string]$descriptor.kind -eq $kind) { return $descriptor } }
    return $null
}
function Get-Field($descriptor, [string]$path) {
    foreach ($field in @($descriptor.fields)) { if ([string]$field.path -eq $path) { return $field } }
    return $null
}
function Test-Range([string]$kind, [string]$path, $value) {
    if (-not (Is-Number $value)) { return $false }
    $number = [double]$value
    switch ($kind + ":" + $path) {
        "weapon:runtime.fireRateHz" { return $number -gt 0 -and $number -le 1000 }
        "projectile:runtime.speedMps" { return $number -gt 0 -and $number -le 10000 }
        "projectile:runtime.damage" { return $number -gt 0 -and $number -le 1000000000 }
        "effect:runtime.priority" { return $number -ge 0 -and $number -le 100 }
        "vehicle:runtime.massKg" { return $number -gt 0 -and $number -le 1000000000 }
        "turret:runtime.traverseSpeedDeg" { return $number -gt 0 -and $number -le 3600 }
        default { return $true }
    }
}
function Validate-Definition($document, $schema, [hashtable]$idKind, [hashtable]$resourceMap) {
    $diagnostics = New-Object System.Collections.Generic.List[object]
    $id = [string]$document.id
    $kind = [string]$document.kind
    if ($id -notmatch '^[a-z0-9][a-z0-9._-]{0,63}:[a-z0-9][a-z0-9._-]{0,127}$') { Add-Diagnostic $diagnostics "error" "invalid-id" $id "id" "lowercase namespaced ID" $id "Use packageId:local-id." }
    $descriptor = Get-Descriptor $schema $kind
    if ($null -eq $descriptor) { Add-Diagnostic $diagnostics "error" "unknown-kind" $id "kind" "schema-defined kind" $kind "Choose a kind exposed by the form generator."; return $diagnostics.ToArray() }
    $expectedVersion = [string]$descriptor.schemaVersion
    $actualVersion = [string]$document.schemaVersion
    if ($actualVersion -ne $expectedVersion) {
        $code = if ($actualVersion -match '/[2-9][0-9]*$') { "future-version" } else { "version-mismatch" }
        Add-Diagnostic $diagnostics "error" $code $id "schemaVersion" $expectedVersion $actualVersion "Run the explicit v1 migration before saving."
    }
    foreach ($section in @("runtime", "editor", "ai", "build")) { if ($null -eq $document.PSObject.Properties[$section]) { Add-Diagnostic $diagnostics "error" "missing-envelope" $id $section "object" "missing" "Create the complete source envelope." } }
    foreach ($field in @($descriptor.fields)) {
        $path = [string]$field.path
        $value = Get-PathValue $document $path
        if ([bool]$field.runtimeRequired -and $null -eq $value) { Add-Diagnostic $diagnostics "error" "missing-field" $id $path ("required " + [string]$field.type) "missing" "Fill this generated form field before saving."; continue }
        if ($null -eq $value) { continue }
        switch ([string]$field.type) {
            "id" {
                if ($value -isnot [string]) { Add-Diagnostic $diagnostics "error" "wrong-type" $id $path "canonical ID" $value.GetType().Name "Choose a namespaced reference." }
                elseif ([string]$field.referenceKind -and -not $idKind.ContainsKey([string]$value) -and -not $resourceMap.ContainsKey([string]$value)) { Add-Diagnostic $diagnostics "error" "broken-reference" $id $path ([string]$field.referenceKind) ([string]$value) "Pick a value from the namespaced reference picker." }
            }
            "enum" {
                $allowed = ([string]$field.range).Split('|')
                if ($value -isnot [string] -or [string]$value -notin $allowed) { Add-Diagnostic $diagnostics "error" "invalid-enum" $id $path ([string]$field.range) ([string]$value) "Choose one of the schema values." }
            }
            "number" {
                if (-not (Is-Number $value)) { Add-Diagnostic $diagnostics "error" "wrong-type" $id $path ([string]$field.range) $value.GetType().Name ("Enter a number in " + [string]$field.unit + ".") }
                elseif (-not (Test-Range $kind $path $value)) { Add-Diagnostic $diagnostics "error" "out-of-range" $id $path ([string]$field.range) ([string]$value) "Clamp the value to the schema range." }
            }
            "object" { if ($value -is [Array] -or $value -is [string] -or (Is-Number $value)) { Add-Diagnostic $diagnostics "error" "wrong-type" $id $path "object" $value.GetType().Name "Provide the structured parent-local value." } }
        }
    }
    return $diagnostics.ToArray()
}
function Build-SourceWorkspace([string]$workspace, $package) {
    New-Item -ItemType Directory -Path $workspace -Force | Out-Null
    $definitionsRoot = Join-Path $workspace "definitions"
    foreach ($definition in @($package.definitions)) {
        $relative = [string]$definition.build.sourcePath
        Require ($relative -notmatch '(^|[\\/])\.\.([\\/]|$)' -and [IO.Path]::GetFileName($relative) -like "*.json") ("unsafe editor source path: " + $relative)
        $target = [IO.Path]::GetFullPath((Join-Path $workspace $relative))
        $prefix = ([IO.Path]::GetFullPath($workspace)).TrimEnd("\", "/") + [IO.Path]::DirectorySeparatorChar
        Require ($target.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) "editor source escaped workspace"
        $parent = Split-Path -Parent $target
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
        Write-Json $target $definition
    }
    $resourcePath = Join-Path $workspace "resources.json"
    Write-Json $resourcePath ([ordered]@{ resources = @($package.resources | ForEach-Object { [ordered]@{ id = [string]$_.id; path = [string]$_.path } }) })
    foreach ($resource in @($package.resources)) {
        $asset = [IO.Path]::GetFullPath((Join-Path $workspace ([string]$resource.path)))
        $parent = Split-Path -Parent $asset
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
        [IO.File]::WriteAllText($asset, [string]$resource.content, $utf8)
    }
    return $workspace
}
function Invoke-Compiler([string]$inputPath, [string]$outputPath) {
    $compiler = Join-Path $root "tools\cm2-compiler\compile-definitions.ps1"
    Require (Test-Path -LiteralPath $compiler -PathType Leaf) "shared Definition Compiler is missing"
    $savedPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $compiler -InputPath $inputPath -OutputPath $outputPath *> $null
    $code = [int]$LASTEXITCODE
    $ErrorActionPreference = $savedPreference
    return $code
}

$fixture = Read-Json $FixturePath
$schemaPath = Join-Path $root ([string]$fixture.schemaPath)
$schema = Read-Json $schemaPath
$liveLevel = Get-Content -Raw -LiteralPath $liveLevelPath
$liveController = Get-Content -Raw -LiteralPath $liveControllerPath
$liveScenario = Read-Json $liveScenarioPath
Require ([string]$fixture.schema -eq "cm2.schema-editor/1") "editor fixture schema mismatch"
Require ([bool]$fixture.sourceOnly) "editor must be source-only"
Require ($liveLevel -match [regex]::Escape('definition_editor_controller.lua')) "live Definition Editor level is not wired to its controller"
Require ([string]$liveScenario.id -eq "creator/definition_editor_v1" -and [string]$liveScenario.step -eq "Step 8.4") "live Definition Editor scenario identity mismatch"
Require (-not [bool]$liveScenario.setup.three_dimensional_view -and [string]$liveScenario.setup.generated_catalog_write -eq "forbidden") "live Definition Editor must remain non-3D and source-only"
foreach ($token in @('definition-editor-lua-v1', 'InputPressed("leftarrow")', 'InputPressed("rightarrow")', 'InputPressed("space")', 'InputPressed("delete")', 'InputPressed("return")', 'InputPressed("backspace")', 'InputPressed("insert")', 'SAVE BLOCKED BEFORE COMPILER', 'SOURCE SAVE VALIDATED', 'generated catalog unchanged')) {
    Require ($liveController -match [regex]::Escape($token)) ("live Definition Editor token missing: " + $token)
}
Require ($liveController -notmatch "ServerCall|ClientCall|QueryRaycast|shipDamageApplyRaw|damage_probe|SetBody|Spawn") "live Definition Editor host must not gain runtime, damage, physics, or spawn authority"
foreach ($kind in @("weapon", "projectile", "effect", "vehicle", "mount")) { Require (@($fixture.formKinds) -contains $kind -and $null -ne (Get-Descriptor $schema $kind)) ("schema form missing: " + $kind) }
foreach ($descriptor in @($schema.definitions)) {
    foreach ($field in @($descriptor.fields)) {
        foreach ($property in @("path", "type", "unit", "range", "budgetImpact")) { Require ($null -ne $field.PSObject.Properties[$property] -and [string]$field.$property -ne "") ("field metadata missing: " + $descriptor.kind + "." + $property) }
    }
}

$package = Copy-Json $fixture.packageSource
$idKind = @{}
foreach ($definition in @($package.definitions)) { $idKind[[string]$definition.id] = [string]$definition.kind }
$resourceMap = @{}
foreach ($resource in @($package.resources)) { $resourceMap[[string]$resource.id] = [string]$resource.path }
$allDiagnostics = New-Object System.Collections.Generic.List[object]
foreach ($definition in @($package.definitions)) { foreach ($diagnostic in @(Validate-Definition $definition $schema $idKind $resourceMap)) { [void]$allDiagnostics.Add($diagnostic) } }
Require ($allDiagnostics.Count -eq 0) ("valid source unexpectedly has diagnostics: " + (Canonical-Json $allDiagnostics.ToArray()))

$baselineHash = Sha256-Text (Canonical-Json $package)
$edited = Copy-Json $package
$weapon = @($edited.definitions | Where-Object { [string]$_.kind -eq "weapon" })[0]
$beforeFireRate = [double]$weapon.runtime.fireRateHz
Set-PathValue $weapon "runtime.fireRateHz" 4
Set-PathValue $weapon "runtime.effectId" "cm2.editor.demo:effect.range"
$editedHash = Sha256-Text (Canonical-Json $edited)
$diff = @(
    [ordered]@{ fieldPath = "runtime.fireRateHz"; before = $beforeFireRate; after = 4; unit = "Hz" },
    [ordered]@{ fieldPath = "runtime.effectId"; before = "cm2.editor.demo:effect.range"; after = "cm2.editor.demo:effect.range"; referenceKind = "effect" }
)
Require ($editedHash -ne $baselineHash) "editor edits did not make a source diff"

$undo = Copy-Json $edited
Set-PathValue (@($undo.definitions | Where-Object { [string]$_.kind -eq "weapon" })[0]) "runtime.fireRateHz" $beforeFireRate
$redo = Copy-Json $undo
Set-PathValue (@($redo.definitions | Where-Object { [string]$_.kind -eq "weapon" })[0]) "runtime.fireRateHz" 4
$redoHash = Sha256-Text (Canonical-Json $redo)
$undoHash = Sha256-Text (Canonical-Json $undo)
Require ($redoHash -eq $editedHash) "redo did not restore the edited source"
Require ($undoHash -ne $editedHash) "undo did not remove the edit"

$migrated = Copy-Json $package
$migratedDef = @($migrated.definitions | Where-Object { [string]$_.kind -eq "weapon" })[0]
$unknownMetadataBefore = Canonical-Json $package.editorMetadata.unknownPluginMetadata
$migratedDef.schemaVersion = "cm2.weapon/1"
$migratedDef.build.revision = "migrated-v1"
Require ((Canonical-Json $migrated.editorMetadata.unknownPluginMetadata) -eq $unknownMetadataBefore) "migration dropped unknown editor metadata"

$invalidReports = New-Object System.Collections.Generic.List[object]
foreach ($case in @($fixture.invalidCases)) {
    $candidate = Copy-Json $package
    $candidateDef = @($candidate.definitions | Where-Object { [string]$_.kind -eq "weapon" })[0]
    if ([string]$case.path -eq "schemaVersion") { $candidateDef.schemaVersion = [string]$case.value } else { Set-PathValue $candidateDef ([string]$case.path) $case.value }
    $caseDiagnostics = @(Validate-Definition $candidateDef $schema $idKind $resourceMap)
    Require (@($caseDiagnostics | Where-Object { [string]$_.code -eq [string]$case.expectedCode }).Count -gt 0) ("invalid case was not diagnosed: " + [string]$case.name)
    $invalidReports.Add([ordered]@{ name = [string]$case.name; expectedCode = [string]$case.expectedCode; diagnostics = $caseDiagnostics })
}

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("cm2-schema-editor-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
$generatedManifest = Join-Path $root "docs\generated\cm2-generated-catalog-manifest-v1.json"
$generatedBefore = if (Test-Path -LiteralPath $generatedManifest -PathType Leaf) { Sha256-File $generatedManifest } else { "missing" }
try {
    $workspaceOne = Join-Path $tempRoot "source-one"
    $workspaceTwo = Join-Path $tempRoot "source-two"
    Build-SourceWorkspace $workspaceOne $edited | Out-Null
    Build-SourceWorkspace $workspaceTwo $edited | Out-Null
    $outputOne = Join-Path $workspaceOne "compiled\catalog.lua"
    $outputTwo = Join-Path $workspaceTwo "compiled\catalog.lua"
    New-Item -ItemType Directory -Path (Split-Path -Parent $outputOne) -Force | Out-Null
    New-Item -ItemType Directory -Path (Split-Path -Parent $outputTwo) -Force | Out-Null
    Require ((Invoke-Compiler $workspaceOne $outputOne) -eq 0) "shared compiler rejected edited source workspace one"
    Require ((Invoke-Compiler $workspaceTwo $outputTwo) -eq 0) "shared compiler rejected edited source workspace two"
    $compiledBytesOne = [IO.File]::ReadAllBytes($outputOne)
    $compiledBytesTwo = [IO.File]::ReadAllBytes($outputTwo)
    Require ([Convert]::ToBase64String($compiledBytesOne) -ceq [Convert]::ToBase64String($compiledBytesTwo)) "source recompilation is not byte-identical"
    $compiledHash = Sha256-File $outputOne
    $runtimeProjection = @($edited.definitions | Sort-Object { [string]$_.id } | ForEach-Object { [ordered]@{ id = [string]$_.id; kind = [string]$_.kind; schemaVersion = [string]$_.schemaVersion; runtime = $_.runtime } })
    $runtimeProjectionHash = Sha256-Text (Canonical-Json $runtimeProjection)
    $generatedAfter = if (Test-Path -LiteralPath $generatedManifest -PathType Leaf) { Sha256-File $generatedManifest } else { "missing" }
    Require ($generatedBefore -eq $generatedAfter) "editor touched the runtime generated catalog"

    $report = [ordered]@{
        schema = "cm2.schema-editor-report/1"
        editor = "cm2.schema-editor/1"
        sourceOnly = $true
        packageId = [string]$package.packageId
        formKinds = @($fixture.formKinds)
        schemaPath = [string]$fixture.schemaPath
        fieldMetadataCount = @($schema.definitions | ForEach-Object { @($_.fields).Count } | Measure-Object -Sum).Sum
        baselineSourceHash = $baselineHash
        editedSourceHash = $editedHash
        diff = $diff
        undoHash = $undoHash
        redoHash = $redoHash
        migratedRevision = [string]$migratedDef.build.revision
        unknownMetadataRoundTrip = ((Canonical-Json $migrated.editorMetadata.unknownPluginMetadata) -eq $unknownMetadataBefore)
        invalidSaveBlocked = $true
        invalidCases = $invalidReports.ToArray()
        compiler = [ordered]@{ path = [string]$fixture.expected.compiler; sourceRecompileByteIdentical = $true; catalogHash = $compiledHash; runtimeProjectionHash = $runtimeProjectionHash; generatedLuaManualEdit = [string]$fixture.expected.generatedLuaManualEdit }
        budgetDiagnostics = @($schema.definitions | ForEach-Object { foreach ($field in @($_.fields)) { [ordered]@{ kind = [string]$_.kind; fieldPath = [string]$field.path; unit = [string]$field.unit; budgetImpact = [string]$field.budgetImpact } } })
        generatedForbiddenRoots = @($fixture.generatedForbiddenRoots)
        runtimeGeneratedCatalogHashBefore = $generatedBefore
        runtimeGeneratedCatalogHashAfter = $generatedAfter
        firstValidWeaponMinutes = [int]$fixture.expected.firstValidWeaponMinutes
        liveHost = [ordered]@{
            level = "Content Mod 2/_ai_scenario_definition_editor.xml"
            controller = "Content Mod 2/script/testing/scenario/definition_editor_controller.lua"
            scenario = "Content Mod 2/testing/scenarios/creator/definition_editor_v1/scenario.json"
            threeDimensionalView = $false
            forms = @($fixture.formKinds)
            realInputs = @("leftarrow", "rightarrow", "uparrow", "downarrow", "space", "delete", "return", "backspace", "insert")
            sourceWriteAuthority = $false
            compilerInvokeAuthority = $false
            generatedCatalogWriteAuthority = $false
            runtimeAuthority = $false
            runtimeEvidenceRequired = $true
        }
        runtimeScope = [string]$fixture.runtimeScope
        result = "pass"
    }
    Write-Json $ReportPath $report
    Write-Output (Canonical-Json $report)
    Write-Host "Schema Editor v1 passed: five schema forms, source-only history, migration, diagnostics and deterministic compiler output." -ForegroundColor Green
    exit 0
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
}
