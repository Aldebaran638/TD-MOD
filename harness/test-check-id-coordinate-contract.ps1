# Self-tests for check-id-coordinate-contract.ps1 and the normalizer.

$ErrorActionPreference = "Stop"
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$checker = Join-Path $repositoryRoot "harness\check-id-coordinate-contract.ps1"
$fixture = Join-Path $repositoryRoot "harness\data\contracts\id-coordinate-golden.json"
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("id-coordinate-fixtures-" + [Guid]::NewGuid().ToString("N"))
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
    New-Item -ItemType Directory -Path (Join-Path $valid "docs") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $valid "harness\data\contracts") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $valid "tools") -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $repositoryRoot "docs\id-coordinate-contract.md") -Destination (Join-Path $valid "docs\id-coordinate-contract.md")
    Copy-Item -LiteralPath $fixture -Destination (Join-Path $valid "harness\data\contracts\id-coordinate-golden.json")
    Copy-Item -LiteralPath (Join-Path $repositoryRoot "tools\normalize-cm2-contract.ps1") -Destination (Join-Path $valid "tools\normalize-cm2-contract.ps1")
    if ((Run-Check $valid) -ne 0) { throw "valid contract fixture was rejected" }
    Write-Host "[PASS] accepts ID/coordinate golden contract"

    $badHash = Join-Path $tempRoot "bad-hash"
    Copy-Item -LiteralPath $valid -Destination $badHash -Recurse
    $badPath = Join-Path $badHash "harness\data\contracts\id-coordinate-golden.json"
    (Get-Content -Raw -LiteralPath $badPath).Replace('7ba3d8c60860f13250f595fab05238f149666bb82fff7c50e3b4509e28bc75ba', '0000000000000000000000000000000000000000000000000000000000000000') | Set-Content -LiteralPath $badPath -Encoding utf8
    if ((Run-Check $badHash) -eq 0) { throw "golden hash mismatch was accepted" }
    Write-Host "[PASS] rejects golden hash mismatch"

    $badId = Join-Path $tempRoot "bad-id"
    Copy-Item -LiteralPath $valid -Destination $badId -Recurse
    $badIdPath = Join-Path $badId "harness\data\contracts\id-coordinate-golden.json"
    (Get-Content -Raw -LiteralPath $badIdPath).Replace('"cm2:mount.mirror"', '"CM2:mount.mirror"') | Set-Content -LiteralPath $badIdPath -Encoding utf8
    if ((Run-Check $badId) -eq 0) { throw "uppercase ID was accepted" }
    Write-Host "[PASS] rejects non-canonical ID"

    Write-Host "Self-test passed." -ForegroundColor Green
    exit 0
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
