# Content Mod 2 deterministic Definition Compiler MVP.
# This is an out-of-band compiler; it does not replace the current legacy catalog.

param(
    [Parameter(Mandatory = $true)][string]$InputPath,
    [Parameter(Mandatory = $true)][string]$OutputPath,
    [string]$ManifestPath = "",
    [string]$ReportPath = "",
    [string]$HumanReportPath = "",
    [string]$SchemaPath = ""
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if ($ManifestPath -eq "") { $ManifestPath = [IO.Path]::ChangeExtension($OutputPath, ".manifest.json") }
if ($ReportPath -eq "") { $ReportPath = [IO.Path]::ChangeExtension($OutputPath, ".report.json") }
if ($HumanReportPath -eq "") { $HumanReportPath = [IO.Path]::ChangeExtension($OutputPath, ".diagnostics.md") }
if ($SchemaPath -eq "") { $SchemaPath = Join-Path $root "schemas\cm2\source-envelope-v1.json" }
$invariant = [Globalization.CultureInfo]::InvariantCulture
$diagnostics = New-Object System.Collections.Generic.List[object]

function Add-Diagnostic([string]$severity, [string]$code, [string]$id, [string]$fieldPath, [string]$expected, [string]$actual, [string]$suggestion) {
    $diagnostics.Add([ordered]@{ severity=$severity; code=$code; id=$id; fieldPath=$fieldPath; expected=$expected; actual=$actual; suggestion=$suggestion })
}

function Get-JsonFiles([string]$path) {
    if (Test-Path -LiteralPath $path -PathType Leaf) { return @((Get-Item -LiteralPath $path)) }
    if (Test-Path -LiteralPath $path -PathType Container) {
        return @(Get-ChildItem -LiteralPath $path -File -Filter "*.json" |
            Where-Object { $_.Name -ne "resources.json" -and $_.Name -notmatch '\.(report|manifest)\.json$' } |
            Sort-Object FullName)
    }
    throw "authoring input does not exist: $path"
}

function Get-SourceRecords([IO.FileInfo[]]$files) {
    $records = New-Object System.Collections.Generic.List[object]
    foreach ($file in $files) {
        try { $document = Get-Content -Raw -LiteralPath $file.FullName | ConvertFrom-Json }
        catch { Add-Diagnostic "error" "invalid-json" "<file>" $file.Name "valid JSON" $_.Exception.Message "Fix the authoring JSON before compiling."; continue }
        if ($null -ne $document.definitions) { foreach ($entry in @($document.definitions)) { [void]$records.Add($entry) } }
        elseif ($null -ne $document.bases) { foreach ($entry in @($document.bases)) { [void]$records.Add($entry) } }
        elseif ($document -is [Array]) { foreach ($entry in @($document)) { [void]$records.Add($entry) } }
        else { [void]$records.Add($document) }
    }
    return $records.ToArray()
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

function Is-Number($value) { return ($null -ne $value -and $value -is [ValueType] -and $value -isnot [bool] -and $value -isnot [char]) }

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

function ConvertTo-LuaString([string]$value) {
    return '"' + $value.Replace('\', '\\').Replace('"', '\"').Replace("`r", '\r').Replace("`n", '\n') + '"'
}

function ConvertTo-Lua($value) {
    if ($null -eq $value) { return "nil" }
    if ($value -is [bool]) { return ([string]$value).ToLowerInvariant() }
    if ($value -is [string]) { return ConvertTo-LuaString $value }
    if (Is-Number $value) { return ([double]$value).ToString("0.################", $invariant) }
    if ($value -is [Array]) {
        $items = @($value | ForEach-Object { ConvertTo-Lua $_ })
        return "{" + ($items -join ",") + "}"
    }
    if ($value -is [System.Collections.IDictionary]) {
        $pairs = New-Object System.Collections.Generic.List[string]
        foreach ($key in @($value.Keys | Sort-Object)) {
            $keyText = if ([string]$key -match '^[A-Za-z_][A-Za-z0-9_]*$') { [string]$key } else { "[" + (ConvertTo-LuaString ([string]$key)) + "]" }
            [void]$pairs.Add($keyText + "=" + (ConvertTo-Lua $value[$key]))
        }
        return "{" + ($pairs -join ",") + "}"
    }
    $pairs = New-Object System.Collections.Generic.List[string]
    foreach ($property in @($value.PSObject.Properties | Sort-Object Name)) {
        $key = [string]$property.Name
        if ($key -match '^[A-Za-z_][A-Za-z0-9_]*$') { $keyText = $key } else { $keyText = "[" + (ConvertTo-LuaString $key) + "]" }
        [void]$pairs.Add($keyText + "=" + (ConvertTo-Lua $property.Value))
    }
    return "{" + ($pairs -join ",") + "}"
}

function Get-Sha256([byte[]]$bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return (($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") }) -join "") }
    finally { $sha.Dispose() }
}

function Publish-Atomic([string]$text, [string]$path) {
    $path = [IO.Path]::GetFullPath($path)
    $parent = Split-Path -Parent $path
    if ($parent -ne "") { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $temp = $path + ".tmp." + [Guid]::NewGuid().ToString("N")
    [IO.File]::WriteAllText($temp, $text, (New-Object Text.UTF8Encoding($false)))
    # Windows PowerShell/.NET on supported workstations does not expose a
    # usable File.Replace overload for every filesystem provider. A same-
    # directory Move-Item -Force keeps the temporary file beside the target
    # and makes the publish operation a single rename from the compiler's
    # perspective; no target is touched before this point.
    try { Move-Item -LiteralPath $temp -Destination $path -Force }
    finally {
        if (Test-Path -LiteralPath $temp -PathType Leaf) { Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue }
    }
}

try {
    $schema = Get-Content -Raw -LiteralPath $SchemaPath | ConvertFrom-Json
    $descriptorByKind = @{}
    foreach ($descriptor in @($schema.definitions)) { $descriptorByKind[[string]$descriptor.kind] = $descriptor }
    $files = Get-JsonFiles $InputPath
    $records = Get-SourceRecords $files
    $sourceParts = New-Object System.Collections.Generic.List[string]
    $sourceBase = if (Test-Path -LiteralPath $InputPath -PathType Container) { (Resolve-Path -LiteralPath $InputPath).Path } else { (Resolve-Path -LiteralPath (Split-Path -Parent $InputPath)).Path }
    foreach ($file in $files) {
        $relative = $file.FullName.Substring($sourceBase.Length).TrimStart('\')
        [void]$sourceParts.Add($relative + "`n" + (Get-Content -Raw -LiteralPath $file.FullName))
    }
    $inputHash = Get-Sha256 ([Text.Encoding]::UTF8.GetBytes((($sourceParts | Sort-Object) -join "`n")))
    $resourceMap = @{}
    $resourceFile = if (Test-Path -LiteralPath $InputPath -PathType Container) { Join-Path $InputPath "resources.json" } else { "" }
    if ($resourceFile -ne "" -and (Test-Path -LiteralPath $resourceFile -PathType Leaf)) {
        $resourceDocument = Get-Content -Raw -LiteralPath $resourceFile | ConvertFrom-Json
        foreach ($resource in @($resourceDocument.resources)) { $resourceMap[[string]$resource.id] = [string]$resource.path }
    }
    $idKind = @{}
    foreach ($record in $records) {
        $id = [string]$record.id
        if ($id -notmatch '^[a-z0-9][a-z0-9._-]{0,63}:[a-z0-9][a-z0-9._-]{0,127}$') { Add-Diagnostic "error" "invalid-id" $id "id" "lowercase packageId:local-id" $id "Use a canonical namespaced ID."; continue }
        if ($idKind.ContainsKey($id)) { Add-Diagnostic "error" "duplicate-id" $id "id" "unique ID" $id "Rename one definition; duplicate IDs cannot be compiled." }
        else { $idKind[$id] = [string]$record.kind }
    }
    foreach ($record in $records) {
        $id = [string]$record.id; $kind = [string]$record.kind
        $descriptor = $descriptorByKind[$kind]
        if ($null -eq $descriptor) { Add-Diagnostic "error" "unknown-kind" $id "kind" "v1 catalog kind" $kind "Add a schema descriptor before using this kind."; continue }
        $expectedSchema = "cm2.$kind/1"
        if ([string]$record.schemaVersion -ne $expectedSchema) { Add-Diagnostic "error" "version-mismatch" $id "schemaVersion" $expectedSchema ([string]$record.schemaVersion) "Run an explicit migration or use schema major 1." }
        foreach ($section in @("runtime", "editor", "ai", "build")) {
            if ($null -eq $record.PSObject.Properties[$section]) { Add-Diagnostic "error" "missing-envelope" $id $section "object" "missing" "Add the complete source envelope." }
        }
        if ($null -eq $record.runtime) { continue }
        foreach ($field in @($descriptor.fields)) {
            $value = Get-PathValue $record ([string]$field.path)
            if ($field.runtimeRequired -and $null -eq $value) { Add-Diagnostic "error" "missing-field" $id $field.path "required $($field.type)" "missing" "Provide the required runtime field."; continue }
            if ($null -eq $value) { continue }
            switch ([string]$field.type) {
                "id" {
                    if ($value -isnot [string]) { Add-Diagnostic "error" "wrong-type" $id $field.path "canonical ID" ($value.GetType().Name) "Use a namespaced string ID." }
                    elseif ([string]$field.referenceKind -and ([string]$value -notin $idKind.Keys) -and ([string]$value -notin $resourceMap.Keys)) { Add-Diagnostic "error" "broken-reference" $id $field.path ([string]$field.referenceKind) ([string]$value) "Add the target or correct the reference." }
                }
                "enum" { if ($value -isnot [string] -or [string]$value -notin ([string]$field.range).Split('|')) { Add-Diagnostic "error" "invalid-enum" $id $field.path ([string]$field.range) ([string]$value) "Use a declared v1 enum value." } }
                "number" {
                    if (-not (Is-Number $value)) { Add-Diagnostic "error" "wrong-type" $id $field.path ([string]$field.range) ($value.GetType().Name) "Use a numeric value with the declared unit." }
                    elseif (-not (Test-Range $kind ([string]$field.path) $value)) { Add-Diagnostic "error" "out-of-range" $id $field.path ([string]$field.range) ([string]$value) "Clamp the value to the v1 range." }
                }
                "object" { if ($value -is [Array] -or $value -is [string] -or $value -is [ValueType]) { Add-Diagnostic "error" "wrong-type" $id $field.path "object" ($value.GetType().Name) "Provide a structured object." } }
            }
        }
        if ($null -ne $record.build.budgetClass -and [string]$record.build.budgetClass -notin @("standard", "visual", "ship", "anchor", "turret")) { Add-Diagnostic "warning" "unknown-budget-class" $id "build.budgetClass" "known budget class" ([string]$record.build.budgetClass) "Use a declared budget class or document an extension." }
    }
    foreach ($resourceId in @($resourceMap.Keys)) {
        $resourceRoot = if (Test-Path -LiteralPath $InputPath -PathType Container) { $InputPath } else { Split-Path -Parent $InputPath }
        $resourcePath = Join-Path $resourceRoot $resourceMap[$resourceId]
        if (-not (Test-Path -LiteralPath $resourcePath -PathType Leaf)) { Add-Diagnostic "error" "missing-resource" $resourceId "resource.path" "existing file" $resourceMap[$resourceId] "Add the resource or correct the relative path." }
    }
    $errors = @($diagnostics | Where-Object { $_.severity -eq "error" })
    $report = [ordered]@{ schemaVersion="cm2.compiler-report/1"; inputHash=$inputHash; errors=@($errors); warnings=@($diagnostics | Where-Object { $_.severity -eq "warning" }); definitionCount=$records.Count }
    Publish-Atomic (($report | ConvertTo-Json -Depth 20) + "`n") $ReportPath
    $humanLines = New-Object System.Collections.Generic.List[string]
    [void]$humanLines.Add("# CM2 Definition Compiler MVP diagnostics")
    [void]$humanLines.Add("")
    [void]$humanLines.Add(("- Input SHA-256: " + '`' + $inputHash + '`'))
    [void]$humanLines.Add("- Definitions: $($records.Count)")
    if ($diagnostics.Count -eq 0) { [void]$humanLines.Add("- Result: PASS") }
    else {
        [void]$humanLines.Add("- Result: " + $(if ($errors.Count -gt 0) { "FAIL" } else { "PASS with warnings" }))
        [void]$humanLines.Add("")
        [void]$humanLines.Add("| Severity | Code | ID | Field | Expected | Actual | Suggestion |")
        [void]$humanLines.Add("|---|---|---|---|---|---|---|")
        foreach ($diagnostic in $diagnostics.ToArray()) {
            [void]$humanLines.Add("| $($diagnostic.severity) | $($diagnostic.code) | $($diagnostic.id) | $($diagnostic.fieldPath) | $($diagnostic.expected) | $($diagnostic.actual) | $($diagnostic.suggestion) |")
        }
    }
    Publish-Atomic (($humanLines -join "`n") + "`n") $HumanReportPath
    if ($errors.Count -gt 0) {
        Write-Host ("Compiler failed with $($errors.Count) error(s). Report: $ReportPath") -ForegroundColor Red
        exit 1
    }
    $runtimeRecords = @($records | Sort-Object { [string]$_.id } | ForEach-Object {
        [ordered]@{ id=[string]$_.id; kind=[string]$_.kind; schemaVersion=[string]$_.schemaVersion; runtime=$_.runtime }
    })
    $body = ($runtimeRecords | ForEach-Object { "[" + (ConvertTo-LuaString $_.id) + "]=" + (ConvertTo-Lua $_) }) -join ",`n  "
    $header = "-- CM2 GENERATED FILE; DO NOT EDIT.`n-- Source: Content Mod 2 Definition Compiler MVP.`n-- Input SHA-256: $inputHash`nreturn {`n  "
    $catalogText = $header + $body + "`n}`n"
    $catalogHash = Get-Sha256 ([Text.Encoding]::UTF8.GetBytes($catalogText))
    $manifest = [ordered]@{ schemaVersion="cm2.generated-manifest/1"; compiler="cm2-definition-compiler-mvp"; inputHash=$inputHash; catalogHash=$catalogHash; definitionCount=$records.Count; sourceFiles=@($files | ForEach-Object { $_.Name } | Sort-Object); manualEdit="forbidden" }
    Publish-Atomic $catalogText $OutputPath
    Publish-Atomic (($manifest | ConvertTo-Json -Depth 20) + "`n") $ManifestPath
    Write-Host "Compiler succeeded: $($records.Count) definitions, catalog SHA-256 $catalogHash." -ForegroundColor Green
    exit 0
}
catch {
    Add-Diagnostic "error" "compiler-exception" "<compiler>" "compiler" "successful compilation" $_.Exception.Message "Fix the compiler input or tool error; previous catalog was not replaced."
    $fallback = [ordered]@{ schemaVersion="cm2.compiler-report/1"; errors=$diagnostics.ToArray(); warnings=@(); definitionCount=0 }
    try {
        Publish-Atomic (($fallback | ConvertTo-Json -Depth 20) + "`n") $ReportPath
        Publish-Atomic ("# CM2 Definition Compiler MVP diagnostics`n`n- Result: FAIL`n- Error: $($_.Exception.Message)`n") $HumanReportPath
    } catch { }
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
