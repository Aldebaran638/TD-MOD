# Resolve Package/Core/SDK/build compatibility from the public policy authority.

param(
    [string]$PolicyPath = "",
    [Parameter(Mandatory = $true)][string]$PackageSchema,
    [Parameter(Mandatory = $true)][string]$PackageCoreRange,
    [Parameter(Mandatory = $true)][string]$PackageSdkRange,
    [Parameter(Mandatory = $true)][string]$BuildFormat,
    [string]$CoreApiVersion = "1.2.0",
    [string]$SdkVersion = "1.0.0",
    [string]$PackageId = "",
    [string]$ReportPath = ""
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if ($PolicyPath -eq "") { $PolicyPath = Join-Path $root "docs\compatibility-policy-v1.json" }
$utf8 = New-Object Text.UTF8Encoding($false)

function Canonical-Json([object]$value) { return ($value | ConvertTo-Json -Depth 100 -Compress) }
function Sha256-File([string]$path) { return (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant() }
function Write-TextAtomic([string]$path, [string]$text) {
    if ($path -eq "") { return }
    $full = [IO.Path]::GetFullPath($path); $parent = Split-Path -Parent $full
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $temporary = $full + ".tmp." + [Guid]::NewGuid().ToString("N")
    try { [IO.File]::WriteAllText($temporary, $text, $utf8); Move-Item -LiteralPath $temporary -Destination $full -Force }
    finally { if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue } }
}
function Test-VersionRange([string]$versionText, [string]$rangeText) {
    if ($versionText -notmatch '^\d+\.\d+\.\d+$') { throw ("invalid resolved semantic version: " + $versionText) }
    $version = [version]$versionText; $clauses = @($rangeText -split '\s+' | Where-Object { $_ -ne "" })
    if ($clauses.Count -eq 0) { throw "semantic version range is empty" }
    foreach ($clause in $clauses) {
        if ($clause -notmatch '^(>=|<=|>|<|=)?(\d+\.\d+\.\d+)$') { throw ("unsupported semantic version range clause: " + $clause) }
        $operator = [string]$Matches[1]; if ($operator -eq "") { $operator = "=" }
        $comparison = $version.CompareTo([version]$Matches[2])
        $accepted = switch ($operator) { ">=" {$comparison -ge 0}; "<=" {$comparison -le 0}; ">" {$comparison -gt 0}; "<" {$comparison -lt 0}; "=" {$comparison -eq 0} }
        if (-not $accepted) { return $false }
    }
    return $true
}
function Reject([string]$code, [string]$surface, [string]$required, [string]$resolved, [string]$suggestion) {
    $errorReport = [ordered]@{ schema="cm2.compatibility-resolution/1"; policyHash=if (Test-Path -LiteralPath $PolicyPath) { Sha256-File $PolicyPath } else { "" }; packageId=$PackageId; compatible=$false; code=$code; surface=$surface; required=$required; resolved=$resolved; fieldPath=$surface; suggestion=$suggestion; result="fail" }
    $text = Canonical-Json $errorReport; Write-TextAtomic $ReportPath $text; Write-Output $text; exit 1
}

if (-not (Test-Path -LiteralPath $PolicyPath -PathType Leaf)) { Reject "policy-missing" "policy" "cm2.compatibility-policy/1" "missing" "Restore docs/compatibility-policy-v1.json." }
$policy = Get-Content -Raw -LiteralPath $PolicyPath | ConvertFrom-Json
if ([string]$policy.schema -ne "cm2.compatibility-policy/1") { Reject "policy-schema" "policy" "cm2.compatibility-policy/1" ([string]$policy.schema) "Use the supported compatibility policy schema." }
if ($PackageSchema -notin @($policy.negotiation.supportedPackageSchemas)) { Reject "package-version" "schemaVersion" (@($policy.negotiation.supportedPackageSchemas) -join "|") $PackageSchema "Migrate the package through a published adapter before validation." }
if ($BuildFormat -notin @($policy.negotiation.supportedBuildFormats)) { Reject "build-format" "buildFormatVersion" (@($policy.negotiation.supportedBuildFormats) -join "|") $BuildFormat "Rebuild with a supported package build format." }
if (-not (Test-VersionRange $CoreApiVersion ([string]$policy.negotiation.supportedCoreApiRange))) { Reject "core-policy-version" "coreApi" ([string]$policy.negotiation.supportedCoreApiRange) $CoreApiVersion "Select a Core API version inside the public support window." }
if (-not (Test-VersionRange $CoreApiVersion $PackageCoreRange)) { Reject "core-package-version" "coreApiVersionRange" $PackageCoreRange $CoreApiVersion "Update the package Core range or install a compatible Core." }
if (-not (Test-VersionRange $SdkVersion ([string]$policy.negotiation.supportedSdkRange))) { Reject "sdk-policy-version" "sdk" ([string]$policy.negotiation.supportedSdkRange) $SdkVersion "Select an SDK version inside the public support window." }
if (-not (Test-VersionRange $SdkVersion $PackageSdkRange)) { Reject "sdk-package-version" "sdkVersionRange" $PackageSdkRange $SdkVersion "Update the package SDK range or install a compatible SDK." }

$report = [ordered]@{
    schema="cm2.compatibility-resolution/1"; policyVersion=[string]$policy.policyVersion; policyHash=Sha256-File $PolicyPath; packageId=$PackageId; compatible=$true
    order=@($policy.negotiation.order)
    surfaces=[ordered]@{
        package=[ordered]@{ required=$PackageSchema; resolved=[string]$policy.current.packageSchema; compatible=$true }
        coreApi=[ordered]@{ policyRange=[string]$policy.negotiation.supportedCoreApiRange; packageRange=$PackageCoreRange; resolved=$CoreApiVersion; compatible=$true }
        schema=[ordered]@{ required="source-envelope major 1 after explicit migration"; resolved="major-1"; compatible=$true }
        buildFormat=[ordered]@{ required=$BuildFormat; resolved=[string]$policy.current.buildFormat; compatible=$true }
        sdk=[ordered]@{ policyRange=[string]$policy.negotiation.supportedSdkRange; packageRange=$PackageSdkRange; resolved=$SdkVersion; compatible=$true }
    }
    diagnosticLevels=$policy.diagnosticLevels; result="pass"
}
$text = Canonical-Json $report; Write-TextAtomic $ReportPath $text; Write-Output $text; exit 0
