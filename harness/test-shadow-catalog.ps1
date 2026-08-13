# Self-test for candidate shadow comparison and safe fallback behavior.

$ErrorActionPreference = "Stop"
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$builder = Join-Path $repositoryRoot "tools\cm2-slices\build-vertical-slices.ps1"
$compare = Join-Path $repositoryRoot "tools\cm2-shadow\compare-shadow.ps1"
$ownership = Join-Path $repositoryRoot "docs\candidates\ownership-map.json"
$shadowMap = Join-Path $repositoryRoot "docs\candidates\shadow-map.json"
$candidateRoot = Join-Path $repositoryRoot "docs\candidates\generated"
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("cm2-shadow-fixtures-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

function Run-Compare([string]$mapPath, [string]$source) {
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $compare -RepositoryRoot $repositoryRoot -OwnershipPath $ownership -ShadowMapPath $mapPath -CandidateRoot $candidateRoot -DefinitionSource $source -ReportPath (Join-Path $tempRoot ($source + ".json")) 2>$null | Out-String | Out-Null
        return $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $previousPreference }
}

try {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $builder -RepositoryRoot $repositoryRoot -OwnershipPath $ownership -OutputRoot $candidateRoot | Out-String | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "candidate rebuild failed" }
    if ((Run-Compare $shadowMap "legacy") -ne 0) { throw "legacy shadow comparison failed" }
    if ((Run-Compare $shadowMap "candidate-v1") -ne 0) { throw "candidate-v1 shadow comparison failed" }
    $candidateReport = Get-Content -Raw -LiteralPath (Join-Path $tempRoot "candidate-v1.json") | ConvertFrom-Json
    if (-not [bool]$candidateReport.candidateRuntimeEnabled) { throw "clean candidate shadow was not eligible" }
    Write-Host "[PASS] legacy and candidate-v1 shadow comparisons are clean and init-only"

    $brokenMap = Join-Path $tempRoot "broken-shadow-map.json"
    $broken = Get-Content -Raw -LiteralPath $shadowMap | ConvertFrom-Json
    $broken.slices[0].expectedEffectType = "impact"
    $broken | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $brokenMap -Encoding utf8
    if ((Run-Compare $brokenMap "candidate-v1") -eq 0) { throw "unexplained shadow difference was accepted" }
    $blocked = Get-Content -Raw -LiteralPath (Join-Path $tempRoot "candidate-v1.json") | ConvertFrom-Json
    if ($blocked.candidateRuntimeEnabled) { throw "blocked shadow was marked runtime-enabled" }
    Write-Host "[PASS] unexplained shadow difference blocks candidate and preserves legacy fallback"

    Write-Host "Self-test passed." -ForegroundColor Green
    exit 0
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
