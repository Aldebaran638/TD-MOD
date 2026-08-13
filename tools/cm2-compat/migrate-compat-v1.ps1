# Major-0 to canonical-v1 migration adapter. Input is immutable; output/report
# publish only after the complete migration succeeds.

param(
    [Parameter(Mandatory = $true)][string]$InputPath,
    [Parameter(Mandatory = $true)][string]$OutputPath,
    [string]$ReportPath = ""
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$policyPath = Join-Path $root "docs\compatibility-policy-v1.json"
$schemaPath = Join-Path $root "schemas\cm2\source-envelope-v1.json"
$utf8 = New-Object Text.UTF8Encoding($false)
if ($ReportPath -eq "") { $ReportPath = [IO.Path]::ChangeExtension($OutputPath, ".report.json") }
$script:packageId = ""
$script:definitionId = ""
$script:warnings = New-Object System.Collections.Generic.List[object]

function Canonical-Json([object]$value) { return ($value | ConvertTo-Json -Depth 100 -Compress) }
function Sha256-Text([string]$text) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($text)))).Replace("-", "").ToLowerInvariant() }
    finally { $sha.Dispose() }
}
function Sha256-File([string]$path) { return (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant() }
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
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue }
    }
}
function Fail([string]$code, [string]$message, [string]$fieldPath = "", [string]$suggestion = "") {
    $errorObject = New-Object System.Exception($message)
    $errorObject.Data["cm2Code"] = $code
    $errorObject.Data["cm2FieldPath"] = $fieldPath
    $errorObject.Data["cm2Suggestion"] = $suggestion
    throw $errorObject
}
function Require([bool]$condition, [string]$code, [string]$message, [string]$fieldPath = "", [string]$suggestion = "") {
    if (-not $condition) { Fail $code $message $fieldPath $suggestion }
}
function Ensure-Property([object]$object, [string]$name, [object]$value) {
    if ($null -eq $object.PSObject.Properties[$name]) { $object | Add-Member -NotePropertyName $name -NotePropertyValue $value }
}
function Remove-Property([object]$object, [string]$name) {
    if ($null -ne $object.PSObject.Properties[$name]) { $object.PSObject.Properties.Remove($name) }
}
function Get-Major([string]$version) {
    if ($version -notmatch '/(-?\d+)$') { Fail "unsupported-version" ("Unparseable schema: " + $version) "schemaVersion" "Use a published schema version." }
    return [int]$Matches[1]
}
function Add-Warning([string]$code, [string]$field, [string]$message) {
    [void]$script:warnings.Add([ordered]@{
        level = "warning"; code = $code; packageId = $script:packageId; definitionId = $script:definitionId
        fieldPath = $field; message = $message
    })
}
function Test-SensitiveUnknown([string]$name) {
    return ($name -match '(?i)script|lua|network|engine.?handle|file.?path|runtime.?entry')
}
function Move-UnknownRuntime([object]$document, [string[]]$allowed) {
    $unknown = [ordered]@{}
    foreach ($property in @($document.runtime.PSObject.Properties)) {
        if ($property.Name -in $allowed) { continue }
        if (Test-SensitiveUnknown $property.Name) {
            Fail "security-sensitive-unknown" ("Security-sensitive Runtime field is not migratable: " + $property.Name) ("runtime." + $property.Name) "Remove it or use an approved future schema."
        }
        if ($property.Name -match '(?i)required') {
            Fail "future-required" ("Unknown required Runtime field is not migratable: " + $property.Name) ("runtime." + $property.Name) "Use the matching future migration."
        }
        $unknown[$property.Name] = $property.Value
        Remove-Property $document.runtime $property.Name
        Add-Warning "unknown-optional" ("runtime." + $property.Name) "Moved unknown optional Runtime data outside Runtime projection."
    }
    if ($unknown.Count -gt 0) {
        Ensure-Property $document.editor "compatibility" ([pscustomobject]@{})
        Ensure-Property $document.editor.compatibility "unknownRuntimeFields" ([pscustomobject]@{})
        foreach ($key in $unknown.Keys) { Ensure-Property $document.editor.compatibility.unknownRuntimeFields $key $unknown[$key] }
    }
}
function Get-SourceDescriptor([string]$kind) {
    $catalog = Get-Content -Raw -LiteralPath $schemaPath | ConvertFrom-Json
    $descriptor = @(@($catalog.definitions) + @($catalog.supplementalDefinitions) | Where-Object { [string]$_.kind -eq $kind })
    Require ($descriptor.Count -eq 1) "unsupported-version" ("No canonical v1 schema for kind: " + $kind) "kind" "Use a published source schema."
    return $descriptor[0]
}
function Complete-And-ValidateSource([object]$document) {
    $descriptor = Get-SourceDescriptor ([string]$document.kind)
    Require ([string]$document.schemaVersion -eq [string]$descriptor.schemaVersion) "unsupported-version" "Source schema does not match its kind" "schemaVersion" ("Use " + [string]$descriptor.schemaVersion + ".")
    $allowed = @($descriptor.fields | ForEach-Object { ([string]$_.path).Substring("runtime.".Length) })
    Move-UnknownRuntime $document $allowed
    foreach ($field in @($descriptor.fields | Where-Object { [bool]$_.runtimeRequired })) {
        $name = ([string]$field.path).Substring("runtime.".Length)
        Require ($null -ne $document.runtime.PSObject.Properties[$name] -and $null -ne $document.runtime.$name -and [string]$document.runtime.$name -ne "") "missing-required" ("Required canonical Runtime field is missing: " + $name) ([string]$field.path) "Populate the field before migration."
    }
}
function Migrate-Source([object]$document) {
    $script:definitionId = [string]$document.id
    Require ([string]$document.id -ne "") "missing-required" "Source definition id is required" "id" "Add a canonical namespaced id."
    Require ([string]$document.kind -ne "") "missing-required" "Source definition kind is required" "kind" "Declare the v1 kind."
    Require ($null -ne $document.runtime) "missing-required" "Runtime section is required" "runtime" "Add the Runtime envelope."
    Ensure-Property $document "editor" ([pscustomobject]@{})
    Ensure-Property $document "ai" ([pscustomobject]@{})
    Ensure-Property $document "build" ([pscustomobject]@{})
    $kind = [string]$document.kind
    $major = Get-Major ([string]$document.schemaVersion)
    if ($major -gt 1) { Fail "future-required" "Future schema major is not readable" "schemaVersion" "Use a published future migration." }
    if ($major -lt 0) { Fail "unsupported-version" "Schema is older than the supported window" "schemaVersion" "Upgrade through a supported major-0 source." }
    if ($major -eq 0) {
        switch ($kind) {
            "effect" {
                if ($null -eq $document.runtime.PSObject.Properties["effectType"] -and $null -ne $document.runtime.PSObject.Properties["type"]) { $document.runtime | Add-Member effectType ([string]$document.runtime.type) }
                if ($null -eq $document.runtime.PSObject.Properties["assetId"] -and $null -ne $document.runtime.PSObject.Properties["asset"]) { $document.runtime | Add-Member assetId ([string]$document.runtime.asset) }
                if ($null -eq $document.runtime.PSObject.Properties["priority"]) { $document.runtime | Add-Member priority 50 }
                Remove-Property $document.runtime "type"
                Remove-Property $document.runtime "asset"
            }
            "weapon" {
                if ($null -eq $document.runtime.PSObject.Properties["behavior"] -and $null -ne $document.runtime.PSObject.Properties["behaviour"]) { $document.runtime | Add-Member behavior ([string]$document.runtime.behaviour) }
                if ($null -eq $document.runtime.PSObject.Properties["effectId"] -and $null -ne $document.runtime.PSObject.Properties["effect"]) { $document.runtime | Add-Member effectId ([string]$document.runtime.effect) }
                if ($null -eq $document.runtime.PSObject.Properties["fireRateHz"]) { $document.runtime | Add-Member fireRateHz 1 }
                Remove-Property $document.runtime "behaviour"
                Remove-Property $document.runtime "effect"
            }
            default { Fail "unsupported-version" ("No major-0 adapter for kind: " + $kind) "kind" "Add an explicit migration." }
        }
        $document.schemaVersion = "cm2.$kind/1"
        Ensure-Property $document.build "migratedFrom" ("cm2.$kind/0")
        $document.build.migratedFrom = "cm2.$kind/0"
        Add-Warning "deprecated-alias" "schemaVersion" ("Migrated cm2." + $kind + "/0 to canonical v1.")
    }
    Complete-And-ValidateSource $document
    return $document
}
function Move-UnknownPackage([object]$document) {
    $known = @(
        "packageId", "packageVersion", "schemaVersion", "displayName", "author", "license", "coreApiVersionRange",
        "sdkVersionRange", "buildFormatVersion", "capabilities", "entrypoints", "contentEntries", "assetEntries",
        "generatedEntries", "dependencies", "optionalDependencies", "files", "budget", "signature", "provenance"
    )
    $unknown = [ordered]@{}
    foreach ($property in @($document.PSObject.Properties)) {
        if ($property.Name -in $known) { continue }
        if ($property.Name -eq "runtimeLua") {
            if ([bool]$property.Value) { Fail "security-sensitive-unknown" "Runtime Lua cannot be migrated into a data-only package" "runtimeLua" "Remove Runtime Lua and expose data-only capabilities." }
            Remove-Property $document $property.Name
            Add-Warning "deprecated-alias" "runtimeLua" "Removed the obsolete false Runtime Lua marker."
            continue
        }
        if (Test-SensitiveUnknown $property.Name) { Fail "security-sensitive-unknown" ("Security-sensitive Package field is not migratable: " + $property.Name) $property.Name "Remove it or use an approved future schema." }
        if ($property.Name -match '(?i)required') { Fail "future-required" ("Unknown required Package field is not migratable: " + $property.Name) $property.Name "Use the matching future migration." }
        $unknown[$property.Name] = $property.Value
        Remove-Property $document $property.Name
        Add-Warning "unknown-optional" $property.Name "Moved unknown optional Package data under provenance.compatibility."
    }
    if ($unknown.Count -gt 0) {
        Ensure-Property $document.provenance "compatibility" ([pscustomobject]@{})
        Ensure-Property $document.provenance.compatibility "unknownPackageFields" ([pscustomobject]@{})
        foreach ($key in $unknown.Keys) { Ensure-Property $document.provenance.compatibility.unknownPackageFields $key $unknown[$key] }
    }
}
function Migrate-Package([object]$document) {
    $script:packageId = [string]$document.packageId
    Require ([string]$document.packageId -ne "") "missing-required" "Package ID is required" "packageId" "Add a canonical packageId."
    $major = Get-Major ([string]$document.schemaVersion)
    if ($major -gt 1) { Fail "future-required" "Future package schema is not readable" "schemaVersion" "Use a published future migration." }
    if ($major -lt 0) { Fail "unsupported-version" "Package schema is outside the migration window" "schemaVersion" "Upgrade through a supported package release." }
    Ensure-Property $document "provenance" ([pscustomobject]@{})
    if ($major -eq 0) {
        $document.schemaVersion = "cm2.package/1"
        Ensure-Property $document "buildFormatVersion" "cm2.package-build/1"
        Ensure-Property $document "coreApiVersionRange" ">=1.0.0 <2.0.0"
        Ensure-Property $document "sdkVersionRange" ">=1.0.0 <2.0.0"
        Ensure-Property $document "entrypoints" ([ordered]@{ runtime = "data-only"; preview = "cm2.preview/1"; lua = $null })
        Ensure-Property $document.provenance "migratedFrom" "cm2.package/0"
        $document.provenance.migratedFrom = "cm2.package/0"
        Add-Warning "deprecated-alias" "schemaVersion" "Migrated cm2.package/0 to canonical cm2.package/1."
    }
    Require ([string]$document.schemaVersion -eq "cm2.package/1") "unsupported-version" "Package writer only emits cm2.package/1" "schemaVersion" "Use the published migration."
    Require ([string]$document.packageVersion -match '^\d+\.\d+\.\d+$') "missing-required" "Package version must be semantic version" "packageVersion" "Add packageVersion x.y.z."
    Require ([string]$document.buildFormatVersion -eq "cm2.package-build/1") "unsupported-version" "Unsupported build format" "buildFormatVersion" "Rebuild with cm2.package-build/1."
    Require ([string]$document.entrypoints.runtime -eq "data-only" -and $null -eq $document.entrypoints.lua) "security-sensitive-unknown" "Migrated packages must remain data-only" "entrypoints" "Set runtime=data-only and lua=null."
    Move-UnknownPackage $document
    return $document
}

