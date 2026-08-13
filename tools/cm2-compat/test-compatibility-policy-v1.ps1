# Executable regression for the five-surface compatibility/deprecation policy.

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$checker = Join-Path $PSScriptRoot "check-compatibility-policy-v1.ps1"
$migrator = Join-Path $PSScriptRoot "migrate-compat-v1.ps1"
$resolver = Join-Path $PSScriptRoot "resolve-compatibility-v1.ps1"
$packageValidator = Join-Path $root "tools\cm2-package\run-package-manifest-v1.ps1"
$fixturePath = Join-Path $root "docs\candidates\compatibility-policy-v1.fixture.json"
$policyPath = Join-Path $root "docs\compatibility-policy-v1.json"
$packageFixturePath = Join-Path $root "testing\fixtures\creator_sdk\alpha_project\package.source.json"
$resultPath = Join-Path $root "docs\candidates\compatibility-policy-v1.result.json"
$utf8 = New-Object Text.UTF8Encoding($false)
$script:assertions = 0

function Assert-True([bool]$condition, [string]$message) {
    if (-not $condition) { throw ("Compatibility self-test failed: " + $message) }
    $script:assertions++
    Write-Host ("[PASS] " + $message) -ForegroundColor Green
}
function Canonical([object]$value) { return ($value | ConvertTo-Json -Depth 100 -Compress) }
function Write-Document([string]$path, [object]$value) { [IO.File]::WriteAllText($path, (Canonical $value), $utf8) }
function Read-Document([string]$path) { return Get-Content -Raw -LiteralPath $path | ConvertFrom-Json }
function Sha256-File([string]$path) { return (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant() }
function Invoke-Script([string]$path, [string[]]$arguments) {
    $saved = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $lines = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $path @arguments 2>&1)
    $code = [int]$LASTEXITCODE
    $ErrorActionPreference = $saved
    $jsonLine = @($lines | ForEach-Object { [string]$_ } | Where-Object { $_.TrimStart().StartsWith("{") }) | Select-Object -Last 1
    $json = if ($null -ne $jsonLine) { $jsonLine | ConvertFrom-Json } else { $null }
    return [pscustomobject]@{ code = $code; json = $json; lines = @($lines | ForEach-Object { [string]$_ }) }
}
function New-Case([object]$value, [string]$name, [string]$temporaryRoot) {
    $path = Join-Path $temporaryRoot ($name + ".input.json")
    Write-Document $path $value
    return $path
}
function Invoke-Migration([string]$inputPath, [string]$outputPath, [string]$reportPath) {
    return Invoke-Script $migrator @("-InputPath", $inputPath, "-OutputPath", $outputPath, "-ReportPath", $reportPath)
}
function Invoke-Resolution([object]$row, [string]$reportPath) {
    return Invoke-Script $resolver @(
        "-PackageSchema", [string]$row.packageSchema,
        "-PackageCoreRange", [string]$row.coreRange,
        "-PackageSdkRange", [string]$row.sdkRange,
        "-BuildFormat", [string]$row.buildFormat,
        "-CoreApiVersion", [string]$row.core,
        "-SdkVersion", [string]$row.sdk,
        "-PackageId", "cm2.compat.matrix",
        "-ReportPath", $reportPath
    )
}
function Assert-Rejection([object]$result, [string]$code, [string]$message) {
    Assert-True ($result.code -ne 0 -and $null -ne $result.json -and [string]$result.json.result -eq "fail") ($message + " fails closed")
    Assert-True ([string]$result.json.code -eq $code) ($message + " returns " + $code)
    foreach ($field in @("packageId", "definitionId", "fieldPath", "message", "suggestion")) {
        Assert-True ($null -ne $result.json.PSObject.Properties[$field]) ($message + " exposes stable " + $field)
    }
}

