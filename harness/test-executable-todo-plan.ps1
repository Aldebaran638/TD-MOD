# Runs contract/schema and fail-closed executable-plan regressions.

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$scripts = Join-Path $root '.codex\skills\teardown-autonomous-testing\scripts'
& python (Join-Path $scripts 'test_validate_contract.py')
if ($LASTEXITCODE -ne 0) { throw 'Verification Contract tests failed.' }
& python (Join-Path $scripts 'test_todo_plan.py')
if ($LASTEXITCODE -ne 0) { throw 'Executable Todo plan tests failed.' }
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root '.codex\tools\test-todo-stop.ps1')
if ($LASTEXITCODE -ne 0) { throw 'Executable Todo Stop Hook tests failed.' }
Write-Output 'Executable Todo plan self-test passed.'
