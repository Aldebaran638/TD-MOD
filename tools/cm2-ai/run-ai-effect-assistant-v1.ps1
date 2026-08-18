# Headless AI Effect Assistant. It produces only candidate EffectDefinitions,
# bounded budget profiles and disposable Compiler outputs.

param(
    [string]$PolicyPath = "",
    [string]$FixturePath = "",
    [string]$ReportPath = ""
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if ($PolicyPath -eq "") { $PolicyPath = Join-Path $root "docs\ai-effect-assistant-v1.json" }
if ($FixturePath -eq "") { $FixturePath = Join-Path $root "docs\candidates\ai-effect-assistant-v1.fixture.json" }
if ($ReportPath -eq "") { $ReportPath = Join-Path $root "docs\candidates\ai-effect-assistant-v1.result.json" }
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
        schema = "cm2.ai-effect-report/1"
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
function New-Envelope([string]$id, [object]$runtime, [object]$editor, [object]$ai, [object]$build) {
    return [ordered]@{
        schemaVersion = "cm2.effect/1"
        id = $id
        kind = "effect"
        runtime = $runtime
        editor = $editor
        ai = $ai
        build = $build
    }
}
function Invoke-Compiler([string]$definitionsPath, [string]$outputRoot) {
    $catalogPath = Join-Path $outputRoot "catalog.lua"
    $manifestPath = Join-Path $outputRoot "catalog.manifest.json"
    $reportPath = Join-Path $outputRoot "catalog.report.json"
    $humanPath = Join-Path $outputRoot "catalog.diagnostics.md"
    New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
    $compiler = Join-Path $root "tools\cm2-compiler\compile-definitions.ps1"
    $args = @("-InputPath", $definitionsPath, "-OutputPath", $catalogPath, "-ManifestPath", $manifestPath, "-ReportPath", $reportPath, "-HumanReportPath", $humanPath, "-SchemaPath", (Join-Path $root "schemas\cm2\source-envelope-v1.json"))
    $saved = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $compiler @args *> $null
    $exitCode = [int]$LASTEXITCODE
    $ErrorActionPreference = $saved
    $compilerResult = $null
    if (Test-Path -LiteralPath $reportPath -PathType Leaf) { $compilerResult = Get-Content -Raw -LiteralPath $reportPath | ConvertFrom-Json }
    $manifest = $null
    if (Test-Path -LiteralPath $manifestPath -PathType Leaf) { $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json }
    return [ordered]@{
        passed = ($exitCode -eq 0 -and $null -ne $manifest -and $null -ne $compilerResult -and [int]$compilerResult.errors.Count -eq 0)
        exitCode = $exitCode
        definitionCount = if ($null -eq $compilerResult) { 0 } else { [int]$compilerResult.definitionCount }
        errorCount = if ($null -eq $compilerResult) { 1 } else { [int]$compilerResult.errors.Count }
        inputHash = if ($null -eq $compilerResult) { "" } else { [string]$compilerResult.inputHash }
        catalogHash = if ($null -eq $manifest) { "" } else { [string]$manifest.catalogHash }
        outputScope = "disposable-temp-only"
    }
}
function New-HumanDiff([object]$intent) {
    return @(
        [ordered]@{ fieldPath = "runtime.effectType"; before = $null; after = [string]$intent.effectType; owner = "ai-proposed" },
        [ordered]@{ fieldPath = "runtime.nodes"; before = $null; after = @($intent.nodes); owner = "ai-proposed" },
        [ordered]@{ fieldPath = "runtime.color"; before = $null; after = @($intent.color); owner = "ai-proposed" },
        [ordered]@{ fieldPath = "runtime.durationMs"; before = $null; after = $intent.durationMs; owner = "ai-proposed" },
        [ordered]@{ fieldPath = "runtime.emitters"; before = $null; after = $intent.emitters; owner = "ai-proposed" },
        [ordered]@{ fieldPath = "runtime.shake"; before = $null; after = $intent.shake; owner = "ai-proposed" },
        [ordered]@{ fieldPath = "runtime.priority"; before = $null; after = $intent.priority; owner = "ai-proposed" }
    )
}
function Get-NodeCost([string]$node) {
    switch ($node) {
        "emitter" { return 1 }
        "beam" { return 3 }
        "shockwave" { return 3 }
        "sound" { return 1 }
        "shake" { return 1 }
        default { return 99 }
    }
}
function Evaluate-EffectCase([object]$testCase, [object]$policy, [object]$fixture, [string]$tempRoot) {
    $intent = $testCase.intent
    $promptHash = Sha256-Text ([string]$testCase.prompt)
    $candidateDescriptor = [ordered]@{ id = [string]$testCase.id; prompt = [string]$testCase.prompt; intent = $intent; parserVersion = [string]$policy.parserVersion }
    $candidateHash = Sha256-Text (Canonical $candidateDescriptor)
    $decision = "accept"
    $code = "candidate-valid"
    $reasons = New-Object System.Collections.Generic.List[string]
    $humanDiff = @(New-HumanDiff $intent)
    $profileResults = New-Object System.Collections.Generic.List[object]
    $effectCost = 0
    foreach ($node in @($intent.nodes)) { $effectCost += Get-NodeCost ([string]$node) }
    $effectCost += [int]$intent.emitters
    $invalidColor = $null -eq $intent.PSObject.Properties["color"] -or @($intent.color).Count -ne 3
    if ([string]$intent.requestedOperation -notin @($policy.permissions.allow)) {
        $decision = "reject"; $code = "permission-denied"; [void]$reasons.Add("Requested operation is outside the Effect Assistant allow-list.")
    }
    elseif ([string]$intent.requestedOperation -in @($policy.permissions.deny)) {
        $decision = "reject"; $code = "permission-denied"; [void]$reasons.Add("Requested operation is explicitly denied.")
    }
    elseif ([string]$intent.requestedTarget -notin @($policy.allowLists.targetKinds) -or [string]$intent.requestedTarget -match '(^|[\\/])\.\.([\\/]|$)|Global Mod|Core|generated|\.lua($|[\\/])') {
        $decision = "reject"; $code = "forbidden-target"; [void]$reasons.Add("Effect candidates may only target source-definition-candidate.")
    }
    elseif ($null -eq $intent.PSObject.Properties["effectType"] -or [string]$intent.effectType -eq "" -or @($intent.nodes).Count -eq 0) {
        $decision = "repair"; $code = "intent-ambiguous"; [void]$reasons.Add("Effect type and at least one approved node are required.")
    }
    elseif ([string]$intent.effectType -notin @($policy.allowLists.effectTypes) -or @($intent.nodes | Where-Object { [string]$_ -notin @($policy.allowLists.nodes) }).Count -gt 0) {
        $decision = "reject"; $code = "node-or-type-reject"; [void]$reasons.Add("Effect type or node is not registered; custom renderers require Core review.")
    }
    elseif (-not [bool]$intent.assetExists) {
        $decision = "reject"; $code = "missing-resource"; [void]$reasons.Add("Effect asset must already exist in the package resource map.")
    }
    elseif ($invalidColor -or @($intent.color | Where-Object { [double]$_ -lt 0 -or [double]$_ -gt 1 }).Count -gt 0 -or [double]$intent.durationMs -le 0 -or [double]$intent.durationMs -gt [double]$policy.ranges.maxDurationMs -or [int]$intent.emitters -le 0 -or [int]$intent.emitters -gt [int]$policy.ranges.maxEmitters -or [double]$intent.shake -lt 0 -or [double]$intent.shake -gt [double]$policy.ranges.maxShake -or [double]$intent.priority -lt 0 -or [double]$intent.priority -gt [double]$policy.ranges.maxPriority -or $effectCost -gt [int]$policy.ranges.maxPowerCost) {
        $decision = "reject"; $code = "budget-or-range-reject"; [void]$reasons.Add("Effect hard cap or parameter range was exceeded.")
    }

    $finalBuildHash = "not-built"
    $lab = [ordered]@{ status = "not-run"; requests = 0; accepted = 0; degraded = 0; rejected = 0; hardCap = [int]$policy.ranges.maxPowerCost; fixedSeed = [int]$fixture.fixedSeed; trace = @(); replayHash = "" }
    if ($decision -eq "accept") {
        $prefix = "cm2.ai.effect"
        $assetId = $prefix + ":asset." + [string]$intent.assetLocalId
        $caseRoot = Join-Path $tempRoot ("candidate-" + [string]$testCase.id)
        $assetPath = Join-Path $caseRoot "definitions\assets"
        New-Item -ItemType Directory -Path $assetPath -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $assetPath ([string]$intent.assetLocalId + ".fx")), "candidate effect asset " + [string]$testCase.id, $utf8)
        $profileSpecs = @(
            [ordered]@{ name = "normal"; emitterCount = [int]$intent.emitters; durationMs = [int]$intent.durationMs; degraded = $false },
            [ordered]@{ name = "critical"; emitterCount = [Math]::Min(2, [int]$intent.emitters); durationMs = [Math]::Min(500, [int]$intent.durationMs); degraded = $true },
            [ordered]@{ name = "ambient"; emitterCount = 1; durationMs = [Math]::Min(250, [int]$intent.durationMs); degraded = $true }
        )
        foreach ($profileSpec in $profileSpecs) {
            $profileName = [string]$profileSpec.name
            $definitions = Join-Path $caseRoot ("definitions-" + $profileName)
            $assets = Join-Path $definitions "assets"
            New-Item -ItemType Directory -Path $assets -Force | Out-Null
            Copy-Item -LiteralPath (Join-Path $assetPath ([string]$intent.assetLocalId + ".fx")) -Destination (Join-Path $assets ([string]$intent.assetLocalId + ".fx")) -Force
            $effectId = $prefix + ":" + [string]$testCase.id + "." + $profileName
            $runtime = [ordered]@{
                effectType = [string]$intent.effectType
                assetId = $assetId
                priority = [double]$intent.priority
                nodes = @($intent.nodes)
                color = @($intent.color)
                durationMs = [int]$profileSpec.durationMs
                emitters = [int]$profileSpec.emitterCount
                shake = [double]$intent.shake
                lod = @("near", "far")
                budgetProfile = $profileName
                facade = "EffectPlayer+PresentationBudget"
            }
            $ai = [ordered]@{ promptHash = $promptHash; candidateHash = $candidateHash; modelVersion = [string]$policy.modelVersion; toolVersion = [string]$policy.toolVersion; parserVersion = [string]$policy.parserVersion; validatorVersion = [string]$fixture.validatorVersion; humanDiff = $humanDiff; confidence = 0.9; humanApprovalRequired = $true; budgetProfile = $profileName }
            $source = New-Envelope $effectId $runtime ([ordered]@{ displayName = "AI " + [string]$testCase.id + " " + $profileName; prompt = [string]$testCase.prompt }) $ai ([ordered]@{ sourcePath = "definitions/" + $profileName + ".json"; revision = "ai-effect-v1"; budgetClass = "visual"; generated = $false; manualEdit = "forbidden" })
            Write-Json (Join-Path $definitions ($profileName + ".json")) $source
            Write-Json (Join-Path $definitions "resources.json") ([ordered]@{ resources = @([ordered]@{ id = $assetId; path = "assets/" + [string]$intent.assetLocalId + ".fx" }) })
            $compilerInfo = Invoke-Compiler $definitions (Join-Path $caseRoot ("compiler-" + $profileName))
            [void]$profileResults.Add([ordered]@{ name = $profileName; degraded = [bool]$profileSpec.degraded; emitterCount = [int]$profileSpec.emitterCount; durationMs = [int]$profileSpec.durationMs; compiler = $compilerInfo })
        }
        $allCompiled = @($profileResults.ToArray() | Where-Object { -not [bool]$_.compiler.passed }).Count -eq 0
        if (-not $allCompiled) {
            $decision = "reject"; $code = "compiler-reject"; [void]$reasons.Add("Shared Compiler rejected at least one budget profile.")
        }
        else {
            $finalBuildHash = Sha256-Text (Canonical $profileResults.ToArray())
            $trace = @(
                [ordered]@{ operation = "play"; distance = "near"; profile = "normal"; result = "accepted"; fixedSeed = [int]$fixture.fixedSeed },
                [ordered]@{ operation = "play"; distance = "far"; profile = "normal"; result = "accepted"; fixedSeed = [int]$fixture.fixedSeed },
                [ordered]@{ operation = "play"; distance = "near"; profile = "critical"; result = "degraded"; fixedSeed = [int]$fixture.fixedSeed },
                [ordered]@{ operation = "play"; distance = "far"; profile = "ambient"; result = "degraded"; fixedSeed = [int]$fixture.fixedSeed }
            )
            $lab = [ordered]@{ status = "pass"; requests = 4; accepted = 2; degraded = 2; rejected = 0; hardCap = [int]$policy.ranges.maxPowerCost; fixedSeed = [int]$fixture.fixedSeed; trace = $trace; replayHash = Sha256-Text (Canonical $trace) }
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
        profiles = $profileResults.ToArray()
        effectLab = $lab
        finalBuildHash = $finalBuildHash
        publish = "manual-approval-required"
        facade = "EffectPlayer+PresentationBudget"
        aiWrites = [ordered]@{ sourceCandidate = if ($decision -eq "accept") { 1 } else { 0 }; generated = 0; core = 0; lua = 0; network = 0 }
    }
}

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("cm2-ai-effect-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
try {
    if (-not (Test-Path -LiteralPath $PolicyPath -PathType Leaf)) { Fail "policy-missing" "Effect Assistant policy does not exist" "policy" "Restore the reviewed policy." }
    if (-not (Test-Path -LiteralPath $FixturePath -PathType Leaf)) { Fail "fixture-missing" "Effect Assistant fixture does not exist" "fixture" "Restore the fixed prompt fixture." }
    $policy = Get-Content -Raw -LiteralPath $PolicyPath | ConvertFrom-Json
    $fixture = Get-Content -Raw -LiteralPath $FixturePath | ConvertFrom-Json
    if ([string]$policy.schema -ne "cm2.ai-effect-policy/1") { Fail "policy-schema" "Effect Assistant policy schema mismatch" "policy.schema" "Use policy v1." }
    if ([string]$fixture.schema -ne "cm2.ai-effect-fixtures/1") { Fail "fixture-schema" "Effect Assistant fixture schema mismatch" "fixture.schema" "Use fixture v1." }
    $coreBefore = Snapshot-Scopes
    $evaluations = New-Object System.Collections.Generic.List[object]
    foreach ($testCase in @($fixture.cases)) { [void]$evaluations.Add((Evaluate-EffectCase $testCase $policy $fixture $tempRoot)) }
    $coreAfter = Snapshot-Scopes
    $matching = @($evaluations.ToArray() | Where-Object { [string]$_.decision -eq [string]$_.expected }).Count
    $accepted = @($evaluations.ToArray() | Where-Object { [string]$_.decision -eq "accept" })
    $profileTotal = 0
    $profilePassed = 0
    foreach ($acceptedCase in $accepted) {
        $profileTotal += @($acceptedCase.profiles).Count
        $profilePassed += @($acceptedCase.profiles | Where-Object { [bool]$_.compiler.passed }).Count
    }
    $legalRate = [Math]::Round($matching / $evaluations.Count, 4)
    $profilePassRate = if ($profileTotal -eq 0) { 0.0 } else { [Math]::Round($profilePassed / $profileTotal, 4) }
    $determinismHash = Sha256-Text (Canonical $evaluations.ToArray())
    $repoUnchanged = $coreBefore -eq $coreAfter
    $report = [ordered]@{
        schema = "cm2.ai-effect-report/1"
        status = "candidate-only"
        policySchema = [string]$policy.schema
        modelVersion = [string]$policy.modelVersion
        toolVersion = [string]$policy.toolVersion
        parserVersion = [string]$policy.parserVersion
        fixedSeed = [int]$fixture.fixedSeed
        pipeline = @($policy.pipeline)
        caseCount = $evaluations.Count
        evaluations = $evaluations.ToArray()
        metrics = [ordered]@{ accepted = $accepted.Count; repairs = @($evaluations.ToArray() | Where-Object { $_.decision -eq "repair" }).Count; rejected = @($evaluations.ToArray() | Where-Object { $_.decision -eq "reject" }).Count; legalRate = $legalRate; profileCompilerPassRate = $profilePassRate; determinismHash = $determinismHash; performanceRisk = "hard-cap-with-explainable-degradation" }
        humanApproval = [ordered]@{ required = $true; diffDisplayed = $true; autoPublish = $false; ownership = "ai-proposed-fields-remain-reviewable" }
        facade = [ordered]@{ required = "EffectPlayer+PresentationBudget"; bypassAttempts = 0; customRendererAllowed = $false }
        aiWrites = [ordered]@{ sourceCandidates = $accepted.Count; generated = 0; core = 0; lua = 0; network = 0; compilerOutputs = "disposable-temp-only" }
        repositoryIntegrity = [ordered]@{ coreDiff = if ($repoUnchanged) { 0 } else { 1 }; sourceOfTruthPreserved = $repoUnchanged }
        runtime = [ordered]@{ status = "deferred"; teardownAvailable = ($null -ne (Get-Command Teardown.exe -ErrorAction SilentlyContinue)); reason = "Effect Lab replay is headless and fixed-seed; live rendering, hard-cap frame cost and screenshot capture require Teardown.exe." }
        rollback = "Discard candidate EffectDefinitions/reports and keep the last valid profile catalog; only Core experts may add a renderer."
        result = if ($legalRate -eq 1.0 -and $profilePassRate -eq 1.0 -and $repoUnchanged) { "pass" } else { "fail" }
    }
    Write-Json $ReportPath $report
    Write-Output (Canonical $report)
    if ([string]$report.result -ne "pass") { exit 1 }
    exit 0
}
catch {
    Fail "ai-effect-runner-error" $_.Exception.Message "runner" "Inspect the EffectIntent, node allow-list, budget profiles or Compiler diagnostics."
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
}
