# Headless Creator SDK Beta conformance runner.

param(
    [string]$PolicyPath = "",
    [string]$FixturePath = "",
    [string]$ReportPath = ""
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if ($PolicyPath -eq "") { $PolicyPath = Join-Path $root "docs\sdk-beta-v1.json" }
if ($FixturePath -eq "") { $FixturePath = Join-Path $root "docs\candidates\sdk-beta-v1.fixture.json" }
if ($ReportPath -eq "") { $ReportPath = Join-Path $root "docs\candidates\sdk-beta-v1.result.json" }
$utf8 = New-Object Text.UTF8Encoding($false)
function Canonical([object]$value) { return ($value | ConvertTo-Json -Depth 100 -Compress) }
function Write-Json([string]$path, [object]$value) {
    $parent = Split-Path -Parent $path
    if ($parent -and -not (Test-Path -LiteralPath $parent -PathType Container)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    [IO.File]::WriteAllText($path, (Canonical $value) + "`n", $utf8)
}
function Fail([string]$code, [string]$message, [string]$fieldPath, [string]$suggestion) {
    $report = [ordered]@{ schema = "cm2.creator-sdk-beta-error/1"; code = $code; fieldPath = $fieldPath; message = $message; suggestion = $suggestion; result = "fail" }
    Write-Json $ReportPath $report; Write-Output (Canonical $report); exit 1
}
function Invoke-Suite([string]$relativePath, [string]$label) {
    $path = Join-Path $root $relativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Fail "suite-missing" ("Required suite is missing: " + $relativePath) "requiredSuites" "Restore the conformance suite." }
    $saved = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $path *> $null
    $code = [int]$LASTEXITCODE; $ErrorActionPreference = $saved
    if ($code -ne 0) { Fail "suite-failed" ("Beta suite failed: " + $label) $label "Fix the failing Alpha/clean-room/compatibility contract before inviting authors." }
    return [ordered]@{ suite = $label; status = "pass" }
}

try {
    $policy = Get-Content -Raw -LiteralPath $PolicyPath | ConvertFrom-Json
    $fixture = Get-Content -Raw -LiteralPath $FixturePath | ConvertFrom-Json
    if ([string]$policy.schema -ne "cm2.creator-sdk-beta/1") { Fail "policy-schema" "SDK Beta policy schema mismatch" "schema" "Use the Beta v1 policy." }
    if ([string]$fixture.schema -ne "cm2.creator-sdk-beta-fixtures/1") { Fail "fixture-schema" "SDK Beta fixture schema mismatch" "schema" "Use the Beta fixture v1." }
    $suites = New-Object System.Collections.Generic.List[object]
    [void]$suites.Add((Invoke-Suite "tools\cm2-sdk\test-cm2-sdk-v1.ps1" "alpha-cli"))
    [void]$suites.Add((Invoke-Suite "tools\cm2-clean-room\test-clean-room-hello-ship-v1.ps1" "clean-room"))
    [void]$suites.Add((Invoke-Suite "tools\cm2-compat\test-compatibility-policy-v1.ps1" "compatibility"))
    $teardown = Get-Command Teardown.exe -ErrorAction SilentlyContinue
    $teardownProcess = Get-Process -Name teardown -ErrorAction SilentlyContinue | Select-Object -First 1
    $report = [ordered]@{
        schema = "cm2.creator-sdk-beta-report/1"
        status = "headless-beta"
        toolVersion = [string]$policy.toolVersion
        cohort = @($policy.cohort | ForEach-Object {[ordered]@{ id = [string]$_.id; profile = [string]$_.profile; editorRequired = [bool]$_.editorRequired; workflowCount = @($_.workflow).Count }})
        suites = @($suites.ToArray())
        resolvedBlockers = @($policy.resolvedBlockers)
        externalAuthors = [int]$policy.externalEvidence.authorsInvited
        teardownAvailable = ($null -ne $teardown -or $null -ne $teardownProcess)
        runtimeStatus = if ($null -eq $teardown -and $null -eq $teardownProcess) { "deferred" } else { "not-run" }
        s0s8 = "deferred-until-runtime"
        repeatableBuild = [bool]$policy.acceptance.repeatableBuild
        editorFree = [bool]$policy.acceptance.editorFree
        result = "pass"
    }
    Write-Json $ReportPath $report
    Write-Output (Canonical $report)
    exit 0
}
catch { Fail "beta-runner-error" $_.Exception.Message "runner" "Inspect the Beta fixture and suite reports." }
