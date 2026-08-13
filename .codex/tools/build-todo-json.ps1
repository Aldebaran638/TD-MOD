$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$sourcePath = Join-Path $repoRoot 'TEARDOWN_SHIP_PLATFORM_TODO.md'
$targetPath = Join-Path $repoRoot 'TEARDOWN_SHIP_PLATFORM_TODO.json'
$upgraderPath = Join-Path $repoRoot '.codex\skills\teardown-autonomous-testing\scripts\upgrade_todo_plan.py'

if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
    throw "Source Todo document not found: $sourcePath"
}
if (-not (Test-Path -LiteralPath $upgraderPath -PathType Leaf)) {
    throw "Executable-plan upgrader not found: $upgraderPath"
}

$existing = $null
$existingById = @{}
if (Test-Path -LiteralPath $targetPath -PathType Leaf) {
    $existing = Get-Content -LiteralPath $targetPath -Raw -Encoding utf8 | ConvertFrom-Json
    foreach ($task in @($existing.tasks)) { $existingById[[string]$task.id] = $task }
}

$markdown = Get-Content -LiteralPath $sourcePath -Raw -Encoding utf8
$stepMatches = [regex]::Matches(
    $markdown,
    '(?ms)^### \[ \] Step (?<id>\d+\.\d+).(?<title>.+?)\r?\n\r?\n(?<body>.*?)(?=^### \[ \] Step |\z)'
)

$tasks = @(
    foreach ($match in $stepMatches) {
        $body = $match.Groups['body'].Value
        $fieldMatches = [regex]::Matches($body, '(?m)^- \*\*(?<label>[^*]+)\*\* (?<value>.*)$')
        if ($fieldMatches.Count -lt 5) {
            throw "Step $($match.Groups['id'].Value) has fewer than five required form fields."
        }
        $taskValue = $fieldMatches[0].Groups['value'].Value.Trim()
        $reasonValue = $fieldMatches[1].Groups['value'].Value.Trim()
        $outcomeValue = $fieldMatches[2].Groups['value'].Value.Trim()
        $criteriaValue = $fieldMatches[3].Groups['value'].Value.Trim()
        $formValue = $fieldMatches[4].Groups['value'].Value.Trim()

        $id = $match.Groups['id'].Value
        $stepId = "Step $id"
        $stageNumber = [int]($id.Split('.')[0])
        $old = $existingById[$stepId]
        $implementationStatus = if ($null -ne $old -and -not [string]::IsNullOrWhiteSpace([string]$old.implementation_status)) {
            [string]$old.implementation_status
        } elseif ($null -ne $old -and -not [string]::IsNullOrWhiteSpace([string]$old.status)) {
            [string]$old.status
        } else { 'not_started' }

        $value = [ordered]@{
            id = $stepId
            stage = "Gate $stageNumber"
            title = $match.Groups['title'].Value.Trim()
            implementation_status = $implementationStatus
            task_goal = ($taskValue + ' Reason: ' + $reasonValue)
            expected_outcome = $outcomeValue
            prerequisites = @(
                "Plan dependency and owner form: $formValue"
                if ($stageNumber -eq 0) { 'Gate prerequisite: repository baseline is readable and runnable' } else { "Gate prerequisite: Gate $($stageNumber - 1) exit criteria are approved" }
            )
            implementation_scope = @($taskValue)
            acceptance_criteria = @($criteriaValue)
            rollback = if ($null -ne $old -and -not [string]::IsNullOrWhiteSpace([string]$old.rollback)) { [string]$old.rollback } else { 'Use the rollback point in the plan; never overwrite the last valid generated artifact, and record reason, impact, and recovery version in the migration ledger.' }
            evidence = if ($null -ne $old -and $null -ne $old.evidence) { $old.evidence } else {
                [ordered]@{ code_or_document = ''; automated_tests = ''; harness = ''; runtime_or_performance = ''; rollback_record = '' }
            }
            source_plan = "TEARDOWN_SHIP_PLATFORM_EVOLUTION_PLAN.md#step-$id"
        }
        foreach ($field in @('status_reason', 'developer_confirmed', 'verification_status', 'verification_status_reason', 'verification', 'test_infrastructure_prerequisites', 'plan_order')) {
            if ($null -ne $old -and $null -ne $old.PSObject.Properties[$field]) { $value[$field] = $old.$field }
        }
        $value
    }
)

if ($tasks.Count -ne 80) {
    throw "Expected exactly 80 Step tasks, found $($tasks.Count)."
}

$document = [ordered]@{
    schema_version = if ($null -ne $existing) { [string]$existing.schema_version } else { 'cm2.todo/1' }
    project = 'Content Mod 2 ship platform evolution'
    developer_confirmed_unable = if ($null -ne $existing) { $existing.developer_confirmed_unable } else { [ordered]@{ enabled = $false; field = 'developer_confirmed'; task_ids = @() } }
    source_plan = 'TEARDOWN_SHIP_PLATFORM_EVOLUTION_PLAN.md'
    task_count = $tasks.Count
    tasks = $tasks
}

$utf8NoBom = New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText($targetPath, ($document | ConvertTo-Json -Depth 100), $utf8NoBom)
& python $upgraderPath $targetPath
if ($LASTEXITCODE -ne 0) { throw 'Executable-plan upgrade failed.' }
Write-Output "Generated $targetPath with $($tasks.Count) executable tasks while preserving implementation, verification, and evidence history."
