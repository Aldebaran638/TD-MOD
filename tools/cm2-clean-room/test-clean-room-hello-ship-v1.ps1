# Self-test for the isolated clean-room hello-ship conformance runner.

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$runner = Join-Path $PSScriptRoot "run-clean-room-hello-ship-v1.ps1"
$fixture = Join-Path $root "docs\candidates\clean-room-hello-ship-v1.fixture.json"
$report = Join-Path $root "docs\candidates\clean-room-hello-ship-v1.result.json"

function Assert-True([bool]$condition, [string]$message) {
    if (-not $condition) { throw ("Clean-room self-test failed: " + $message) }
    Write-Host ("[PASS] " + $message) -ForegroundColor Green
}
function Invoke-Runner {
    $saved = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner -FixturePath $fixture -ReportPath $report *> $null
    $code = [int]$LASTEXITCODE
    $ErrorActionPreference = $saved
    return $code
}

Assert-True ((Invoke-Runner) -eq 0) "runs the clean-room build/compile/preview/install/uninstall matrix"
Assert-True (Test-Path -LiteralPath $report -PathType Leaf) "writes the machine-readable conformance report"
$result = Get-Content -Raw -LiteralPath $report | ConvertFrom-Json
Assert-True ([string]$result.result -eq "pass") "conformance report is passing"
Assert-True ([string]$result.packageId -eq "cm2.cleanroom.hello-ship" -and [int]$result.bodyCount -eq 1) "report identifies the one-body package"
Assert-True ([int]$result.contentDefinitionCount -eq 4 -and [int]$result.assetCount -eq 4 -and [int]$result.generatedCount -eq 1) "report covers definitions, owned assets and generated data"
Assert-True ([int]$result.coreDiff -eq 0 -and -not [bool]$result.runtimeLua) "report proves no Core diff and no Runtime Lua"
Assert-True ([string]$result.install.uninstall -eq "pass" -and [int]$result.install.generatedLeftovers -eq 0) "install/uninstall leaves no generated package output"
Assert-True ([string]$result.negativeCases.missingDependency -eq "rejected" -and [string]$result.negativeCases.futureSchema -eq "rejected" -and [string]$result.negativeCases.privateReference -eq "rejected") "negative conformance cases are rejected"
Assert-True ([string]$result.runtime.status -eq "deferred" -or [string]$result.runtime.status -eq "not-run") "runtime status is explicit rather than fabricated"
Assert-True ([string]$result.packageFingerprint -ne "" -and [string]$result.compilerCatalogHash -ne "") "package and compiler hashes are recorded"

Write-Host "Clean-room self-test passed." -ForegroundColor Green
exit 0
