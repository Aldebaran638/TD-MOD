$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$checker = Join-Path $PSScriptRoot "check-generated-catalog-manifest-v1.ps1"
& $checker -Path $root
if ($LASTEXITCODE -ne 0) { throw "generated catalog manifest checker rejected the candidate" }
$manifestPath = Join-Path $root "docs\generated\cm2-generated-catalog-manifest-v1.json"
$original = [IO.File]::ReadAllText($manifestPath)
try {
    $bad = $original -replace '"outputHash":\s*"[0-9a-f]+"', '"outputHash": "0000000000000000000000000000000000000000000000000000000000000000"'
    [IO.File]::WriteAllText($manifestPath, $bad, (New-Object Text.UTF8Encoding($false)))
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $checker -Path $root 2>$null | Out-Null
        $staleExitCode = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $previousPreference }
    if ($staleExitCode -eq 0) { throw "stale outputHash was accepted" }
    Write-Host "[PASS] stale aggregate output hash fails before promotion"
}
finally {
    [IO.File]::WriteAllText($manifestPath, $original, (New-Object Text.UTF8Encoding($false)))
}
$lua = Get-Content -Raw (Join-Path $root "docs\generated\cm2-generated-catalog-v1.lua")
if ($lua -notmatch 'promotionAllowed = false' -or $lua -notmatch 'mode = "shadow"') { throw "legacy-safe shadow fixture is missing" }
Write-Host "[PASS] generated header/hash/manifest/entry closure and explicit shadow ownership are present"
Write-Host "Self-test passed."
exit 0
