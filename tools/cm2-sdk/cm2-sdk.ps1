# Creator SDK CLI Alpha v1.
# A project-root-driven, data-only authoring boundary. Every project command
# consumes ProjectPath/package.source.json, uses the public PackageManifest
# validator and shared Definition Compiler, and never writes Runtime Lua.

param(
    [ValidateSet("init", "new", "validate", "build", "explain", "preview", "test", "package", "migrate", "doctor", "clean")][string]$Command = "doctor",
    [string]$ProjectPath = "",
    [string]$OutputPath = "",
    [string]$FixturePath = "",
    [string]$SdkFixturePath = ""
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if ($script:SdkFixturePath -eq "") { $script:SdkFixturePath = Join-Path $root "docs\candidates\sdk-cli-v1.fixture.json" }
$sdkFixture = Get-Content -Raw -LiteralPath $script:SdkFixturePath | ConvertFrom-Json
$toolVersion = [string]$sdkFixture.toolVersion
$utf8 = New-Object Text.UTF8Encoding($false)
$script:packageId = ""
$script:projectRoot = $null

function Fail([string]$code, [string]$message, [string]$packageId = "", [string]$definitionId = "", [string]$fieldPath = "", [string]$suggestion = "") {
    $exception = New-Object System.Exception($message)
    $exception.Data["cm2Code"] = $code
    $exception.Data["cm2PackageId"] = $packageId
    $exception.Data["cm2DefinitionId"] = $definitionId
    $exception.Data["cm2FieldPath"] = $fieldPath
    $exception.Data["cm2Suggestion"] = $suggestion
    throw $exception
}
function Require([bool]$condition, [string]$code, [string]$message, [string]$packageId = "", [string]$definitionId = "", [string]$fieldPath = "", [string]$suggestion = "") {
    if (-not $condition) { Fail $code $message $packageId $definitionId $fieldPath $suggestion }
}
function Canonical-Json([object]$value) { return ($value | ConvertTo-Json -Depth 100 -Compress) }
function Copy-Json([object]$value) { return (Canonical-Json $value | ConvertFrom-Json) }
function Read-Json([string]$path) { return Get-Content -Raw -LiteralPath $path | ConvertFrom-Json }
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
    finally { if (Test-Path -LiteralPath $temporary -PathType Leaf) { Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue } }
}
function Write-Json([string]$path, [object]$value) { Write-TextAtomic $path (Canonical-Json $value) }
function Resolve-Rooted([string]$path) {
    if ([IO.Path]::IsPathRooted($path)) { return [IO.Path]::GetFullPath($path) }
    return [IO.Path]::GetFullPath((Join-Path (Get-Location).Path $path))
}
function Test-Within([string]$path, [string]$parent) {
    $child = [IO.Path]::GetFullPath($path).TrimEnd("\", "/")
    $rootedParent = [IO.Path]::GetFullPath($parent).TrimEnd("\", "/")
    return $child.Equals($rootedParent, [StringComparison]::OrdinalIgnoreCase) -or $child.StartsWith($rootedParent + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
}
function Get-ProjectRoot([bool]$required = $true) {
    if ($null -ne $script:projectRoot) { return $script:projectRoot }
    if ($script:ProjectPath -eq "") {
        if ($required) { Fail "project-required" "ProjectPath is required for this SDK command" "" "" "ProjectPath" "Pass the root created by cm2-sdk init." }
        return $null
    }
    $candidate = Resolve-Rooted $script:ProjectPath
    Require (Test-Path -LiteralPath $candidate -PathType Container) "project-missing" "Creator project root does not exist" "" "" "ProjectPath" "Run cm2-sdk init or select an existing project root."
    $script:projectRoot = (Resolve-Path -LiteralPath $candidate).Path
    return $script:projectRoot
}
function Get-ProjectSourcePath {
    if ($script:FixturePath -ne "") {
        $fixture = Resolve-Rooted $script:FixturePath
        Require (Test-Path -LiteralPath $fixture -PathType Leaf) "fixture-missing" "Explicit package fixture is missing" "" "" "FixturePath" "Select an existing fixture."
        return $fixture
    }
    $project = Get-ProjectRoot
    $source = Join-Path $project "package.source.json"
    Require (Test-Path -LiteralPath $source -PathType Leaf) "project-source-missing" "package.source.json is missing" "" "" "package.source.json" "Restore the project package source or rerun init in a clean root."
    return $source
}
function Get-SourceRelativePath([string]$uri, [string]$packageId) {
    $prefix = "pkg://" + $packageId + "/"
    Require ($uri.StartsWith($prefix, [StringComparison]::Ordinal)) "unsafe-path" "Package source URI does not use its package namespace" $packageId "" "source" "Use pkg://<packageId>/<relative-path>."
    $relative = $uri.Substring($prefix.Length).Replace("/", [IO.Path]::DirectorySeparatorChar)
    Require ($relative -ne "" -and $relative -notmatch '(^|[\\/])\.\.([\\/]|$)' -and -not [IO.Path]::IsPathRooted($relative)) "unsafe-path" "Package source URI escapes the project" $packageId "" "source" "Use a project-relative source path."
    return $relative
}
function Assert-ToolLock([bool]$checkProject = $true) {
    Require ([string]$sdkFixture.toolVersion -eq "cm2.sdk-cli/1.0.0-alpha.1") "tool-version" "SDK tool version is not supported" "" "" "toolVersion" "Install the locked SDK CLI alpha version."
    foreach ($tool in @($sdkFixture.toolLock.tools)) { Require ([string]$tool.name -ne "" -and [string]$tool.version -ne "") "tool-version" "SDK tool lock entry is incomplete" "" "" "toolLock" "Restore the pinned SDK tool lock." }
    if (-not $checkProject -or $script:ProjectPath -eq "") { return }
    $project = Get-ProjectRoot
    $lockPath = Join-Path $project "sdk.tool-lock.json"
    Require (Test-Path -LiteralPath $lockPath -PathType Leaf) "tool-version" "Project SDK tool lock is missing" "" "" "sdk.tool-lock.json" "Restore the lock generated by init."
    $actual = Canonical-Json (Read-Json $lockPath)
    $expected = Canonical-Json $sdkFixture.toolLock
    Require ($actual -ceq $expected) "tool-version" "Project SDK tool lock differs from the installed alpha toolchain" "" "" "sdk.tool-lock.json" "Restore the exact pinned tool versions or migrate explicitly."
}
function Assert-DataOnlyProject([string]$project, [object]$fixture) {
    $paths = New-Object System.Collections.Generic.List[string]
    foreach ($file in @($fixture.manifest.files)) { [void]$paths.Add([string]$file.path) }
    foreach ($relative in $paths.ToArray()) {
        Require ($relative -notmatch '\.lua$') "runtime-lua-forbidden" "Data-only package declares a Lua file" ([string]$fixture.manifest.packageId) "" "manifest.files" "Remove Runtime Lua from the public package."
        $full = [IO.Path]::GetFullPath((Join-Path $project $relative))
        Require (Test-Within $full $project) "unsafe-path" "Package file escapes ProjectPath" ([string]$fixture.manifest.packageId) "" "manifest.files" "Use project-relative package files."
        Require (Test-Path -LiteralPath $full -PathType Leaf) "missing-source" ("Package source file is missing: " + $relative) ([string]$fixture.manifest.packageId) "" $relative "Restore the declared source file."
        $text = Get-Content -Raw -LiteralPath $full
        foreach ($forbidden in @("Content Mod 2", "Global Mod", "file://", "include(", "dofile(", "loadfile(")) {
            Require (-not $text.Contains($forbidden)) "private-reference" ("Public package source references a private/runtime path: " + $forbidden) ([string]$fixture.manifest.packageId) "" $relative "Use only public schema IDs and package-local resources."
        }
    }
}
function Write-HydratedFixture([string]$path) {
    $sourcePath = Get-ProjectSourcePath
    $source = Read-Json $sourcePath
    Require ([string]$source.schema -eq "cm2.package-manifest/1") "project-source-invalid" "Project package source schema is invalid" "" "" "package.source.json" "Use cm2.package-manifest/1."
    if ($script:FixturePath -ne "" -and $script:ProjectPath -eq "") {
        Write-Json $path $source
        return $source
    }
    $project = Get-ProjectRoot
    Assert-DataOnlyProject $project $source
    $document = Copy-Json $source
    $script:packageId = [string]$document.manifest.packageId
    $fileMap = @{}
    foreach ($file in @($document.manifest.files)) {
        $relative = [string]$file.path
        $full = [IO.Path]::GetFullPath((Join-Path $project $relative))
        Require (Test-Within $full $project) "unsafe-path" "Package file escapes ProjectPath" $script:packageId "" "manifest.files" "Use a project-relative file."
        Require (Test-Path -LiteralPath $full -PathType Leaf) "missing-source" ("Package source file is missing: " + $relative) $script:packageId "" $relative "Restore the declared source file."
        $hash = Sha256-File $full
        $file.hash = $hash
        $fileMap[$relative.Replace("\", "/")] = $hash
    }
    foreach ($entry in @($document.manifest.contentEntries) + @($document.manifest.assetEntries) + @($document.manifest.generatedEntries)) {
        $relative = (Get-SourceRelativePath ([string]$entry.source) $script:packageId).Replace("\", "/")
        Require ($fileMap.ContainsKey($relative)) "missing-source" ("Manifest entry has no project file: " + [string]$entry.id) $script:packageId ([string]$entry.id) "source" "Add the source to manifest.files."
        $entry.hash = $fileMap[$relative]
    }
    $document.manifest.signature.value = "pending"
    Write-Json $path $document
    return $document
}
function Invoke-External([string]$scriptPath, [string[]]$arguments) {
    $saved = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath @arguments *> $null
    $code = [int]$LASTEXITCODE
    $ErrorActionPreference = $saved
    return $code
}
function Prepare-Package([string]$workRoot) {
    $fixturePath = Join-Path $workRoot "package.hydrated.json"
    $source = Write-HydratedFixture $fixturePath
    $script:packageId = [string]$source.manifest.packageId
    $reportPath = Join-Path $workRoot "package.report.json"
    $artifactPath = Join-Path $workRoot "package.artifact.json"
    $validator = Join-Path $root "tools\cm2-package\run-package-manifest-v1.ps1"
    Require (Test-Path -LiteralPath $validator -PathType Leaf) "tool-missing" "PackageManifest validator is missing" $script:packageId "" "validator" "Restore tools/cm2-package."
    $code = Invoke-External $validator @("-FixturePath", $fixturePath, "-ReportPath", $reportPath, "-ArtifactPath", $artifactPath)
    Require ($code -eq 0) "validate-failed" "PackageManifest validation failed" $script:packageId "manifest" "manifest" "Fix the package, dependency, capability, version, budget, or hash contract before building."
    return [pscustomobject]@{ fixturePath = $fixturePath; reportPath = $reportPath; artifactPath = $artifactPath; report = Read-Json $reportPath; artifact = Read-Json $artifactPath }
}
function Compile-Project([string]$workRoot) {
    if ($script:ProjectPath -eq "") { return [pscustomobject]@{ mode = "explicit-fixture"; definitionCount = 0; inputHash = "external"; catalogHash = "external" } }
    $project = Get-ProjectRoot
    $definitionRoot = Join-Path $project "definitions"
    Require (Test-Path -LiteralPath $definitionRoot -PathType Container) "definitions-missing" "Project definitions directory is missing" $script:packageId "" "definitions" "Add public source-envelope JSON definitions."
    $definitionFiles = @(Get-ChildItem -LiteralPath $definitionRoot -Recurse -File -Filter "*.json" | Sort-Object FullName)
    Require ($definitionFiles.Count -gt 0) "definitions-missing" "Project contains no source-envelope definitions" $script:packageId "" "definitions" "Add at least one public source-envelope JSON file."
    $compilerInput = Join-Path $workRoot "compiler-input"
    New-Item -ItemType Directory -Path $compilerInput -Force | Out-Null
    $index = 0
    foreach ($file in $definitionFiles) {
        $relative = $file.FullName.Substring($definitionRoot.Length).TrimStart("\", "/") -replace '[\\/]', '__'
        Write-TextAtomic (Join-Path $compilerInput (("{0:D3}__" -f $index) + $relative)) ([IO.File]::ReadAllText($file.FullName))
        $index++
    }
    $source = Read-Json (Get-ProjectSourcePath)
    $resources = New-Object System.Collections.Generic.List[object]
    $resourceIndex = 0
    foreach ($asset in @($source.manifest.assetEntries)) {
        $relative = Get-SourceRelativePath ([string]$asset.source) ([string]$source.manifest.packageId)
        $sourceFile = [IO.Path]::GetFullPath((Join-Path $project $relative))
        Require (Test-Within $sourceFile $project -and (Test-Path -LiteralPath $sourceFile -PathType Leaf)) "missing-resource" "Compiler resource is missing" $script:packageId ([string]$asset.id) "source" "Restore the project-local asset."
        $resourceRelative = "resources/" + (("{0:D3}-" -f $resourceIndex) + [IO.Path]::GetFileName($sourceFile))
        $resourceTarget = Join-Path $compilerInput $resourceRelative
        $resourceParent = Split-Path -Parent $resourceTarget
        if (-not (Test-Path -LiteralPath $resourceParent)) { New-Item -ItemType Directory -Path $resourceParent -Force | Out-Null }
        Copy-Item -LiteralPath $sourceFile -Destination $resourceTarget -Force
        [void]$resources.Add([ordered]@{ id = [string]$asset.id; path = $resourceRelative })
        $resourceIndex++
    }
    Write-Json (Join-Path $compilerInput "resources.json") ([ordered]@{ resources = $resources.ToArray() })
    $compiler = Join-Path $root "tools\cm2-compiler\compile-definitions.ps1"
    Require (Test-Path -LiteralPath $compiler -PathType Leaf) "tool-missing" "Shared Definition Compiler is missing" $script:packageId "" "compiler" "Restore tools/cm2-compiler."
    $catalogPath = Join-Path $workRoot "compiler.catalog.lua"
    $manifestPath = Join-Path $workRoot "compiler.manifest.json"
    $reportPath = Join-Path $workRoot "compiler.report.json"
    $humanPath = Join-Path $workRoot "compiler.diagnostics.md"
    $code = Invoke-External $compiler @("-InputPath", $compilerInput, "-OutputPath", $catalogPath, "-ManifestPath", $manifestPath, "-ReportPath", $reportPath, "-HumanReportPath", $humanPath)
    $report = if (Test-Path -LiteralPath $reportPath -PathType Leaf) { Read-Json $reportPath } else { $null }
    if ($code -ne 0) {
        $diagnostic = if ($null -ne $report -and @($report.errors).Count -gt 0) { @($report.errors)[0] } else { $null }
        $definitionId = if ($null -ne $diagnostic) { [string]$diagnostic.id } else { "" }
        $field = if ($null -ne $diagnostic) { [string]$diagnostic.fieldPath } else { "definitions" }
        $suggestion = if ($null -ne $diagnostic) { [string]$diagnostic.suggestion } else { "Inspect compiler.report.json and fix the public source envelope." }
        $diagnosticCode = if ($null -ne $diagnostic) { [string]$diagnostic.code } else { "compile-failed" }
        Fail "compile-failed" ("Shared Definition Compiler rejected the project: " + $diagnosticCode) $script:packageId $definitionId $field $suggestion
    }
    $compilerManifest = Read-Json $manifestPath
    return [pscustomobject]@{
        mode = "shared-compiler"
        definitionCount = [int]$report.definitionCount
        inputHash = [string]$report.inputHash
        catalogHash = [string]$compilerManifest.catalogHash
        manifestPath = $manifestPath
        reportPath = $reportPath
        humanPath = $humanPath
    }
}
function Run-Preview([string]$reportPath) {
    $preview = Join-Path $root "tools\cm2-preview\run-preview-suite-v1.ps1"
    Require (Test-Path -LiteralPath $preview -PathType Leaf) "tool-missing" "Preview builder is missing" $script:packageId "" "preview" "Restore tools/cm2-preview."
    $previewFixture = Resolve-Rooted ([string]$sdkFixture.previewFixture)
    Require (Test-Path -LiteralPath $previewFixture -PathType Leaf) "preview-fixture" "Preview fixture is missing" $script:packageId "" "previewFixture" "Provide the shared Preview fixture."
    $code = Invoke-External $preview @("-FixturePath", $previewFixture, "-ReportPath", $reportPath)
    Require ($code -eq 0) "preview-failed" "Preview builder failed" $script:packageId "" "preview" "Fix the shared Preview contract."
    return Read-Json $reportPath
}
function Get-SdkOutputRoot {
    if ($script:ProjectPath -ne "") { return Join-Path (Get-ProjectRoot) ".cm2-sdk" }
    if ($script:FixturePath -ne "") { return Join-Path (Split-Path -Parent (Resolve-Rooted $script:FixturePath)) ".cm2-sdk" }
    return Join-Path $root ".cm2-sdk"
}
function Get-OutputTarget([string]$leaf) {
    $sdkRoot = Get-SdkOutputRoot
    $target = if ($script:OutputPath -ne "") { Resolve-Rooted $script:OutputPath } else { Join-Path $sdkRoot $leaf }
    Require (Test-Within $target $sdkRoot -and -not ([IO.Path]::GetFullPath($target).Equals([IO.Path]::GetFullPath($sdkRoot), [StringComparison]::OrdinalIgnoreCase))) "unsafe-output" "SDK output must be a child of the project .cm2-sdk root" $script:packageId "" "OutputPath" "Choose a project-local .cm2-sdk child."
    return [IO.Path]::GetFullPath($target)
}
function Publish-Directory([string]$staging, [string]$target, [string]$sdkRoot) {
    Require (Test-Within $target $sdkRoot) "unsafe-output" "SDK output escapes its project build root" $script:packageId "" "OutputPath" "Use a child of ProjectPath/.cm2-sdk."
    $backup = $target + ".previous"
    if (Test-Path -LiteralPath $target) {
        $reportPath = Join-Path $target "build-report.json"
        $hashPath = Join-Path $target "build-report.sha256"
        Require ((Test-Path -LiteralPath $reportPath -PathType Leaf) -and (Test-Path -LiteralPath $hashPath -PathType Leaf)) "generated-drift" "Existing SDK output has no integrity companion" $script:packageId "build-report" "build-report.sha256" "Restore the last valid build or remove it explicitly."
        $expected = (Get-Content -Raw -LiteralPath $hashPath).Trim().ToLowerInvariant()
        Require ($expected -eq (Sha256-File $reportPath)) "generated-drift" "Last SDK build is drifted; refusing overwrite" $script:packageId "build-report" "build-report.sha256" "Restore the last valid build or remove it explicitly."
        if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Recurse -Force }
        Move-Item -LiteralPath $target -Destination $backup -Force
    }
    try { Move-Item -LiteralPath $staging -Destination $target -Force }
    catch {
        if ((Test-Path -LiteralPath $backup) -and -not (Test-Path -LiteralPath $target)) { Move-Item -LiteralPath $backup -Destination $target -Force }
        throw
    }
}
function Invoke-Build([string]$leaf) {
    Assert-ToolLock
    $target = Get-OutputTarget $leaf
    $sdkRoot = Get-SdkOutputRoot
    New-Item -ItemType Directory -Path $sdkRoot -Force | Out-Null
    $workRoot = Join-Path ([IO.Path]::GetTempPath()) ("cm2-sdk-work-" + [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $workRoot -Force | Out-Null
    try {
        $package = Prepare-Package $workRoot
        $compiler = Compile-Project $workRoot
        $artifact = $package.artifact
        $manifest = Copy-Json $artifact.manifest
        $lock = Copy-Json $artifact.lock
        $staging = Join-Path $sdkRoot (".sdk-staging-" + [Guid]::NewGuid().ToString("N"))
        New-Item -ItemType Directory -Path $staging -Force | Out-Null
        try {
            Write-Json (Join-Path $staging "manifest.json") $manifest
            Write-Json (Join-Path $staging "lock.json") $lock
            Write-Json (Join-Path $staging "resources.json") ([ordered]@{ files = @($manifest.files) })
            Write-Json (Join-Path $staging "budget.json") $manifest.budget
            Write-TextAtomic (Join-Path $staging "package.artifact.json") ([IO.File]::ReadAllText($package.artifactPath))
            Write-TextAtomic (Join-Path $staging "package-report.json") ([IO.File]::ReadAllText($package.reportPath))
            if ([string]$compiler.mode -eq "shared-compiler") {
                Write-TextAtomic (Join-Path $staging "compiler-manifest.json") ([IO.File]::ReadAllText($compiler.manifestPath))
                Write-TextAtomic (Join-Path $staging "compiler-report.json") ([IO.File]::ReadAllText($compiler.reportPath))
                Write-TextAtomic (Join-Path $staging "compiler-diagnostics.md") ([IO.File]::ReadAllText($compiler.humanPath))
            }
            $fingerprint = [string]$package.report.packageArtifactHash
            Write-TextAtomic (Join-Path $staging "fingerprint.sha256") ($fingerprint + "`n")
            $outputs = @($sdkFixture.expected.buildOutputs)
            $buildReport = [ordered]@{
                schema = "cm2.sdk-build-report/1"
                toolVersion = $toolVersion
                packageId = [string]$package.report.packageId
                packageVersion = [string]$package.report.packageVersion
                projectSchema = "cm2.creator-project/1"
                compilerVersion = "cm2.definition-compiler/1.0.0"
                compilerMode = [string]$compiler.mode
                compilerInputHash = [string]$compiler.inputHash
                compilerCatalogHash = [string]$compiler.catalogHash
                definitionCount = [int]$compiler.definitionCount
                manifestHash = [string]$package.report.manifestHash
                lockHash = Sha256-Text (Canonical-Json $lock)
                resourceCount = @($manifest.files).Count
                budget = $manifest.budget
                fingerprint = $fingerprint
                compatibilityPolicyHash = [string]$package.report.compatibilityPolicyHash
                outputs = $outputs
                editorIndependent = $true
                runtimeLua = $false
                result = "pass"
            }
            Write-Json (Join-Path $staging "build-report.json") $buildReport
            Write-TextAtomic (Join-Path $staging "build-report.sha256") ((Sha256-File (Join-Path $staging "build-report.json")) + "`n")
            Publish-Directory $staging $target $sdkRoot
            $buildReport | Add-Member -NotePropertyName publish -NotePropertyValue "published" -Force
            return $buildReport
        }
        finally { if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue } }
    }
    finally { if (Test-Path -LiteralPath $workRoot) { Remove-Item -LiteralPath $workRoot -Recurse -Force -ErrorAction SilentlyContinue } }
}
function New-HelloShipProject([string]$destination) {
    Require (-not (Test-Path -LiteralPath $destination)) "output-exists" "init refuses to overwrite an existing project" "" "" "ProjectPath" "Choose a new project directory."
    foreach ($directory in @("definitions\vehicle", "definitions\mount", "definitions\weapon", "definitions\projectile", "definitions\effect", "assets", "generated")) { New-Item -ItemType Directory -Path (Join-Path $destination $directory) -Force | Out-Null }
    $packageId = [string]$sdkFixture.newTemplate.packageId
    $ids = [ordered]@{ ship = "$packageId`:ship.hello"; mount = "$packageId`:mount.main"; weapon = "$packageId`:weapon.pulse"; projectile = "$packageId`:projectile.pulse"; effect = "$packageId`:effect.pulse"; shipAsset = "$packageId`:asset.ship"; pulseAsset = "$packageId`:asset.pulse" }
    $definitions = [ordered]@{
        "definitions\vehicle\hello.json" = [ordered]@{ schemaVersion="cm2.vehicle/1"; id=$ids.ship; kind="vehicle"; runtime=[ordered]@{ controlMode="player"; massKg=1000; mountId=$ids.mount }; editor=[ordered]@{ displayName="Hello Ship" }; ai=[ordered]@{ role="none" }; build=[ordered]@{ budgetClass="ship" } }
        "definitions\mount\main.json" = [ordered]@{ schemaVersion="cm2.mount/1"; id=$ids.mount; kind="mount"; runtime=[ordered]@{ parentId=$ids.ship; localTransform=[ordered]@{ position=@(0,0,0); rotation=@(0,0,0,1) }; slotType="p" }; editor=[ordered]@{ displayName="Pulse Mount" }; ai=[ordered]@{ role="none" }; build=[ordered]@{ budgetClass="anchor" } }
        "definitions\weapon\pulse.json" = [ordered]@{ schemaVersion="cm2.weapon/1"; id=$ids.weapon; kind="weapon"; runtime=[ordered]@{ behavior="ballistic"; effectId=$ids.effect; projectileId=$ids.projectile; fireRateHz=2 }; editor=[ordered]@{ displayName="Pulse" }; ai=[ordered]@{ targetMode="hostile" }; build=[ordered]@{ budgetClass="standard" } }
        "definitions\projectile\pulse.json" = [ordered]@{ schemaVersion="cm2.projectile/1"; id=$ids.projectile; kind="projectile"; runtime=[ordered]@{ speedMps=120; damage=10; effectId=$ids.effect }; editor=[ordered]@{ displayName="Pulse Projectile" }; ai=[ordered]@{ targetMode="hostile" }; build=[ordered]@{ budgetClass="standard" } }
        "definitions\effect\pulse.json" = [ordered]@{ schemaVersion="cm2.effect/1"; id=$ids.effect; kind="effect"; runtime=[ordered]@{ effectType="impact"; assetId=$ids.pulseAsset; priority=50 }; editor=[ordered]@{ displayName="Pulse Impact" }; ai=[ordered]@{ role="visual" }; build=[ordered]@{ budgetClass="visual" } }
    }
    foreach ($relative in $definitions.Keys) { Write-Json (Join-Path $destination $relative) $definitions[$relative] }
    Write-TextAtomic (Join-Path $destination "assets\hello-ship.vox") "VOX-CM2-SDK-HELLO-SHIP-v1`n"
    Write-TextAtomic (Join-Path $destination "assets\pulse.png") "PNG-CM2-SDK-PULSE-v1`n"
    Write-Json (Join-Path $destination "generated\runtime-dto.json") ([ordered]@{ schema="cm2.generated/1"; packageId=$packageId; dataOnly=$true })
    $filePaths = @($definitions.Keys) + @("assets\hello-ship.vox", "assets\pulse.png", "generated\runtime-dto.json")
    $files = @($filePaths | ForEach-Object { [ordered]@{ path=$_.Replace("\", "/"); hash="__computed__" } })
    $manifest = [ordered]@{
        packageId=$packageId; packageVersion=[string]$sdkFixture.newTemplate.packageVersion; schemaVersion="cm2.package/1"; coreApiVersionRange=">=1.0.0 <2.0.0"; sdkVersionRange=">=1.0.0 <2.0.0"; buildFormatVersion="cm2.package-build/1"; displayName=[string]$sdkFixture.newTemplate.displayName; author="Independent Creator"; license=[string]$sdkFixture.newTemplate.license
        provenance=[ordered]@{ source="creator-sdk-init"; sourceRevision="hello-ship-v1"; createdBy=$toolVersion }
        dependencies=@([ordered]@{ packageId="cm2.core.schemas"; versionRange=">=1.0.0 <2.0.0"; hash="schema-core-hash-v1" }); optionalDependencies=@(); capabilities=@("Ship","Mount","Weapon","Projectile","Effect","Assets"); entrypoints=[ordered]@{ runtime="data-only"; preview="cm2.preview/1"; lua=$null }
        contentEntries=@(
            [ordered]@{ id=$ids.ship; kind="Ship"; source="pkg://$packageId/definitions/vehicle/hello.json"; hash="__computed__"; references=@($ids.mount) },
            [ordered]@{ id=$ids.mount; kind="Mount"; source="pkg://$packageId/definitions/mount/main.json"; hash="__computed__"; references=@($ids.ship) },
            [ordered]@{ id=$ids.weapon; kind="Weapon"; source="pkg://$packageId/definitions/weapon/pulse.json"; hash="__computed__"; references=@($ids.projectile,$ids.effect) },
            [ordered]@{ id=$ids.projectile; kind="Projectile"; source="pkg://$packageId/definitions/projectile/pulse.json"; hash="__computed__"; references=@($ids.effect) },
            [ordered]@{ id=$ids.effect; kind="Effect"; source="pkg://$packageId/definitions/effect/pulse.json"; hash="__computed__"; references=@($ids.pulseAsset) }
        )
        assetEntries=@(
            [ordered]@{ id=$ids.shipAsset; kind="Assets"; source="pkg://$packageId/assets/hello-ship.vox"; hash="__computed__" },
            [ordered]@{ id=$ids.pulseAsset; kind="Assets"; source="pkg://$packageId/assets/pulse.png"; hash="__computed__" }
        )
        generatedEntries=@([ordered]@{ id="$packageId`:runtime-data"; kind="generated-data"; source="pkg://$packageId/generated/runtime-dto.json"; hash="__computed__" })
        budget=[ordered]@{ body=1; shape=1; joint=0; packageBytes=32768; limits=[ordered]@{ body=2; shape=8; joint=4; packageBytes=262144 } }
        files=$files; signature=[ordered]@{ algorithm="sha256-fingerprint"; keyId="cm2.sdk.fixture"; value="pending" }
    }
    $projectSource = [ordered]@{
        schema="cm2.package-manifest/1"; manifest=$manifest
        dependencyGraph=[ordered]@{ $packageId=@("cm2.core.schemas"); "cm2.core.schemas"=@() }
        lock=[ordered]@{ schema="cm2.package-lock/1"; packages=@([ordered]@{ packageId="cm2.core.schemas"; version="1.2.0"; hash="schema-core-hash-v1" }, [ordered]@{ packageId=$packageId; version=[string]$sdkFixture.newTemplate.packageVersion; hash="pending" }) }
        approvedKinds=@("Ship","Mount","Turret","Weapon","Projectile","Effect","Localization","Assets")
        negativeCases=@($sdkFixture.negativeCases)
        runtimePolicy=[ordered]@{ dataOnly=$true; runtimeLuaAllowed=$false; unknownRuntimeNodeAllowed=$false; builtinOnlyFallback=$true }
        runtimeScope="Creator SDK clean-room data-only package; live Consumer verification is separate."
    }
    Write-Json (Join-Path $destination "package.source.json") $projectSource
    Write-Json (Join-Path $destination "project.json") ([ordered]@{ schema="cm2.creator-project/1"; packageSource="package.source.json"; definitions="definitions"; assets="assets"; generated="generated"; runtimeLua=$false })
    Write-Json (Join-Path $destination "sdk.tool-lock.json") $sdkFixture.toolLock
    return [ordered]@{ command=$Command; project="hello-ship"; packageId=$packageId; definitions=$definitions.Count; runtimeLua=$false; result="pass" }
}

try {
    switch ($Command) {
        { $_ -in @("init", "new") } {
            Assert-ToolLock $false
            $destinationText = if ($script:ProjectPath -ne "") { $script:ProjectPath } elseif ($script:OutputPath -ne "") { $script:OutputPath } else { ".cm2-sdk\new-package" }
            $result = New-HelloShipProject (Resolve-Rooted $destinationText)
            Write-Output (Canonical-Json $result)
        }
        "validate" {
            Assert-ToolLock
            $work = Join-Path ([IO.Path]::GetTempPath()) ("cm2-sdk-validate-" + [Guid]::NewGuid().ToString("N")); New-Item -ItemType Directory -Path $work -Force | Out-Null
            try { $package = Prepare-Package $work; $compiler = Compile-Project $work; Write-Output (Canonical-Json ([ordered]@{ command="validate"; packageId=[string]$package.report.packageId; manifestHash=[string]$package.report.manifestHash; compilerInputHash=[string]$compiler.inputHash; definitionCount=[int]$compiler.definitionCount; diagnostics=0; result="pass" })) }
            finally { if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue } }
        }
        "build" { $report = Invoke-Build "build"; Write-Output (Canonical-Json $report) }
        "package" { $report = Invoke-Build "package"; Write-Output (Canonical-Json ([ordered]@{ command="package"; packageId=[string]$report.packageId; fingerprint=[string]$report.fingerprint; compilerCatalogHash=[string]$report.compilerCatalogHash; buildReport="build-report.json"; result="pass" })) }
        "explain" {
            Assert-ToolLock
            $work = Join-Path ([IO.Path]::GetTempPath()) ("cm2-sdk-explain-" + [Guid]::NewGuid().ToString("N")); New-Item -ItemType Directory -Path $work -Force | Out-Null
            try { $package = Prepare-Package $work; Write-Output (Canonical-Json ([ordered]@{ command="explain"; packageId=[string]$package.report.packageId; capabilities=@($package.report.capabilities); dependencyGraph=$package.report.dependencyGraph; compatibility=$package.report.compatibility; coreOnlyFallback=$package.report.coreOnlyFallback; budgets=$package.report.budget; runtimeLuaAllowed=[bool]$package.report.runtimeLuaAllowed; result="pass" })) }
            finally { if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue } }
        }
        "preview" {
            Assert-ToolLock
            $work = Join-Path ([IO.Path]::GetTempPath()) ("cm2-sdk-preview-" + [Guid]::NewGuid().ToString("N")); New-Item -ItemType Directory -Path $work -Force | Out-Null
            try { [void](Prepare-Package $work); [void](Compile-Project $work); $preview = Run-Preview (Join-Path $work "preview.report.json"); Write-Output (Canonical-Json ([ordered]@{ command="preview"; replay="S0/S2/S5"; reportHash=Sha256-Text (Canonical-Json $preview); runtimeRequired=$false; result="pass" })) }
            finally { if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue } }
        }
        "test" {
            Assert-ToolLock
            $work = Join-Path ([IO.Path]::GetTempPath()) ("cm2-sdk-test-" + [Guid]::NewGuid().ToString("N")); New-Item -ItemType Directory -Path $work -Force | Out-Null
            try { $package = Prepare-Package $work; $compiler = Compile-Project $work; $preview = Run-Preview (Join-Path $work "preview.report.json"); Write-Output (Canonical-Json ([ordered]@{ command="test"; packageHash=[string]$package.report.packageArtifactHash; compilerHash=[string]$compiler.catalogHash; previewHash=Sha256-Text (Canonical-Json $preview); negativeFixtures=@($sdkFixture.negativeCases).Count; result="pass" })) }
            finally { if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue } }
        }
        "migrate" {
            Assert-ToolLock
            $destination = Get-OutputTarget "migrated"; New-Item -ItemType Directory -Path $destination -Force | Out-Null
            $package = Read-Json (Get-ProjectSourcePath); $migrated = Copy-Json $package.manifest; $migrated.schemaVersion = "cm2.package/1"
            if (-not ($migrated.provenance.PSObject.Properties.Name -contains "migratedFrom")) { $migrated.provenance | Add-Member -NotePropertyName migratedFrom -NotePropertyValue "cm2.package/0" }
            else { $migrated.provenance.migratedFrom = "cm2.package/0" }
            Write-Json (Join-Path $destination "manifest.migrated.json") $migrated
            Write-Output (Canonical-Json ([ordered]@{ command="migrate"; from="cm2.package/0"; to="cm2.package/1"; output="manifest.migrated.json"; result="pass" }))
        }
        "doctor" {
            Assert-ToolLock ($script:ProjectPath -ne "")
            $processes = @(Get-Process -Name "teardown", "teardown_modtest" -ErrorAction SilentlyContinue)
            $processPaths = @($processes | ForEach-Object { try { $_.Path } catch { "" } } | Where-Object { $_ -ne "" } | Sort-Object -Unique)
            Write-Output (Canonical-Json ([ordered]@{ command="doctor"; toolVersion=$toolVersion; compiler=(Test-Path -LiteralPath (Join-Path $root ([string]$sdkFixture.compilerPath)) -PathType Leaf); schema=(Test-Path -LiteralPath (Join-Path $root ([string]$sdkFixture.schemaPath)) -PathType Leaf); teardownRunning=($processes.Count -gt 0); teardownProcessCount=$processes.Count; teardownPaths=$processPaths; dataOnlyCommandsAvailable=$true; result="pass" }))
        }
        "clean" {
            Assert-ToolLock
            $sdkRoot = Get-SdkOutputRoot
            $target = if ($script:OutputPath -ne "") { Resolve-Rooted $script:OutputPath } else { Join-Path $sdkRoot "build" }
            Require (Test-Within $target $sdkRoot -and (Split-Path -Leaf $target) -in @("build", "package", "migrated")) "unsafe-clean" "clean target is outside an approved project SDK leaf" $script:packageId "" "OutputPath" "Clean only build, package, or migrated under ProjectPath/.cm2-sdk."
            if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
            Write-Output (Canonical-Json ([ordered]@{ command="clean"; target=(Split-Path -Leaf $target); result="pass" }))
        }
    }
    exit 0
}
catch {
    $caught = $_.Exception
    $errorReport = [ordered]@{
        command=$Command
        code=if ($caught.Data["cm2Code"]) { [string]$caught.Data["cm2Code"] } else { "sdk-error" }
        packageId=if ($caught.Data["cm2PackageId"]) { [string]$caught.Data["cm2PackageId"] } else { $script:packageId }
        definitionId=if ($caught.Data["cm2DefinitionId"]) { [string]$caught.Data["cm2DefinitionId"] } else { "" }
        fieldPath=if ($caught.Data["cm2FieldPath"]) { [string]$caught.Data["cm2FieldPath"] } else { "" }
        message=$caught.Message
        suggestion=if ($caught.Data["cm2Suggestion"]) { [string]$caught.Data["cm2Suggestion"] } else { "Inspect the command report and fix the source package." }
        result="fail"
    }
    Write-Output (Canonical-Json $errorReport)
    exit 1
}
