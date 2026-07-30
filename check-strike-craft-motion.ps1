# Static contract checker for the isolated strike-craft motion controller.

param([string]$Path = ".\Content Mod 2")

$ErrorActionPreference = "Stop"
$issues = 0

function Add-Issue {
    param([string]$Message)
    Write-Host "[STRIKE CRAFT MOTION ERROR] $Message" -ForegroundColor Red
    $script:issues++
}

function Require-Pattern {
    param([string]$Pattern, [string]$Message)
    if ($script:source -notmatch $Pattern) {
        Add-Issue $Message
    }
}

if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    Write-Host "[ERROR] Mod directory does not exist: $Path" -ForegroundColor Red
    exit 1
}

$modRoot = (Resolve-Path -LiteralPath $Path).Path
$motionPath = Join-Path $modRoot "script\weapon\server\slots\h\gamma_strike_craft\flight_controller.lua"
if (-not (Test-Path -LiteralPath $motionPath -PathType Leaf)) {
    Add-Issue "missing production motion controller: script\weapon\server\slots\h\gamma_strike_craft\flight_controller.lua"
    Write-Host "FAILED - strike-craft motion contract has $issues issue(s)." -ForegroundColor Red
    exit 1
}

$source = [IO.File]::ReadAllText($motionPath)
$controlPath = Join-Path $modRoot "script\weapon\server\slots\h\gamma_strike_craft\control.lua"
$dataPath = Join-Path $modRoot "script\data\weapons\h\gamma_strike_craft.lua"
$prefabPath = Join-Path $modRoot "prefabs\gammaStrikeCraft.xml"
$clientFxPath = Join-Path $modRoot "script\weapon\client\slots\h\gamma_strike_craft\effects\craft_fx.lua"
foreach ($requiredPath in @($controlPath, $dataPath, $prefabPath, $clientFxPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        Add-Issue "missing production integration file: $requiredPath"
    }
}
$controlSource = if (Test-Path -LiteralPath $controlPath) { [IO.File]::ReadAllText($controlPath) } else { "" }
$dataSource = if (Test-Path -LiteralPath $dataPath) { [IO.File]::ReadAllText($dataPath) } else { "" }
$prefabSource = if (Test-Path -LiteralPath $prefabPath) { [IO.File]::ReadAllText($prefabPath) } else { "" }
$clientFxSource = if (Test-Path -LiteralPath $clientFxPath) { [IO.File]::ReadAllText($clientFxPath) } else { "" }

if ($controlSource -notmatch 'server\.hSlotFlightCreate\s*\(' -or
    $controlSource -notmatch 'server\.hSlotFlightUpdate\s*\(') {
    Add-Issue "H-slot runtime does not use the production flight controller"
}
if ($controlSource -notmatch 'QueryRejectBody\(craft\.bodyId\)') {
    Add-Issue "strike-craft laser must reject its own body"
}
if ($controlSource -notmatch '_hSlotResolveRecoveryPoint' -or
    $controlSource -notmatch '"return_recovered_finish"') {
    Add-Issue "craft recovery must return to its launcher point"
}
if ($dataSource -notmatch 'maxRange\s*=\s*280\.0' -or
    $dataSource -notmatch 'cruiseSpeed\s*=\s*130\.0' -or
    $dataSource -notmatch 'maxAngularImpulse\s*=\s*5000\.0') {
    Add-Issue "production craft flight and beam tuning is incomplete"
}
if ($prefabSource -notmatch 'gammaStrikeCraftTest\.vox' -or
    $prefabSource -notmatch 'strikeCraftMuzzle' -or
    $prefabSource -notmatch 'strikeCraftEngineLeft' -or
    $prefabSource -notmatch 'strikeCraftEngineRight') {
    Add-Issue "production prefab must use the tested model and explicit attachment nodes"
}
if ($clientFxSource -notmatch 'client\.registerHSlotCraftFx' -or
    $clientFxSource -notmatch 'client\.hSlotCraftFxRender') {
    Add-Issue "production craft tail-flame binding is incomplete"
}

foreach ($forbidden in @(
    @{ Pattern = '\bExplosion\s*\('; Message = "motion controller must not create explosions" },
    @{ Pattern = '\bDelete\s*\('; Message = "motion controller must not delete lifecycle entities" },
    @{ Pattern = '\bSetBodyTransform\s*\('; Message = "normal flight must not teleport with SetBodyTransform" },
    @{ Pattern = '\bregistryShipSetHP\s*\('; Message = "motion controller must not mutate ship HP" },
    @{ Pattern = '\bweaponDamageApplyToShip\s*\('; Message = "motion controller must not apply weapon damage" }
)) {
    if ($source -match $forbidden.Pattern) {
        Add-Issue $forbidden.Message
    }
}

