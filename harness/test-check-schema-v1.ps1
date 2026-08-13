# Self-test for check-schema-v1.ps1.

$ErrorActionPreference = "Stop"
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$checker = Join-Path $repositoryRoot "harness\check-schema-v1.ps1"
$fixture = Join-Path $repositoryRoot "harness\data\schemas\cm2-schema-v1-fixtures.json"
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("schema-v1-fixtures-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

function Run-Check([string]$fixtureRoot) {
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $checker -Path $fixtureRoot 2>$null | Out-String | Out-Null
        return $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $previousPreference }
}

try {
    $valid = Join-Path $tempRoot "valid"
    New-Item -ItemType Directory -Path (Join-Path $valid "schemas\cm2") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $valid "harness\data\schemas") -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $repositoryRoot "schemas\cm2\source-envelope-v1.json") -Destination (Join-Path $valid "schemas\cm2\source-envelope-v1.json")
    Copy-Item -LiteralPath $fixture -Destination (Join-Path $valid "harness\data\schemas\cm2-schema-v1-fixtures.json")
    if ((Run-Check $valid) -ne 0) { throw "valid schema catalog was rejected" }
    Write-Host "[PASS] accepts six core Schema v1 kinds and 30 negative fixtures"

    $missingField = Join-Path $tempRoot "missing-field"
    Copy-Item -LiteralPath $valid -Destination $missingField -Recurse
    $catalogPath = Join-Path $missingField "schemas\cm2\source-envelope-v1.json"
    (Get-Content -Raw -LiteralPath $catalogPath).Replace('"budgetImpact":"renderer class"', '"budgetImpact":null') | Set-Content -LiteralPath $catalogPath -Encoding utf8
    if ((Run-Check $missingField) -eq 0) { throw "missing metadata was accepted" }
    Write-Host "[PASS] rejects missing field metadata"

    $brokenReference = Join-Path $tempRoot "broken-reference"
    Copy-Item -LiteralPath $valid -Destination $brokenReference -Recurse
    $fixturePath = Join-Path $brokenReference "harness\data\schemas\cm2-schema-v1-fixtures.json"
    $brokenDocument = Get-Content -Raw -LiteralPath $fixturePath | ConvertFrom-Json
    $brokenDocument.bases | Where-Object { $_.id -eq "cm2:effect.ray" } | ForEach-Object { $_.runtime.assetId = "cm2:asset.missing" }
    $brokenDocument.knownReferences = @($brokenDocument.knownReferences | Where-Object { $_ -ne "cm2:asset.beam" })
    $brokenDocument | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $fixturePath -Encoding utf8
    if ((Run-Check $brokenReference) -eq 0) { throw "broken reference in valid fixture was accepted" }
    Write-Host "[PASS] rejects broken reference in valid fixture"

    Write-Host "Self-test passed." -ForegroundColor Green
    exit 0
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
