# Self-tests for check-source-of-truth.ps1.

$ErrorActionPreference = "Stop"
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$checker = Join-Path $repositoryRoot "harness\check-source-of-truth.ps1"
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("source-of-truth-fixtures-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

function Write-Utf8([string]$path, [string]$content) {
    $directory = Split-Path -Parent $path
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    [IO.File]::WriteAllText($path, $content, (New-Object Text.UTF8Encoding($false)))
}

function Run-Check([string]$fixtureRoot) {
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $checker -Path $fixtureRoot 2>$null | Out-String | Out-Null
        return $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }
}

try {
    $valid = Join-Path $tempRoot "valid"
    New-Item -ItemType Directory -Path (Join-Path $valid "Content Mod 2") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $valid "Global Mod") -Force | Out-Null
    Write-Utf8 (Join-Path $valid "Content Mod 2\main.xml") "<scene/>"
    Write-Utf8 (Join-Path $valid "Content Mod 2\main.lua") "-- fixture"
    Write-Utf8 (Join-Path $valid "docs\source-of-truth.json") @'
{
  "schema_version": "cm2.source-of-truth/1",
  "product": "Content Mod 2",
  "source_root": "Content Mod 2",
  "generated_target": "Global Mod",
  "required_source_files": ["main.xml", "main.lua"],
  "target_policy": {"manual_edits": "forbidden"}
}
'@
    if ((Run-Check $valid) -ne 0) { throw "valid source-of-truth fixture was rejected" }
    Write-Host "[PASS] accepts valid source-of-truth contract"

    $missing = Join-Path $tempRoot "missing-target"
    Copy-Item -LiteralPath $valid -Destination $missing -Recurse
    Remove-Item -LiteralPath (Join-Path $missing "Global Mod") -Recurse -Force
    if ((Run-Check $missing) -eq 0) { throw "missing generated target was accepted" }
    Write-Host "[PASS] rejects missing generated target"

    $wrongPolicy = Join-Path $tempRoot "wrong-policy"
    Copy-Item -LiteralPath $valid -Destination $wrongPolicy -Recurse
    $manifestPath = Join-Path $wrongPolicy "docs\source-of-truth.json"
    (Get-Content -Raw -LiteralPath $manifestPath).Replace('"forbidden"', '"allowed"') | Set-Content -LiteralPath $manifestPath -Encoding utf8
    if ((Run-Check $wrongPolicy) -eq 0) { throw "manual edit policy violation was accepted" }
    Write-Host "[PASS] rejects manual-edit policy violation"

    Write-Host "Self-test passed." -ForegroundColor Green
    exit 0
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