try {
    Require (Test-Path -LiteralPath $InputPath -PathType Leaf) "input-missing" "Input file does not exist" "input" "Provide a source/package JSON file."
    $inputFull = [IO.Path]::GetFullPath($InputPath)
    $outputFull = [IO.Path]::GetFullPath($OutputPath)
    $reportFull = [IO.Path]::GetFullPath($ReportPath)
    Require ($inputFull -ne $outputFull -and $inputFull -ne $reportFull -and $outputFull -ne $reportFull) "input-mutation" "Input, output and report paths must be distinct" "OutputPath" "Write migration artifacts to distinct files."
    $sourceText = [IO.File]::ReadAllText($inputFull)
    $sourceHash = Sha256-File $inputFull
    $document = $sourceText | ConvertFrom-Json
    $copy = Canonical-Json $document | ConvertFrom-Json
    $sourceSchemaVersion = [string]$copy.schemaVersion
    $isPackage = ($null -ne $copy.PSObject.Properties["packageId"] -and $sourceSchemaVersion -match '^cm2\.package/')
    $migrated = if ($isPackage) { Migrate-Package $copy } else { Migrate-Source $copy }
    $output = Canonical-Json $migrated
    $outputHash = Sha256-Text $output
    Require ((Sha256-File $inputFull) -eq $sourceHash) "input-mutation" "Migration changed its input" "InputPath" "Restore immutable source handling."
    $report = [ordered]@{
        schema = "cm2.compatibility-migration-report/1"
        policyHash = Sha256-File $policyPath
        schemaCatalogHash = Sha256-File $schemaPath
        migration = if ($sourceSchemaVersion -match '/0$') { if ($isPackage) { "cm2.package/0-to-1" } else { "cm2.source-envelope/0-to-1" } } else { "canonical-v1-rewrite" }
        sourceSchemaVersion = $sourceSchemaVersion
        targetSchemaVersion = [string]$migrated.schemaVersion
        inputHash = $sourceHash
        outputHash = $outputHash
        warnings = $script:warnings.ToArray()
        idempotent = $true
        singleWrite = $true
        canonicalAliasesRemoved = $true
        inputMutated = $false
        result = "pass"
    }
    Write-TextAtomic $outputFull $output
    Write-TextAtomic $reportFull (Canonical-Json $report)
    Write-Output (Canonical-Json $report)
    exit 0
}
catch {
    $exception = $_.Exception
    $errorReport = [ordered]@{
        schema = "cm2.compatibility-error/1"
        code = if ($exception.Data["cm2Code"]) { [string]$exception.Data["cm2Code"] } else { "migration-error" }
        packageId = $script:packageId
        definitionId = $script:definitionId
        fieldPath = if ($exception.Data["cm2FieldPath"]) { [string]$exception.Data["cm2FieldPath"] } else { "" }
        message = $exception.Message
        suggestion = if ($exception.Data["cm2Suggestion"]) { [string]$exception.Data["cm2Suggestion"] } else { "Run an explicit supported migration." }
        result = "fail"
    }
    Write-Output (Canonical-Json $errorReport)
    exit 1
}
