# Regression tests against the authoritative executable plan.

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$hook = Join-Path $PSScriptRoot 'check-todo-stop.ps1'
$source = Join-Path $root 'TEARDOWN_SHIP_PLATFORM_TODO.json'
$temp = Join-Path ([IO.Path]::GetTempPath()) ('cm2-hook-unconfirmed-' + [Guid]::NewGuid().ToString('N') + '.json')
function Assert-True([bool]$condition, [string]$message) {
    if (-not $condition) { throw ('Todo hook executable-plan test failed: ' + $message) }
    Write-Host ('[PASS] ' + $message) -ForegroundColor Green
}
try {
    $document = Get-Content -Raw -Encoding utf8 -LiteralPath $source | ConvertFrom-Json
    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $hook -TaskPath $source
    Assert-True ([string]$output -match 'block' -and [string]$output -match 'Step 1\.7' -and [string]$output -notmatch 'Continue with Step 0\.1|Continue with Step 0\.3|Continue with Step 0\.4|Continue with Step 1\.5') 'current source skips the exceptional Step 0.1, Step 0.3, Step 0.4, and Step 1.5 and requests the next unresolved task'

    foreach ($task in @($document.tasks)) { $task.implementation_status = 'finish'; $task.verification_status = 'verified' }
    $document.tasks[0].implementation_status = 'unable'
    $document.tasks[0].verification_status = 'pending'
    $document.tasks[0].PSObject.Properties.Remove('unable_exception')
    $document.developer_confirmed_unable.task_ids = @($document.developer_confirmed_unable.task_ids | Where-Object { [string]$_ -ne 'Step 0.1' })
    [IO.File]::WriteAllText($temp, ($document | ConvertTo-Json -Depth 100), (New-Object Text.UTF8Encoding($false)))
    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $hook -TaskPath $temp
    Assert-True ([string]$output -match 'block' -and [string]$output -match 'unable_exception') 'unable without a special marker remains fail-closed even without the old allowlist'

    $document.tasks[0] | Add-Member -NotePropertyName unable_exception -NotePropertyValue ([ordered]@{
        marker = 'ENVIRONMENT_BLOCKED'
        reason = 'Live execution hit a documented environment limitation.'
        evidence = 'docs/evidence/hook-test-environment.json'
        reviewed_by = 'human'
        reviewed_at = '2026-08-15T00:00:00+08:00'
    }) -Force
    [IO.File]::WriteAllText($temp, ($document | ConvertTo-Json -Depth 100), (New-Object Text.UTF8Encoding($false)))
    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $hook -TaskPath $temp
    Assert-True ([string]::IsNullOrWhiteSpace([string]$output)) 'complete task-level special marker allows an exceptional unable'
    Write-Host 'Todo hook executable-plan regression passed.' -ForegroundColor Green
    exit 0
}
finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue }
}
