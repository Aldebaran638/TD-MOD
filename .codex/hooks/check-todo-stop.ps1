param(
    [string]$TaskPath
)

$ErrorActionPreference = 'Stop'

function Write-Continuation([string]$reason) {
    [ordered]@{
        decision = 'block'
        reason = $reason
    } | ConvertTo-Json -Compress
}

try {
    $repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
    if ([string]::IsNullOrWhiteSpace($TaskPath)) {
        $TaskPath = Join-Path $repoRoot 'TEARDOWN_SHIP_PLATFORM_TODO.json'
    }

    if (-not (Test-Path -LiteralPath $taskPath -PathType Leaf)) {
        Write-Continuation("CM2 Todo gate cannot find $taskPath. Create or restore the task JSON before stopping.")
        exit 0
    }

    $raw = Get-Content -LiteralPath $taskPath -Raw -Encoding utf8
    $document = $raw | ConvertFrom-Json
    $tasks = @($document.tasks)

    if ($tasks.Count -eq 0) {
        Write-Continuation('CM2 Todo gate found no task items. Refuse to stop until the task JSON contains the 80 planned steps.')
        exit 0
    }

    $statusField = if ([string]::IsNullOrWhiteSpace([string]$document.status_field)) { 'status' } else { [string]$document.status_field }
    $completionStatuses = @($document.completion_statuses)
    if ($completionStatuses.Count -eq 0) {
        $completionStatuses = @('finish', 'unable')
    }

    $developerUnable = $document.developer_confirmed_unable
    $developerUnableEnabled = $null -ne $developerUnable -and [bool]$developerUnable.enabled
    $developerUnableField = if ($null -eq $developerUnable -or [string]::IsNullOrWhiteSpace([string]$developerUnable.field)) { 'developer_confirmed' } else { [string]$developerUnable.field }
    $developerUnableIds = if ($null -eq $developerUnable) { @() } else { @($developerUnable.task_ids | ForEach-Object { [string]$_ }) }

    $unfinished = @($tasks | Where-Object {
        $status = $_.$statusField
        $statusIncomplete = $status -notin $completionStatuses
        $unableConfirmed = (($null -ne $_.PSObject.Properties[$developerUnableField]) -and [bool]$_.$developerUnableField) -or ($developerUnableEnabled -and ($developerUnableIds -contains [string]$_.id))
        $unableUnconfirmed = $status -eq 'unable' -and -not $unableConfirmed
        $statusIncomplete -or $unableUnconfirmed
    })
    if ($unfinished.Count -eq 0) {
        exit 0
    }

    $next = $unfinished[0]
    $status = if ([string]::IsNullOrWhiteSpace([string]$next.$statusField)) { '<missing>' } else { [string]$next.$statusField }
    $allowed = $completionStatuses -join ', '
    $reason = "CM2 Todo gate: $($unfinished.Count) task(s) are not in an allowed completion state [$allowed], or an unable task lacks developer confirmation. Continue with $($next.id) $($next.title) (status=$status). Complete its implementation, verification, evidence, rollback record and developer confirmation, then set the task to an allowed completion state."
    Write-Continuation($reason)
    exit 0
}
catch {
    Write-Continuation("CM2 Todo gate failed closed: $($_.Exception.Message). Fix the task JSON or hook before stopping.")
    exit 0
}
