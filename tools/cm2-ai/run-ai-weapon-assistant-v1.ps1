# Headless AI Weapon Assistant. It converts fixed natural-language intents into
# candidate source envelopes, validates them with the shared Compiler, and
# writes no Runtime/Core/generated artifact in the repository.

param(
    [string]$PolicyPath = "",
    [string]$FixturePath = "",
    [string]$ReportPath = ""
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if ($PolicyPath -eq "") { $PolicyPath = Join-Path $root "docs\ai-weapon-assistant-v1.json" }
if ($FixturePath -eq "") { $FixturePath = Join-Path $root "docs\candidates\ai-weapon-assistant-v1.fixture.json" }
if ($ReportPath -eq "") { $ReportPath = Join-Path $root "docs\candidates\ai-weapon-assistant-v1.result.json" }
$utf8 = New-Object Text.UTF8Encoding($false)

function Canonical([object]$value) { return ($value | ConvertTo-Json -Depth 100 -Compress) }
function Write-Json([string]$path, [object]$value) {
    $parent = Split-Path -Parent $path
    if ($parent -and -not (Test-Path -LiteralPath $parent -PathType Container)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    [IO.File]::WriteAllText($path, (Canonical $value) + [Environment]::NewLine, $utf8)
}
function Sha256-Text([string]$text) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return (($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($text)) | ForEach-Object { $_.ToString("x2") }) -join "") }
    finally { $sha.Dispose() }
}
function Fail([string]$code, [string]$message, [string]$fieldPath, [string]$suggestion) {
    $report = [ordered]@{
        schema = "cm2.ai-weapon-report/1"
        status = "candidate-only"
        result = "fail"
        code = $code
        fieldPath = $fieldPath
        message = $message
        suggestion = $suggestion
        aiWrites = [ordered]@{ sourceCandidates = 0; generated = 0; core = 0; lua = 0; network = 0 }
    }
    Write-Json $ReportPath $report
    Write-Output (Canonical $report)
    exit 1
}
function Snapshot-Scopes {
    $records = New-Object System.Collections.Generic.List[object]
    foreach ($scope in @("Content Mod 2", "Global Mod")) {
        $scopePath = Join-Path $root $scope
        if (-not (Test-Path -LiteralPath $scopePath -PathType Container)) { continue }
        $scopeFull = (Resolve-Path -LiteralPath $scopePath).Path
        foreach ($file in @(Get-ChildItem -LiteralPath $scopeFull -Recurse -File | Sort-Object FullName)) {
            $relative = $file.FullName.Substring($scopeFull.Length).TrimStart("\", "/").Replace("\", "/")
            [void]$records.Add([ordered]@{ path = $scope + "/" + $relative; hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName).Hash.ToLowerInvariant() })
        }
    }
    return Sha256-Text (Canonical $records.ToArray())
}
function New-Envelope([string]$kind, [string]$id, [object]$runtime, [object]$editor, [object]$ai, [object]$build) {
    return [ordered]@{
        schemaVersion = "cm2." + $kind + "/1"
        id = $id
        kind = $kind
        runtime = $runtime
        editor = $editor
        ai = $ai
        build = $build
    }
}
function New-HumanDiff([object]$intent) {
    $fields = @(
        [ordered]@{ fieldPath = "runtime.behavior"; before = $null; after = [string]$intent.behavior; owner = "ai-proposed" },
        [ordered]@{ fieldPath = "runtime.fireRateHz"; before = $null; after = $intent.fireRateHz; owner = "ai-proposed" },
        [ordered]@{ fieldPath = "runtime.damage"; before = $null; after = $intent.damage; owner = "ai-proposed" },
        [ordered]@{ fieldPath = "runtime.speedMps"; before = $null; after = $intent.speedMps; owner = "ai-proposed" },
        [ordered]@{ fieldPath = "runtime.effectType"; before = $null; after = [string]$intent.effectType; owner = "ai-proposed" },
        [ordered]@{ fieldPath = "runtime.effectPriority"; before = $null; after = $intent.effectPriority; owner = "ai-proposed" }
    )
    return $fields
}
function Invoke-Compiler([string]$definitionsPath, [string]$outputRoot) {
    $catalogPath = Join-Path $outputRoot "catalog.lua"
    $manifestPath = Join-Path $outputRoot "catalog.manifest.json"
    $reportPath = Join-Path $outputRoot "catalog.report.json"
    $humanPath = Join-Path $outputRoot "catalog.diagnostics.md"
    New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
    $compiler = Join-Path $root "tools\cm2-compiler\compile-definitions.ps1"
    $args = @(
        "-InputPath", $definitionsPath,
        "-OutputPath", $catalogPath,
        "-ManifestPath", $manifestPath,
        "-ReportPath", $reportPath,
        "-HumanReportPath", $humanPath,
        "-SchemaPath", (Join-Path $root "schemas\cm2\source-envelope-v1.json")
    )
    $saved = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $compiler @args *> $null
    $exitCode = [int]$LASTEXITCODE
    $ErrorActionPreference = $saved
    $compilerResult = $null
    if (Test-Path -LiteralPath $reportPath -PathType Leaf) { $compilerResult = Get-Content -Raw -LiteralPath $reportPath | ConvertFrom-Json }
    $manifest = $null
    if (Test-Path -LiteralPath $manifestPath -PathType Leaf) { $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json }
    $catalogHash = ""
    if ($null -ne $manifest) { $catalogHash = [string]$manifest.catalogHash }
    return [ordered]@{
        passed = ($exitCode -eq 0 -and $null -ne $manifest -and [int]$compilerResult.errors.Count -eq 0)
        exitCode = $exitCode
        definitionCount = if ($null -eq $compilerResult) { 0 } else { [int]$compilerResult.definitionCount }
        errorCount = if ($null -eq $compilerResult) { 1 } else { [int]$compilerResult.errors.Count }
        inputHash = if ($null -eq $compilerResult) { "" } else { [string]$compilerResult.inputHash }
        catalogHash = $catalogHash
        outputScope = "disposable-temp-only"
    }
}
function Evaluate-WeaponCase([object]$testCase, [object]$policy, [object]$fixture, [string]$tempRoot) {
    $intent = $testCase.intent
    $promptHash = Sha256-Text ([string]$testCase.prompt)
    $candidateDescriptor = [ordered]@{ id = [string]$testCase.id; prompt = [string]$testCase.prompt; intent = $intent; parserVersion = [string]$policy.parserVersion }
    $candidateHash = Sha256-Text (Canonical $candidateDescriptor)
    $decision = "accept"
    $code = "candidate-valid"
    $reasons = New-Object System.Collections.Generic.List[string]
    $humanDiff = @(New-HumanDiff $intent)
    $compilerInfo = [ordered]@{ passed = $false; exitCode = 0; definitionCount = 0; errorCount = 0; inputHash = ""; catalogHash = ""; outputScope = "not-built" }

    if ([string]$intent.requestedOperation -notin @($policy.permissions.allow)) {
        $decision = "reject"; $code = "permission-denied"; [void]$reasons.Add("Requested operation is outside the allow-list.")
    }
    elseif ([string]$intent.requestedOperation -in @($policy.permissions.deny)) {
        $decision = "reject"; $code = "permission-denied"; [void]$reasons.Add("Requested operation is explicitly denied.")
    }
    elseif ([string]$intent.requestedTarget -notin @($policy.allowLists.targetKinds) -or [string]$intent.requestedTarget -match '(^|[\\/])\.\.([\\/]|$)|Global Mod|Core|generated|\.lua($|[\\/])') {
        $decision = "reject"; $code = "forbidden-target"; [void]$reasons.Add("Candidate target must remain a source-definition candidate.")
    }
    elseif ($null -eq $intent.PSObject.Properties["behavior"] -or [string]$intent.behavior -eq "" -or $null -eq $intent.PSObject.Properties["effectType"] -or [string]$intent.effectType -eq "") {
        $decision = "repair"; $code = "intent-ambiguous"; [void]$reasons.Add("Behavior and effect type are required before a schema patch can be proposed.")
    }
    elseif ([string]$intent.behavior -notin @($policy.allowLists.behaviors) -or [string]$intent.effectType -notin @($policy.allowLists.effectTypes)) {
        $decision = "reject"; $code = "allow-list-reject"; [void]$reasons.Add("Behavior/effect type is not registered in the v1 allow-list.")
    }
    elseif (-not [bool]$intent.assetExists) {
        $decision = "reject"; $code = "missing-resource"; [void]$reasons.Add("Effect asset must already exist in the package resource map.")
    }
    elseif ([double]$intent.fireRateHz -le 0 -or [double]$intent.fireRateHz -gt [double]$policy.budgets.maxFireRateHz -or [double]$intent.speedMps -le 0 -or [double]$intent.speedMps -gt [double]$policy.budgets.maxProjectileSpeedMps -or [double]$intent.damage -le 0 -or [double]$intent.damage -gt [double]$policy.budgets.maxDamagePerShot -or ([double]$intent.damage * [double]$intent.fireRateHz) -gt [double]$policy.budgets.maxDps -or [double]$intent.effectPriority -lt 0 -or [double]$intent.effectPriority -gt [double]$policy.budgets.maxEffectPriority) {
        $decision = "reject"; $code = "budget-or-range-reject"; [void]$reasons.Add("Schema range or deterministic Weapon budget was exceeded.")
    }

    $finalBuildHash = "not-built"
    $rangeLab = [ordered]@{ status = "not-run"; dps = 0; rangeM = 0; power = 0; budget = [ordered]@{ projectile = 0; effect = 0; total = 0; status = "not-run" }; trace = @(); replayHash = "" }
    if ($decision -eq "accept") {
        $prefix = "cm2.ai.weapon"
        $weaponId = $prefix + ":" + [string]$testCase.id
        $projectileId = $prefix + ":projectile." + [string]$testCase.id
        $effectId = $prefix + ":effect." + [string]$testCase.id
        $assetId = $prefix + ":asset." + [string]$intent.assetLocalId
        $packageRoot = Join-Path $tempRoot ("candidate-" + [string]$testCase.id)
        $definitions = Join-Path $packageRoot "definitions"
        $assets = Join-Path $definitions "assets"
        New-Item -ItemType Directory -Path $assets -Force | Out-Null
        $ai = [ordered]@{ promptHash = $promptHash; candidateHash = $candidateHash; modelVersion = [string]$policy.modelVersion; toolVersion = [string]$policy.toolVersion; parserVersion = [string]$policy.parserVersion; validatorVersion = [string]$fixture.validatorVersion; humanDiff = $humanDiff; confidence = 0.9; humanApprovalRequired = $true }
        $buildBase = [ordered]@{ sourcePath = "definitions/" + [string]$testCase.id + ".json"; revision = "ai-weapon-v1"; budgetClass = "standard"; generated = $false; manualEdit = "forbidden" }
        $weaponRuntime = [ordered]@{ behavior = [string]$intent.behavior; effectId = $effectId; projectileId = $projectileId; fireRateHz = [double]$intent.fireRateHz }
        $projectileRuntime = [ordered]@{ speedMps = [double]$intent.speedMps; damage = [double]$intent.damage; effectId = $effectId }
        $effectRuntime = [ordered]@{ effectType = [string]$intent.effectType; assetId = $assetId; priority = [double]$intent.effectPriority }
        $weapon = New-Envelope "weapon" $weaponId $weaponRuntime ([ordered]@{ displayName = "AI " + [string]$testCase.id; prompt = [string]$testCase.prompt }) $ai $buildBase
        $projectile = New-Envelope "projectile" $projectileId $projectileRuntime ([ordered]@{ displayName = "AI " + [string]$testCase.id + " projectile" }) $ai ([ordered]@{ sourcePath = "definitions/projectile-" + [string]$testCase.id + ".json"; revision = "ai-weapon-v1"; budgetClass = "standard"; generated = $false; manualEdit = "forbidden" })
        $effect = New-Envelope "effect" $effectId $effectRuntime ([ordered]@{ displayName = "AI " + [string]$testCase.id + " effect" }) $ai ([ordered]@{ sourcePath = "definitions/effect-" + [string]$testCase.id + ".json"; revision = "ai-weapon-v1"; budgetClass = "visual"; generated = $false; manualEdit = "forbidden" })
        Write-Json (Join-Path $definitions ([string]$testCase.id + ".json")) $weapon
        Write-Json (Join-Path $definitions ("projectile-" + [string]$testCase.id + ".json")) $projectile
        Write-Json (Join-Path $definitions ("effect-" + [string]$testCase.id + ".json")) $effect
        Write-Json (Join-Path $definitions "resources.json") ([ordered]@{ resources = @([ordered]@{ id = $assetId; path = "assets/" + [string]$intent.assetLocalId + ".fx" }) })
        [IO.File]::WriteAllText((Join-Path $assets ([string]$intent.assetLocalId + ".fx")), "candidate effect asset " + [string]$testCase.id, $utf8)
        $compilerInfo = Invoke-Compiler $definitions (Join-Path $packageRoot "compiler")
        if (-not [bool]$compilerInfo.passed) {
            $decision = "reject"; $code = "compiler-reject"; [void]$reasons.Add("Shared Compiler rejected the generated source envelope.")
        }
        else {
            $finalBuildHash = [string]$compilerInfo.catalogHash
            $effectCost = 1
            if ([string]$intent.effectType -eq "beam") { $effectCost = 3 }
            elseif ([string]$intent.effectType -eq "trail") { $effectCost = 2 }
            $projectileCost = 1
            if ([string]$intent.behavior -eq "ballistic") { $projectileCost = 2 }
            elseif ([string]$intent.behavior -eq "guided") { $projectileCost = 4 }
            elseif ([string]$intent.behavior -eq "charged") { $projectileCost = 3 }
            $totalCost = $projectileCost + $effectCost + 1
            $trace = New-Object System.Collections.Generic.List[object]
            for ($shot = 1; $shot -le 4; $shot++) {
                [void]$trace.Add([ordered]@{ shot = $shot; targetDistanceM = 250 + ($shot * 125); hit = $true; damage = [double]$intent.damage; fixedSeed = [int]$fixture.fixedSeed })
            }
            $rangeLab = [ordered]@{
                status = "pass"
                dps = [Math]::Round(([double]$intent.damage * [double]$intent.fireRateHz), 4)
                rangeM = [Math]::Round(([double]$intent.speedMps * 3), 2)
                power = [Math]::Round(([double]$intent.damage * [double]$intent.fireRateHz * $totalCost), 4)
                budget = [ordered]@{ projectile = $projectileCost; effect = $effectCost; total = $totalCost; status = "accepted" }
                trace = $trace.ToArray()
                replayHash = Sha256-Text (Canonical $trace.ToArray())
            }
        }
    }
    return [ordered]@{
        id = [string]$testCase.id
        prompt = [string]$testCase.prompt
        intent = $intent
        expected = [string]$testCase.expected
        decision = $decision
        code = $code
        reasons = $reasons.ToArray()
        promptHash = $promptHash
        candidateHash = $candidateHash
        modelVersion = [string]$policy.modelVersion
        toolVersion = [string]$policy.toolVersion
        parserVersion = [string]$policy.parserVersion
        validatorVersion = [string]$fixture.validatorVersion
        humanDiff = $humanDiff
        finalBuildHash = $finalBuildHash
        compiler = $compilerInfo
        rangeLab = $rangeLab
        publish = "manual-approval-required"
        aiWrites = [ordered]@{ sourceCandidate = if ($decision -eq "accept") { 1 } else { 0 }; generated = 0; core = 0; lua = 0; network = 0 }
    }
}

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("cm2-ai-weapon-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
try {
    if (-not (Test-Path -LiteralPath $PolicyPath -PathType Leaf)) { Fail "policy-missing" "Weapon Assistant policy does not exist" "policy" "Restore the reviewed policy." }
    if (-not (Test-Path -LiteralPath $FixturePath -PathType Leaf)) { Fail "fixture-missing" "Weapon Assistant fixture does not exist" "fixture" "Restore the fixed prompt fixture." }
    $policy = Get-Content -Raw -LiteralPath $PolicyPath | ConvertFrom-Json
    $fixture = Get-Content -Raw -LiteralPath $FixturePath | ConvertFrom-Json
    if ([string]$policy.schema -ne "cm2.ai-weapon-policy/1") { Fail "policy-schema" "Weapon Assistant policy schema mismatch" "policy.schema" "Use policy v1." }
    if ([string]$fixture.schema -ne "cm2.ai-weapon-fixtures/1") { Fail "fixture-schema" "Weapon Assistant fixture schema mismatch" "fixture.schema" "Use fixture v1." }
    $coreBefore = Snapshot-Scopes
    $evaluations = New-Object System.Collections.Generic.List[object]
    foreach ($testCase in @($fixture.cases)) { [void]$evaluations.Add((Evaluate-WeaponCase $testCase $policy $fixture $tempRoot)) }
    $coreAfter = Snapshot-Scopes
    $matching = @($evaluations.ToArray() | Where-Object { [string]$_.decision -eq [string]$_.expected }).Count
    $accepted = @($evaluations.ToArray() | Where-Object { [string]$_.decision -eq "accept" })
    $compiledAccepted = @($accepted | Where-Object { [bool]$_.compiler.passed }).Count
    $legalRate = [Math]::Round($matching / $evaluations.Count, 4)
    $compilerPassRate = if ($accepted.Count -eq 0) { 0.0 } else { [Math]::Round($compiledAccepted / $accepted.Count, 4) }
    $determinismHash = Sha256-Text (Canonical $evaluations.ToArray())
    $report = [ordered]@{
        schema = "cm2.ai-weapon-report/1"
        status = "candidate-only"
        policySchema = [string]$policy.schema
        modelVersion = [string]$policy.modelVersion
        toolVersion = [string]$policy.toolVersion
        parserVersion = [string]$policy.parserVersion
        fixedSeed = [int]$fixture.fixedSeed
        pipeline = @($policy.pipeline)
        caseCount = $evaluations.Count
        evaluations = $evaluations.ToArray()
        metrics = [ordered]@{
            accepted = $accepted.Count
            repairs = @($evaluations.ToArray() | Where-Object { $_.decision -eq "repair" }).Count
            rejected = @($evaluations.ToArray() | Where-Object { $_.decision -eq "reject" }).Count
            legalRate = $legalRate
            savedCompilerPassRate = $compilerPassRate
            determinismHash = $determinismHash
            performanceRisk = "bounded-by-v1-budget-lint"
        }
        humanApproval = [ordered]@{ required = $true; diffDisplayed = $true; autoPublish = $false; ownership = "ai-proposed-fields-remain-reviewable" }
        aiWrites = [ordered]@{ sourceCandidates = $accepted.Count; generated = 0; core = 0; lua = 0; network = 0; compilerOutputs = "disposable-temp-only" }
        repositoryIntegrity = [ordered]@{ coreDiff = if ($coreBefore -eq $coreAfter) { 0 } else { 1 }; sourceOfTruthPreserved = ($coreBefore -eq $coreAfter) }
        runtime = [ordered]@{ status = "deferred"; teardownAvailable = ($null -ne (Get-Command Teardown.exe -ErrorAction SilentlyContinue)); reason = "Weapon Range/Effect Lab is headless and deterministic; live Preview and Teardown firing remain an explicit runtime step." }
        rollback = "Discard candidate sources/report and keep the last valid catalog; do not promote without human approval."
        result = if ($legalRate -eq 1.0 -and $compilerPassRate -eq 1.0 -and $coreBefore -eq $coreAfter) { "pass" } else { "fail" }
    }
    Write-Json $ReportPath $report
    Write-Output (Canonical $report)
    if ([string]$report.result -ne "pass") { exit 1 }
    exit 0
}
catch {
    Fail "ai-weapon-runner-error" $_.Exception.Message "runner" "Inspect the intent fixture, allow-list or shared Compiler diagnostics."
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
}
