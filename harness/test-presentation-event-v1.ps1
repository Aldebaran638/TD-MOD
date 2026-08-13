# Self-test for PresentationEvent v1 static contract and fixture semantics.

$ErrorActionPreference = "Stop"
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$checker = Join-Path $repositoryRoot "harness\check-presentation-event-v1.ps1"
$fixture = Join-Path $repositoryRoot "harness\data\net\presentation-event-v1-fixtures.json"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $checker -Path (Join-Path $repositoryRoot "Content Mod 2")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$data = Get-Content -Raw -LiteralPath $fixture | ConvertFrom-Json
$validJson = $data.valid | ConvertTo-Json -Depth 20 -Compress
if ($validJson -notmatch '"protocolVersion":"cm2.presentation-event/1"' -or $validJson -notmatch '"kind":"impact"') { throw "valid event fixture does not contain protocol/kind" }
foreach ($case in @("staleGeneration", "duplicateSequence", "unknownProtocol", "forbiddenCallback", "unknownKind")) {
    if ($null -eq $data.negative.PSObject.Properties[$case]) { throw "missing negative event fixture: $case" }
}
Write-Host "[PASS] valid DTO fixture and stale/version/forbidden/unknown negative cases are present"
Write-Host "Self-test passed." -ForegroundColor Green
exit 0
