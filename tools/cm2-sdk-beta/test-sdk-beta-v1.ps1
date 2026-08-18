# Self-test for Creator SDK Beta headless conformance.

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$checker = Join-Path $PSScriptRoot "check-sdk-beta-v1.ps1"
$runner = Join-Path $PSScriptRoot "run-sdk-beta-v1.ps1"
$policy = Join-Path $root "docs\sdk-beta-v1.json"
$fixture = Join-Path $root "docs\candidates\sdk-beta-v1.fixture.json"
$result = Join-Path $root "docs\candidates\sdk-beta-v1.result.json"

function Assert-True([bool]$condition, [string]$message) {
    if (-not $condition) { throw ("Creator SDK Beta self-test failed: " + $message) }
    Write-Host ("[PASS] " + $message) -ForegroundColor Green
}
function Invoke-Tool([string]$scriptPath, [string[]]$arguments) {
    $saved = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath @arguments *> $null
    $code = [int]$LASTEXITCODE; $ErrorActionPreference = $saved; return $code
}
function Canonical([object]$value) { return ($value | ConvertTo-Json -Depth 100 -Compress) }

Assert-True ((Invoke-Tool $checker @()) -eq 0) "Beta policy/checker accepts three cohort profiles"
Assert-True ((Invoke-Tool $runner @("-PolicyPath", $policy, "-FixturePath", $fixture, "-ReportPath", $result)) -eq 0) "Beta runner passes Alpha, clean-room and compatibility suites"
$first = Get-Content -Raw -LiteralPath $result | ConvertFrom-Json
Assert-True ([string]$first.result -eq "pass" -and [string]$first.status -eq "headless-beta") "Beta report is passing and explicitly headless"
Assert-True (@($first.cohort).Count -eq 3 -and @($first.suites).Count -eq 3) "report covers all profiles and conformance suites"
Assert-True ([bool]$first.repeatableBuild -and [bool]$first.editorFree) "Beta acceptance is repeatable and editor-free"
Assert-True ([int]$first.externalAuthors -eq 0 -and [string]$first.runtimeStatus -in @("deferred", "not-run")) "external/runtime evidence is not fabricated"
Assert-True (@($first.resolvedBlockers | Where-Object {[string]$_.status -ne "resolved"}).Count -eq 0) "high-frequency blockers have resolutions"
$firstCanonical = Canonical $first
Assert-True ((Invoke-Tool $runner @("-PolicyPath", $policy, "-FixturePath", $fixture, "-ReportPath", $result)) -eq 0) "Beta runner repeats successfully"
$secondCanonical = Canonical (Get-Content -Raw -LiteralPath $result | ConvertFrom-Json)
Assert-True ($firstCanonical -eq $secondCanonical) "Beta report is deterministic across repeated runs"

Write-Host "Creator SDK Beta self-test passed." -ForegroundColor Green
exit 0
