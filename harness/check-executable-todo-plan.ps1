# Validates the authoritative CM2 executable 80-Step plan and every embedded contract.

param([string]$Path = ".")
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $Path).Path
$todo = Join-Path $root 'TEARDOWN_SHIP_PLATFORM_TODO.json'
$validator = Join-Path $root '.codex\skills\teardown-autonomous-testing\scripts\validate_todo_plan.py'
& python $validator $todo
if ($LASTEXITCODE -ne 0) { throw 'Executable Todo plan validation failed.' }
