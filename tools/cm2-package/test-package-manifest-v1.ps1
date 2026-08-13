# Self-test for PackageManifest v1 and the Data-only capability boundary.

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$runner = Join-Path $PSScriptRoot "run-package-manifest-v1.ps1"
$fixturePath = Join-Path $root "docs\candidates\package-manifest-v1.fixture.json"
$utf8 = New-Object Text.UTF8Encoding($false)

function Assert-True([bool]$condition, [string]$message) {
    if (-not $condition) { throw ("PackageManifest self-test failed: " + $message) }
    Write-Host ("[PASS] " + $message) -ForegroundColor Green
}
function Invoke-Package([string]$fixture, [string]$report, [string]$artifact) {
    $saved = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner -FixturePath $fixture -ReportPath $report -ArtifactPath $artifact *> $null
    $code = [int]$LASTEXITCODE
    $ErrorActionPreference = $saved
    return $code
}
function Write-Fixture([object]$document, [string]$path) { [IO.File]::WriteAllText($path, ($document | ConvertTo-Json -Depth 100), $utf8) }

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("cm2-package-manifest-test-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
try {
    $baseReport = Join-Path $tempRoot "base.report.json"
    $baseArtifact = Join-Path $tempRoot "base.package.json"
    Assert-True ((Invoke-Package $fixturePath $baseReport $baseArtifact) -eq 0) "accepts valid data-only PackageManifest"
    $base = Get-Content -Raw -LiteralPath $baseReport | ConvertFrom-Json
    Assert-True ([bool]$base.dataOnly -and -not [bool]$base.runtimeLuaAllowed) "enforces data-only/no Runtime Lua"
    Assert-True ([int]$base.contentEntryCount -eq 4 -and [int]$base.assetEntryCount -eq 2 -and [int]$base.generatedEntryCount -eq 1) "tracks source/assets/generated entries"
    Assert-True ([string]$base.manifestHash -eq [string]$base.packageArtifactHash) "manifest hash matches package artifact hash"
    Assert-True ((Get-FileHash -Algorithm SHA256 -LiteralPath $baseArtifact).Hash.ToLowerInvariant() -eq [string]$base.packageArtifactHash) "reported hash matches the emitted package artifact bytes"
    Assert-True ([bool]$base.compilerCapabilityCheck -and [string]$base.signature.fingerprint -ne "") "Capability gate and reproducible signature are recorded"
    Assert-True (@($base.compilerCapabilities).Count -eq 6 -and @($base.resourceCapabilities).Count -eq 2) "every data-only capability is backed by Compiler schema or resource policy"
    Assert-True ([bool]$base.compatibility.coreApi.compatible -and [bool]$base.compatibility.sdk.compatible -and @($base.compatibility.dependencies | Where-Object { -not $_.compatible }).Count -eq 0) "compatible Core, SDK, and dependency versions are accepted"
    Assert-True ([string]$base.coreOnlyFallback.policy -eq "builtin-only" -and (@($base.coreOnlyFallback.packageIds) -join "|") -eq "cm2.core.schemas") "Core-only fallback excludes the third-party package"
    Assert-True ([int]$base.negativeCases.Count -eq 12) "negative fixture coverage is complete"

    $secondReport = Join-Path $tempRoot "second.report.json"
    $secondArtifact = Join-Path $tempRoot "second.package.json"
    Assert-True ((Invoke-Package $fixturePath $secondReport $secondArtifact) -eq 0) "rebuilds the package into a second clean root"
    Assert-True ([IO.File]::ReadAllText($baseArtifact) -ceq [IO.File]::ReadAllText($secondArtifact)) "two clean builds emit byte-identical package artifacts"

    $cases = @(
        @{ Name = "missing dependency"; Mutate = { param($d) $d.lock.packages = @($d.lock.packages | Where-Object {$_.packageId -ne "cm2.core.schemas"}) } },
        @{ Name = "dependency cycle"; Mutate = { param($d) $d.dependencyGraph.'cm2.core.schemas' = @("cm2.thirdparty.hello-ship") } },
        @{ Name = "duplicate content ID"; Mutate = { param($d) $d.manifest.contentEntries += $d.manifest.contentEntries[0] } },
        @{ Name = "path traversal"; Mutate = { param($d) $d.manifest.contentEntries[0].source = "pkg://cm2.thirdparty.hello-ship/../escape.json" } },
        @{ Name = "unknown capability"; Mutate = { param($d) $d.manifest.capabilities += "ExecuteLua" } },
        @{ Name = "unsupported Lua entrypoint"; Mutate = { param($d) $d.manifest.entrypoints.lua = "script/runtime.lua" } },
        @{ Name = "budget overflow"; Mutate = { param($d) $d.manifest.budget.body = 3 } },
        @{ Name = "asset hash mismatch"; Mutate = { param($d) $d.manifest.assetEntries[0].hash = "wrong-hash" } },
        @{ Name = "future schema"; Mutate = { param($d) $d.manifest.schemaVersion = "cm2.package/2" } },
        @{ Name = "incompatible Core API"; Mutate = { param($d) $d.manifest.coreApiVersionRange = ">=2.0.0 <3.0.0" } },
        @{ Name = "incompatible SDK"; Mutate = { param($d) $d.manifest.sdkVersionRange = ">=2.0.0 <3.0.0" } },
        @{ Name = "incompatible dependency version"; Mutate = { param($d) ($d.lock.packages | Where-Object { $_.packageId -eq "cm2.core.schemas" }).version = "2.0.0" } },
        @{ Name = "signature mismatch"; Mutate = { param($d) $d.manifest.signature.value = "wrong-signature" } }
    )
    foreach ($case in $cases) {
        $document = Get-Content -Raw -LiteralPath $fixturePath | ConvertFrom-Json
        & $case.Mutate $document
        $caseFixture = Join-Path $tempRoot (($case.Name -replace "[^A-Za-z0-9]", "-") + ".json")
        $caseReport = Join-Path $tempRoot (($case.Name -replace "[^A-Za-z0-9]", "-") + ".report.json")
        Write-Fixture $document $caseFixture
        $caseArtifact = Join-Path $tempRoot (($case.Name -replace "[^A-Za-z0-9]", "-") + ".package.json")
        [IO.File]::WriteAllText($caseArtifact, "last-valid-package", $utf8)
        Assert-True ((Invoke-Package $caseFixture $caseReport $caseArtifact) -ne 0) ("rejects " + $case.Name)
        Assert-True ([IO.File]::ReadAllText($caseArtifact) -ceq "last-valid-package") ("preserves last valid artifact for " + $case.Name)
    }
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host "Self-test passed." -ForegroundColor Green
exit 0
