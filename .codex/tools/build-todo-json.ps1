$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$sourcePath = Join-Path $repoRoot 'TEARDOWN_SHIP_PLATFORM_TODO.md'
$targetPath = Join-Path $repoRoot 'TEARDOWN_SHIP_PLATFORM_TODO.json'

if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
    throw "Source Todo document not found: $sourcePath"
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
        $stageNumber = [int]($id.Split('.')[0])
        $form = $formValue

        [ordered]@{
            id = "Step $id"
            stage = "Gate $stageNumber"
            title = $match.Groups['title'].Value.Trim()
            status = 'not_started'
            task_goal = ($taskValue + ' Reason: ' + $reasonValue)
            expected_outcome = $outcomeValue
            prerequisites = @(
                "Plan dependency and owner form: $form"
                if ($stageNumber -eq 0) { 'Gate prerequisite: repository baseline is readable and runnable' } else { "Gate prerequisite: Gate $($stageNumber - 1) exit criteria are approved" }
            )
            implementation_scope = @($taskValue)
            acceptance_criteria = @($criteriaValue)
            verification = @(
                'Run the automated tests and Harness checks for the affected scope.'
                'For entry, lifecycle, network, presentation, performance, or asset changes, attach the Teardown smoke or pressure evidence required by the plan.'
                'Record test output, version hash, screenshots/logs, or replay paths in the Todo form and PR.'
            )
            rollback = 'Use the rollback point in the plan; never overwrite the last valid generated artifact, and record reason, impact, and recovery version in the migration ledger.'
            evidence = [ordered]@{
                code_or_document = ''
                automated_tests = ''
                harness = ''
                runtime_or_performance = ''
                rollback_record = ''
            }
            source_plan = "TEARDOWN_SHIP_PLATFORM_EVOLUTION_PLAN.md#step-$($id)"
        }
    }
)

if ($tasks.Count -ne 80) {
    throw "Expected exactly 80 Step tasks, found $($tasks.Count)."
}

$document = [ordered]@{
    schema_version = 'cm2.todo/1'
    project = 'Content Mod 2 ship platform evolution'
    status_field = 'status'
    finish_value = 'finish'
    allowed_statuses = @('not_started', 'in_progress', 'finish', 'unable')
    completion_statuses = @('finish', 'unable')
    hook_contract = [ordered]@{
        stop_event = 'Stop'
        rule = 'A task allows stopping when its status is finish or unable. Any other status blocks stopping and requests continuation.'
        checker = '.codex/hooks/check-todo-stop.ps1'
    }
    source_plan = 'TEARDOWN_SHIP_PLATFORM_EVOLUTION_PLAN.md'
    task_count = $tasks.Count
    tasks = $tasks
}

$document | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $targetPath -Encoding utf8
Write-Output "Generated $targetPath with $($tasks.Count) tasks."