$fixture = Read-Document $fixturePath
$policy = Read-Document $policyPath
$policyHash = Sha256-File $policyPath
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("cm2-compat-test-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
try {
    Assert-True ((Invoke-Script $checker @()).code -eq 0) "static checker accepts the public matrix, resolver wiring and dated ledger"
    Assert-True (@($policy.supportMatrix).Count -eq 5) "policy covers source, package, Core, SDK and build-format surfaces"

    $effectInput = New-Case $fixture.validV0Effect "effect-v0" $tempRoot
    $effectInputBytes = [IO.File]::ReadAllText($effectInput)
    $effectOutput = Join-Path $tempRoot "effect-v1.json"
    $effectReportPath = Join-Path $tempRoot "effect-v1.report.json"
    $effectResult = Invoke-Migration $effectInput $effectOutput $effectReportPath
    Assert-True ($effectResult.code -eq 0) "major-0 Effect migrates through the explicit reader"
    Assert-True ([IO.File]::ReadAllText($effectInput) -ceq $effectInputBytes) "Effect migration does not mutate its source"
    $effect = Read-Document $effectOutput
    $effectReport = Read-Document $effectReportPath
    Assert-True ([string]$effect.schemaVersion -eq "cm2.effect/1" -and [string]$effect.runtime.effectType -eq "impact" -and [string]$effect.runtime.assetId -eq "cm2:asset.compat") "Effect writer emits required canonical v1 fields"
    Assert-True ($null -eq $effect.runtime.PSObject.Properties["type"] -and $null -eq $effect.runtime.PSObject.Properties["asset"]) "Effect writer deletes deprecated aliases"
    Assert-True ([string]$effect.editor.compatibility.unknownRuntimeFields.legacyOptional -eq "preserve-me" -and [string]$effect.editor.futureColor -eq "amber") "unknown optional Runtime and Editor data round-trip outside Runtime projection"
    Assert-True ([string]$effectReport.policyHash -eq $policyHash -and [bool]$effectReport.canonicalAliasesRemoved) "Effect report binds migration to policy hash and alias-removal evidence"
    $effectSecond = Join-Path $tempRoot "effect-v1-second.json"
    Assert-True ((Invoke-Migration $effectOutput $effectSecond (Join-Path $tempRoot "effect-v1-second.report.json")).code -eq 0) "canonical v1 Effect is readable by the same writer"
    Assert-True ([IO.File]::ReadAllText($effectOutput) -ceq [IO.File]::ReadAllText($effectSecond)) "Effect migration is byte-idempotent"

    $weaponInput = New-Case $fixture.validV0Weapon "weapon-v0" $tempRoot
    $weaponOutput = Join-Path $tempRoot "weapon-v1.json"
    Assert-True ((Invoke-Migration $weaponInput $weaponOutput (Join-Path $tempRoot "weapon-v1.report.json")).code -eq 0) "major-0 Weapon migrates through explicit behaviour/effect aliases"
    $weapon = Read-Document $weaponOutput
    Assert-True ([string]$weapon.runtime.behavior -eq "ray" -and [string]$weapon.runtime.effectId -eq "cm2:effect.compat" -and [double]$weapon.runtime.fireRateHz -eq 1) "Weapon writer emits canonical behavior, effectId and deterministic defaults"
    Assert-True ($null -eq $weapon.runtime.PSObject.Properties["behaviour"] -and $null -eq $weapon.runtime.PSObject.Properties["effect"]) "Weapon writer deletes deprecated aliases"
    Assert-True ([int]$weapon.editor.compatibility.unknownRuntimeFields.futureOptionalCadence -eq 3) "Weapon unknown optional Runtime data is preserved outside Runtime projection"

    $packageCase = $fixture.validV0Package | ConvertTo-Json -Depth 100 | ConvertFrom-Json
    $packageCase | Add-Member -NotePropertyName futureDisplayHints -NotePropertyValue ([ordered]@{ color = "amber" })
    $packageInput = New-Case $packageCase "package-v0" $tempRoot
    $packageOutput = Join-Path $tempRoot "package-v1.json"
    $packageReportPath = Join-Path $tempRoot "package-v1.report.json"
    Assert-True ((Invoke-Migration $packageInput $packageOutput $packageReportPath).code -eq 0) "major-0 Package migrates through the explicit reader"
    $package = Read-Document $packageOutput
    Assert-True ([string]$package.schemaVersion -eq "cm2.package/1" -and [string]$package.buildFormatVersion -eq "cm2.package-build/1") "Package writer emits canonical package/build versions"
    Assert-True ([string]$package.entrypoints.runtime -eq "data-only" -and $null -eq $package.entrypoints.lua) "Package migration retains the data-only security boundary"
    Assert-True ([string]$package.provenance.migratedFrom -eq "cm2.package/0" -and [string]$package.provenance.compatibility.unknownPackageFields.futureDisplayHints.color -eq "amber") "Package migration records provenance and isolates unknown optional fields"
    $packageSecond = Join-Path $tempRoot "package-v1-second.json"
    Assert-True ((Invoke-Migration $packageOutput $packageSecond (Join-Path $tempRoot "package-v1-second.report.json")).code -eq 0) "canonical v1 Package is readable by the same writer"
    Assert-True ([IO.File]::ReadAllText($packageOutput) -ceq [IO.File]::ReadAllText($packageSecond)) "Package migration is byte-idempotent"

    $optionalInput = New-Case $fixture.unknownOptional "unknown-optional" $tempRoot
    $optionalOutput = Join-Path $tempRoot "optional-v1.json"
    Assert-True ((Invoke-Migration $optionalInput $optionalOutput (Join-Path $tempRoot "optional.report.json")).code -eq 0) "unknown optional field migrates with warning"
    $optional = Read-Document $optionalOutput
    Assert-True ([bool]$optional.editor.unknownOptional.futureUi -and [string]$optional.editor.compatibility.unknownRuntimeFields.futureOptional.quality -eq "ultra") "optional data is round-tripped without Runtime projection"

    $lastValidOutput = Join-Path $tempRoot "last-valid.json"
    $lastValidReport = Join-Path $tempRoot "last-valid.report.json"
    [IO.File]::WriteAllText($lastValidOutput, "last-valid-output", $utf8)
    [IO.File]::WriteAllText($lastValidReport, "last-valid-report", $utf8)
    $missing = Invoke-Migration (New-Case $fixture.missingRequired "missing-required" $tempRoot) $lastValidOutput $lastValidReport
    Assert-Rejection $missing "missing-required" "missing required source field"
    Assert-True ([IO.File]::ReadAllText($lastValidOutput) -ceq "last-valid-output" -and [IO.File]::ReadAllText($lastValidReport) -ceq "last-valid-report") "failed migration preserves exact last-valid output and report"
    Assert-Rejection (Invoke-Migration (New-Case $fixture.futureRequired "future-required" $tempRoot) (Join-Path $tempRoot "future.json") (Join-Path $tempRoot "future.report.json")) "future-required" "future schema"
    Assert-Rejection (Invoke-Migration (New-Case $fixture.securitySensitive "security-sensitive" $tempRoot) (Join-Path $tempRoot "security.json") (Join-Path $tempRoot "security.report.json")) "security-sensitive-unknown" "security-sensitive Runtime field"
    Assert-Rejection (Invoke-Migration (New-Case $fixture.unsupportedOld "unsupported-old" $tempRoot) (Join-Path $tempRoot "old.json") (Join-Path $tempRoot "old.report.json")) "unsupported-version" "unsupported old schema"

    $versionMatrix = New-Object System.Collections.Generic.List[object]
    foreach ($row in @($fixture.versionMatrix)) {
        $resolutionPath = Join-Path $tempRoot ("resolve-" + [string]$row.id + ".json")
        $resolution = Invoke-Resolution $row $resolutionPath
        $expectedPass = [string]$row.expected -eq "pass"
        Assert-True ((($resolution.code -eq 0) -eq $expectedPass)) ("version matrix result matches " + [string]$row.id)
        Assert-True ([string]$resolution.json.policyHash -eq $policyHash) ("version matrix binds policy hash for " + [string]$row.id)
        if ($expectedPass) { Assert-True ([bool]$resolution.json.compatible -and [string]$resolution.json.result -eq "pass") "compatible matrix row is accepted" }
        else { Assert-True ([string]$resolution.json.code -eq [string]$row.expected -and -not [bool]$resolution.json.compatible) ("incompatible matrix row fails with " + [string]$row.expected) }
        [void]$versionMatrix.Add([ordered]@{ id = [string]$row.id; expected = [string]$row.expected; actual = if ($expectedPass) { "pass" } else { [string]$resolution.json.code }; result = "pass" })
    }

    $publicReport = Join-Path $tempRoot "public-package-report.json"
    $publicArtifact = Join-Path $tempRoot "public-package-artifact.json"
    $public = Invoke-Script $packageValidator @("-FixturePath", $packageFixturePath, "-ReportPath", $publicReport, "-ArtifactPath", $publicArtifact, "-CoreApiVersion", "1.2.0", "-SdkVersion", "1.0.0")
    Assert-True ($public.code -eq 0) "public PackageManifest validator accepts compatible Consumer package"
    $publicPackageReport = Read-Document $publicReport
    Assert-True ([string]$publicPackageReport.compatibilityPolicyHash -eq $policyHash -and [string]$publicPackageReport.compatibility.policyHash -eq $policyHash) "public package report records the exact policy hash"
    Assert-True ((Invoke-Script $packageValidator @("-FixturePath", $packageFixturePath, "-ReportPath", (Join-Path $tempRoot "bad-core.report.json"), "-ArtifactPath", (Join-Path $tempRoot "bad-core.json"), "-CoreApiVersion", "2.0.0", "-SdkVersion", "1.0.0")).code -ne 0) "public PackageManifest validator rejects future Core"
    Assert-True ((Invoke-Script $packageValidator @("-FixturePath", $packageFixturePath, "-ReportPath", (Join-Path $tempRoot "bad-sdk.report.json"), "-ArtifactPath", (Join-Path $tempRoot "bad-sdk.json"), "-CoreApiVersion", "1.2.0", "-SdkVersion", "2.0.0")).code -ne 0) "public PackageManifest validator rejects future SDK"

    foreach ($entry in @($policy.deprecations)) {
        Assert-True ([string]$entry.writerRemoval.status -eq "verified" -and [string]$entry.writerRemoval.evidence -ne "") ("deprecation writer removal has evidence: " + [string]$entry.id)
        Assert-True ([string]$entry.readerRemoval.status -eq "not-eligible" -and [string]$entry.readerRemoval.evidence -ne "") ("deprecation reader retention has evidence: " + [string]$entry.id)
    }

    $result = [ordered]@{
        schema = "cm2.compatibility-test-report/1"
        policyHash = $policyHash
        assertions = $script:assertions
        surfaces = @($policy.supportMatrix | ForEach-Object { [string]$_.surface })
        migrations = [ordered]@{ effect = "pass"; weapon = "pass"; package = "pass"; byteIdempotent = $true; canonicalAliasesRemoved = $true; inputMutated = $false }
        unknownOptional = "preserved-outside-runtime"
        versionMatrix = $versionMatrix.ToArray()
        publicPackageValidation = [ordered]@{ compatible = "accepted"; futureCore = "rejected"; futureSdk = "rejected"; policyHashMatched = $true }
        negativeCases = [ordered]@{ missingRequired = "rejected"; futureRequired = "rejected"; securitySensitive = "rejected"; unsupportedOld = "rejected" }
        lastValidPreserved = $true
        deprecationLedger = "writer-evidence-and-reader-retention-verified"
        result = "pass"
    }
    [IO.File]::WriteAllText($resultPath, (($result | ConvertTo-Json -Depth 100) + "`n"), $utf8)
}
finally {
    $resolvedTemp = [IO.Path]::GetFullPath($tempRoot)
    $resolvedSystemTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolvedTemp.StartsWith($resolvedSystemTemp, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolvedTemp)) {
        Remove-Item -LiteralPath $resolvedTemp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ("Compatibility policy self-test passed: " + $script:assertions + " assertions.") -ForegroundColor Green
exit 0
