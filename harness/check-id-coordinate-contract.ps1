# Validate the Gate 1 ID/version/coordinate contract and golden normalization.

param(
    [string]$Path = "."
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath $Path).Path
$contractDoc = Join-Path $root "docs\id-coordinate-contract.md"
$fixture = Join-Path $root "harness\data\contracts\id-coordinate-golden.json"
$normalizer = Join-Path $root "tools\normalize-cm2-contract.ps1"
$issues = New-Object System.Collections.Generic.List[string]

foreach ($required in @($contractDoc, $fixture, $normalizer)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { $issues.Add("missing contract artifact: $required") }
}
if ($issues.Count -eq 0) {
    try { $source = Get-Content -Raw -LiteralPath $fixture | ConvertFrom-Json }
    catch { $issues.Add("invalid golden fixture JSON: $($_.Exception.Message)") }
}
if ($issues.Count -eq 0) {
    if ([string]$source.schemaVersion -ne "cm2.contract/1") { $issues.Add("fixture schemaVersion must be cm2.contract/1") }
    $expected = @($source.expectedCases | ForEach-Object { [string]$_ } | Sort-Object)
    $actual = @($source.records | ForEach-Object { [string]$_.goldenCase } | Sort-Object)
    if (($expected -join ",") -ne ($actual -join ",")) { $issues.Add("golden cases must exactly cover root-body, shape-local, parent-anchor, mirror-mount") }
    $duplicateIds = @($source.records | ForEach-Object { ([string]$_.id).ToLowerInvariant() } | Group-Object | Where-Object Count -gt 1)
    if ($duplicateIds.Count -gt 0) { $issues.Add("fixture contains duplicate IDs") }
    foreach ($record in @($source.records)) {
        if ([string]$record.id -cne ([string]$record.id).ToLowerInvariant()) { $issues.Add("ID is not lowercase: $($record.id)") }
        if ([string]$record.localTransform.space -ne "parent-local") { $issues.Add("non-parent-local transform: $($record.id)") }
    }
}
if ($issues.Count -eq 0) {
    $normalized = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $normalizer -InputPath $fixture 2>$null | Out-String
    if ($LASTEXITCODE -ne 0) { $issues.Add("normalizer rejected golden fixture") }
    else {
        try { $result = $normalized | ConvertFrom-Json }
        catch { $issues.Add("normalizer did not return JSON: $($_.Exception.Message)") }
        if ($null -ne $result -and [string]$result.sha256 -ne [string]$source.expectedSha256) {
            $issues.Add("normalized SHA-256 mismatch: expected $($source.expectedSha256), got $($result.sha256)")
        }
        if ($null -ne $result -and [string]$result.canonicalText -match '-0(?:[,.|]|$)') {
            $issues.Add("normalized output contains negative zero")
        }
    }
}
if ($issues.Count -gt 0) {
    Write-Error ("ID/coordinate contract check failed:`n - " + ($issues -join "`n - "))
    exit 1
}

Write-Host "ID/coordinate contract passed: 4 golden cases, deterministic SHA-256 $($source.expectedSha256)." -ForegroundColor Green
exit 0