Require-Pattern 'function\s+server\.hSlotFlightCreate\s*\(' "production craft creation contract is required"
Require-Pattern 'function\s+server\.hSlotFlightUpdate\s*\(' "production physics update contract is required"
Require-Pattern '\bSetBodyVelocity\s*\(' "motion controller must use velocity control"
Require-Pattern '\bConstrainOrientation\s*\(' "orientation must use ConstrainOrientation"
Require-Pattern 'return\s+"recovered"' "DOCK must expose the recovery result"
Require-Pattern 'return\s+"timeout"' "RETURN must have a finite timeout"

$states = @(
    "LAUNCH", "INTERCEPT", "ATTACK_RUN", "BREAK_AWAY", "REPOSITION",
    "RETURN", "DOCK", "EMERGENCY", "DISABLED"
)
foreach ($state in $states) {
    if ($source -notmatch ('"' + [regex]::Escape($state) + '"')) {
        Add-Issue "missing state: $state"
    }
}

$candidateMatch = [regex]::Match(
    $source,
    '(?s)local\s+FlightCandidates\s*=\s*\{(?<body>.*?)\r?\n\}'
)
$candidateCount = 0
if (-not $candidateMatch.Success) {
    Add-Issue "missing preallocated CandidateOffsets table"
}
else {
    $candidateCount = [regex]::Matches(
        $candidateMatch.Groups["body"].Value,
        '\{\s*yaw\s*='
    ).Count
    if ($candidateCount -lt 1 -or $candidateCount -gt 8) {
        Add-Issue "candidate planner must contain between 1 and 8 directions; found $candidateCount"
    }
}

$queryFunction = $source.IndexOf("local function _flightQuery", [StringComparison]::Ordinal)
$queryRequire = $source.IndexOf("QueryRequire(", $queryFunction, [StringComparison]::Ordinal)
$queryReject = $source.IndexOf("QueryRejectBody(craft.bodyId)", $queryFunction, [StringComparison]::Ordinal)
$ownerReject = $source.IndexOf("QueryRejectBody(ownerBody)", $queryFunction, [StringComparison]::Ordinal)
$queryRaycast = $source.IndexOf("QueryRaycast(", $queryFunction, [StringComparison]::Ordinal)
if ($queryFunction -lt 0 -or $queryRequire -lt $queryFunction -or
    $queryReject -lt $queryRequire -or $ownerReject -lt $queryReject -or
    $queryRaycast -lt $ownerReject) {
    Add-Issue "all movement raycasts must pass through a filter-resetting query wrapper"
}
if ([regex]::Matches($source, '\bQueryRaycast\s*\(').Count -ne 1) {
    Add-Issue "movement raycasts must be centralized in _queryPath"
}

$updateIndex = $source.IndexOf("function server.hSlotFlightUpdate(", [StringComparison]::Ordinal)
if ($updateIndex -ge 0) {
    $updateSource = $source.Substring($updateIndex)
    if ($updateSource -match '\bGetTime\s*\(') {
        Add-Issue "hot update must use numeric countdowns instead of global time reads"
    }
    if ($updateSource -match '\bFindBodies\s*\(' -or $updateSource -match '\bFindVehicles\s*\(') {
        Add-Issue "hot update must not enumerate the whole scene each physics step"
    }
}

$emergencyMatch = [regex]::Match($source, '"emergencyDuration",\s*([0-9.]+)')
if ($emergencyMatch.Success) {
    $duration = [double]$emergencyMatch.Groups[1].Value
    if ($duration -lt 0.5 -or $duration -gt 1.2) {
        Add-Issue "emergencyDuration must stay within 0.5-1.2 seconds; found $duration"
    }
}

$nearMatch = [regex]::Match($source, 'nearSweepRemain\s*=\s*1\.0\s*/\s*([0-9.]+)')
$farMatch = [regex]::Match($source, 'farProbeRemain\s*=\s*1\.0\s*/\s*([0-9.]+)')
$plannerMatch = [regex]::Match($source, 'craft\.plannerRemain\s*=\s*([0-9.]+)')
if ($nearMatch.Success -and $farMatch.Success -and $plannerMatch.Success -and $candidateCount -gt 0) {
    $nearHz = [double]$nearMatch.Groups[1].Value
    $farHz = [double]$farMatch.Groups[1].Value
    $plannerHz = 1.0 / [double]$plannerMatch.Groups[1].Value
    $openBudget = $nearHz + $farHz
    $complexBudget = $openBudget + $candidateCount * $plannerHz
    if ($openBudget -gt 45.0) {
        Add-Issue "open-space query budget exceeds 45/s: $openBudget"
    }
    if ($complexBudget -gt 80.0) {
        Add-Issue "complex-avoidance query budget exceeds 80/s: $complexBudget"
    }
}
else {
    Add-Issue "unable to calculate query budget from interval configuration"
}

if ($issues -gt 0) {
    Write-Host "FAILED - strike-craft motion contract has $issues issue(s)." -ForegroundColor Red
    exit 1
}

Write-Host "OK - strike-craft motion contract is valid." -ForegroundColor Green
Write-Host "States: 9; candidates: $candidateCount; open budget: $openBudget/s; complex budget: $complexBudget/s."
exit 0
