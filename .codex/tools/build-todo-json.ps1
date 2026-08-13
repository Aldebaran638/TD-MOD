$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$targetPath = Join-Path $repoRoot 'TEARDOWN_SHIP_PLATFORM_TODO.json'
$upgraderPath = Join-Path $repoRoot '.codex\skills\teardown-autonomous-testing\scripts\upgrade_todo_plan.py'
$validatorPath = Join-Path $repoRoot '.codex\skills\teardown-autonomous-testing\scripts\validate_todo_plan.py'

if (-not (Test-Path -LiteralPath $targetPath -PathType Leaf)) {
    throw "Authoritative executable Todo not found: $targetPath"
}
if (-not (Test-Path -LiteralPath $upgraderPath -PathType Leaf)) {
    throw "Executable-plan upgrader not found: $upgraderPath"
}
if (-not (Test-Path -LiteralPath $validatorPath -PathType Leaf)) {
    throw "Executable-plan validator not found: $validatorPath"
}

# TEARDOWN_SHIP_PLATFORM_TODO.json is the sole machine-readable plan authority.
# This compatibility entrypoint refreshes derived contracts/fingerprints only;
# it never rebuilds business fields or historical state from Markdown.
& python $upgraderPath $targetPath
if ($LASTEXITCODE -ne 0) { throw 'Executable-plan refresh failed.' }
& python $validatorPath $targetPath
if ($LASTEXITCODE -ne 0) { throw 'Executable-plan validation failed after refresh.' }
Write-Output "Refreshed $targetPath in place without changing its business-plan source or history."
