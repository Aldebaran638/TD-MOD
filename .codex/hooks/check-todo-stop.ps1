param(
    [string]$TaskPath
)

$ErrorActionPreference = 'Stop'

function Write-Continuation([string]$reason) {
    [ordered]@{ decision = 'block'; reason = $reason } | ConvertTo-Json -Compress
}

try {
    $repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
    if ([string]::IsNullOrWhiteSpace($TaskPath)) {
        $TaskPath = Join-Path $repoRoot 'TEARDOWN_SHIP_PLATFORM_TODO.json'
    }
    if (-not (Test-Path -LiteralPath $TaskPath -PathType Leaf)) {
        Write-Continuation("CM2 Todo gate cannot find $TaskPath. Restore the executable plan before stopping.")
        exit 0
    }

    $validator = Join-Path $repoRoot '.codex\skills\teardown-autonomous-testing\scripts\validate_todo_plan.py'
    if (-not (Test-Path -LiteralPath $validator -PathType Leaf)) {
        Write-Continuation("CM2 Todo gate cannot find its fail-closed validator at $validator.")
        exit 0
    }
    $validation = (& python $validator $TaskPath --quiet 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) {
        Write-Continuation("CM2 Todo gate rejected the executable plan: $validation")
        exit 0
    }

    $document = Get-Content -LiteralPath $TaskPath -Raw -Encoding utf8 | ConvertFrom-Json
    $tasks = @($document.tasks)
    $completionStatuses = @($document.completion_statuses)
    $verificationCompletion = @($document.verification_completion_statuses)
    $developerUnable = $document.developer_confirmed_unable
    $developerUnableEnabled = $null -ne $developerUnable -and [bool]$developerUnable.enabled
    $developerUnableField = if ($null -eq $developerUnable -or [string]::IsNullOrWhiteSpace([string]$developerUnable.field)) { 'developer_confirmed' } else { [string]$developerUnable.field }
    $developerUnableIds = if ($null -eq $developerUnable) { @() } else { @($developerUnable.task_ids | ForEach-Object { [string]$_ }) }

    $unfinished = @($tasks | Where-Object {
        $implementation = [string]$_.implementation_status
        $verification = [string]$_.verification_status
        $unableConfirmed = (($null -ne $_.PSObject.Properties[$developerUnableField]) -and [bool]$_.$developerUnableField) -or ($developerUnableEnabled -and ($developerUnableIds -contains [string]$_.id))
        $implementationIncomplete = $implementation -notin $completionStatuses
        $unableUnconfirmed = $implementation -eq 'unable' -and -not $unableConfirmed
        # A developer-confirmed unable retains its historical terminal implementation
        # status. All other terminal implementations must also finish verification.
        $verificationIncomplete = $implementation -ne 'unable' -and $verification -notin $verificationCompletion
        $implementationIncomplete -or $unableUnconfirmed -or $verificationIncomplete
    })
    if ($unfinished.Count -eq 0) { exit 0 }

    $next = $unfinished[0]
    $reason = "CM2 executable Todo gate: $($unfinished.Count) task(s) still require implementation or verification. Continue with $($next.id) $($next.title) (implementation=$($next.implementation_status), verification=$($next.verification_status), automation=$($next.verification.automation_level)). Validate its embedded contract, execute the declared profiles/eyes/hands, persist evidence and regression, then update the independent statuses."
    Write-Continuation($reason)
    exit 0
}
catch {
    Write-Continuation("CM2 Todo gate failed closed: $($_.Exception.Message). Fix the executable task plan or hook before stopping.")
    exit 0
}
