# Validate the Source Envelope and six core Schema v1 definitions.

param(
    [string]$Path = "."
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath $Path).Path
$catalogPath = Join-Path $root "schemas\cm2\source-envelope-v1.json"
$fixturePath = Join-Path $root "harness\data\schemas\cm2-schema-v1-fixtures.json"
$issues = New-Object System.Collections.Generic.List[string]
$requiredKinds = @("weapon", "projectile", "effect", "vehicle", "mount", "turret")
$supplementalKinds = @("part", "anchor", "damage", "sound", "targetFilter", "flight", "component")
$failureCases = @("valid", "missing", "wrong-type", "out-of-range", "broken-reference", "future-version")

function Add-Diagnostic($list, $definition, [string]$path, [string]$expected, [string]$actual, [string]$suggestion) {
    $id = if ($null -eq $definition -or $null -eq $definition.id) { "<missing-id>" } else { [string]$definition.id }
    $list.Add([PSCustomObject]@{
        id = $id
        fieldPath = $path
        expected = $expected
        actual = $actual
        suggestion = $suggestion
    })
}

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

function Is-Number($value) {
    return ($null -ne $value -and $value -is [ValueType] -and $value -isnot [bool] -and $value -isnot [char] -and $value -isnot [DateTime])
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

function Test-Definition($definition, $fieldDescriptors, $knownIds) {
    $diagnostics = New-Object System.Collections.Generic.List[object]
    $idText = if ($null -eq $definition.id) { "<missing>" } else { [string]$definition.id }
    $kind = [string]$definition.kind
    $expectedSchema = "cm2.$kind/1"
    foreach ($field in @("schemaVersion", "id", "kind", "runtime", "editor", "ai", "build")) {
        if ($null -eq $definition.PSObject.Properties[$field] -or $null -eq $definition.$field) {
            Add-Diagnostic $diagnostics $definition $field "required" "missing" "Add the envelope field."
        }
    }
    if ($idText -notmatch '^[a-z0-9][a-z0-9._-]{0,63}:[a-z0-9][a-z0-9._-]{0,127}$') {
        Add-Diagnostic $diagnostics $definition "id" "packageId:local-id (lowercase ASCII)" $idText "Use a canonical namespaced ID."
    }
    if ([string]$definition.schemaVersion -match '/([0-9]+)$' -and [int]$Matches[1] -gt 1) {
        Add-Diagnostic $diagnostics $definition "schemaVersion" $expectedSchema ([string]$definition.schemaVersion) "Run an explicit schema migration before compiling."
    }
    elseif ([string]$definition.schemaVersion -ne $expectedSchema) {
        Add-Diagnostic $diagnostics $definition "schemaVersion" $expectedSchema ([string]$definition.schemaVersion) "Use the v1 schema for this kind."
    }
    if ($kind -notin $requiredKinds) {
        Add-Diagnostic $diagnostics $definition "kind" ($requiredKinds -join "|") $kind "Choose one of the six v1 kinds."
        return $diagnostics
    }
    foreach ($section in @("runtime", "editor", "ai", "build")) {
        if ($null -ne $definition.$section -and $definition.$section -is [Array]) {
            Add-Diagnostic $diagnostics $definition $section "object" "array" "Keep authoring sections as objects."
        }
    }
    foreach ($field in @($fieldDescriptors)) {
        $value = Get-PathValue $definition ([string]$field.path)
        if ($field.runtimeRequired -and $null -eq $value) {
            Add-Diagnostic $diagnostics $definition $field.path "required $($field.type)" "missing" "Provide the Runtime-required field or migrate to a supported adapter."
            continue
        }
        if ($null -eq $value) { continue }
        $actual = $value.GetType().Name
        switch ([string]$field.type) {
            "id" {
                if ($value -isnot [string] -or [string]$value -notmatch '^[a-z0-9][a-z0-9._-]{0,63}:[a-z0-9][a-z0-9._-]{0,127}$') {
                    Add-Diagnostic $diagnostics $definition $field.path "canonical ID" "${actual}:$value" "Use a lowercase packageId:local-id."
                }
                elseif ([string]$field.referenceKind -and [string]$value -notin $knownIds) {
                    Add-Diagnostic $diagnostics $definition $field.path "$($field.referenceKind) reference" ([string]$value) "Add the referenced Definition or correct the ID."
                }
            }
            "enum" {
                $allowed = ([string]$field.range).Split('|')
                if ($value -isnot [string] -or [string]$value -notin $allowed) {
                    Add-Diagnostic $diagnostics $definition $field.path ([string]$field.range) "${actual}:$value" "Use one of the declared enum values."
                }
            }
            "number" {
                if (-not (Is-Number $value)) {
                    Add-Diagnostic $diagnostics $definition $field.path ([string]$field.range) "${actual}:$value" "Provide a numeric value with the declared unit."
                }
                elseif (-not (Test-Range $kind ([string]$field.path) $value)) {
                    Add-Diagnostic $diagnostics $definition $field.path ([string]$field.range) ([string]$value) "Clamp or replace the value within the v1 range."
                }
            }
            "object" {
                if ($value -is [Array] -or $value -is [string] -or $value -is [ValueType]) {
                    Add-Diagnostic $diagnostics $definition $field.path "object" "${actual}:$value" "Provide a parent-local transform object."
                }
            }
        }
    }
    return $diagnostics
}

foreach ($required in @($catalogPath, $fixturePath)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { $issues.Add("missing schema artifact: $required") }
}
if ($issues.Count -eq 0) {
    try {
        $catalog = Get-Content -Raw -LiteralPath $catalogPath | ConvertFrom-Json
        $fixtures = Get-Content -Raw -LiteralPath $fixturePath | ConvertFrom-Json
    }
    catch { $issues.Add("invalid schema JSON: $($_.Exception.Message)") }
}
if ($issues.Count -eq 0) {
    if ([string]$catalog.schemaVersion -ne "cm2.schema-catalog/1") { $issues.Add("catalog schemaVersion must be cm2.schema-catalog/1") }
    if ((@($catalog.envelope.required) -join ",") -ne "schemaVersion,id,kind,runtime,editor,ai,build") { $issues.Add("envelope required fields are incomplete or reordered") }
    $definitions = @($catalog.definitions)
    if ($definitions.Count -ne 6) { $issues.Add("catalog must contain exactly six core kinds") }
    foreach ($kind in $requiredKinds) {
        $entry = $definitions | Where-Object { [string]$_.kind -eq $kind }
        if ($null -eq $entry) { $issues.Add("missing schema descriptor: $kind"); continue }
        foreach ($field in @($entry.fields)) {
            foreach ($metadata in @("path", "type", "unit", "range", "default", "runtimeRequired", "referenceKind", "budgetImpact")) {
                $metadataProperty = $field.PSObject.Properties[$metadata]
                if ($null -eq $metadataProperty) {
                    $issues.Add("$kind field $($field.path) missing metadata: $metadata")
                }
                elseif ($null -eq $metadataProperty.Value -and $metadata -notin @("default", "referenceKind")) {
                    $issues.Add("$kind field $($field.path) has empty metadata: $metadata")
                }
            }
        }
    }
    foreach ($kind in $supplementalKinds) {
        $entry = @($catalog.supplementalDefinitions | Where-Object { [string]$_.kind -eq $kind })
        if ($entry.Count -ne 1) { $issues.Add("missing or duplicate supplemental schema descriptor: $kind"); continue }
        foreach ($field in @($entry[0].fields)) {
            foreach ($metadata in @("path", "type", "unit", "range", "default", "runtimeRequired", "referenceKind", "budgetImpact")) {
                $metadataProperty = $field.PSObject.Properties[$metadata]
                if ($null -eq $metadataProperty -or ($null -eq $metadataProperty.Value -and $metadata -notin @("default", "referenceKind"))) {
                    $issues.Add("$kind field $($field.path) missing metadata: $metadata")
                }
            }
        }
    }
    if ((@($fixtures.failureCases | ForEach-Object { [string]$_ }) -join ",") -ne ($failureCases -join ",")) { $issues.Add("fixture failureCases must enumerate six required categories") }
}
if ($issues.Count -eq 0) {
    $bases = @($fixtures.bases)
    $knownIds = New-Object System.Collections.Generic.HashSet[string]
    foreach ($base in $bases) { [void]$knownIds.Add([string]$base.id) }
    foreach ($externalId in @($fixtures.knownReferences)) { [void]$knownIds.Add([string]$externalId) }
    $fixtureCount = 0
    $diagnosticCount = 0
    foreach ($base in $bases) {
        $kind = [string]$base.kind
        $descriptor = @($catalog.definitions | Where-Object { [string]$_.kind -eq $kind })[0]
        $validDiagnostics = @(Test-Definition $base @($descriptor.fields) $knownIds)
        if ($validDiagnostics.Count -gt 0) { $issues.Add("valid $kind fixture rejected: $($validDiagnostics[0].fieldPath)") }
        foreach ($case in $failureCases | Where-Object { $_ -ne "valid" }) {
            $mutated = ConvertFrom-Json ($base | ConvertTo-Json -Depth 20)
            switch ($case) {
                "missing" { $mutated.runtime = $null }
                "wrong-type" { $mutated.id = 7 }
                "out-of-range" {
                    switch ($kind) {
                        "weapon" { $mutated.runtime.fireRateHz = -1 }
                        "projectile" { $mutated.runtime.speedMps = 0 }
                        "effect" { $mutated.runtime.priority = 101 }
                        "vehicle" { $mutated.runtime.massKg = 0 }
                        "mount" { $mutated.runtime.slotType = "invalid" }
                        "turret" { $mutated.runtime.traverseSpeedDeg = 0 }
                    }
                }
                "broken-reference" {
                    switch ($kind) {
                        "weapon" { $mutated.runtime.effectId = "cm2:missing.effect" }
                        "projectile" { $mutated.runtime.effectId = "cm2:missing.effect" }
                        "effect" { $mutated.runtime.assetId = "cm2:missing.asset" }
                        "vehicle" { $mutated.runtime.mountId = "cm2:missing.mount" }
                        "mount" { $mutated.runtime.parentId = "cm2:missing.vehicle" }
                        "turret" { $mutated.runtime.weaponId = "cm2:missing.weapon" }
                    }
                }
                "future-version" { $mutated.schemaVersion = "cm2.$kind/2" }
            }
            $diagnostics = @(Test-Definition $mutated @($descriptor.fields) $knownIds)
            $fixtureCount++
            if ($diagnostics.Count -eq 0) { $issues.Add("$case $kind fixture was accepted") }
            else {
                $diagnosticCount += $diagnostics.Count
                foreach ($diagnostic in $diagnostics) {
                    foreach ($key in @("id", "fieldPath", "expected", "actual", "suggestion")) {
                        if ([string]::IsNullOrWhiteSpace([string]$diagnostic.$key)) { $issues.Add("diagnostic missing $key for $case/$kind") }
                    }
                }
            }
        }
    }
    if ($bases.Count -ne 6) { $issues.Add("fixture bases must contain one valid definition per core kind") }
    if ($fixtureCount -ne 30) { $issues.Add("expected 30 negative fixtures, got $fixtureCount") }
}
if ($issues.Count -gt 0) {
    Write-Error ("Schema v1 check failed:`n - " + ($issues -join "`n - "))
    exit 1
}

Write-Host "Schema v1 passed: 6 kinds, 6 valid bases, 30 negative fixtures, structured diagnostics ($diagnosticCount)." -ForegroundColor Green
exit 0
