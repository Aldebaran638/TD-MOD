# Validate the machine-readable Content/Global source-of-truth contract.

param(
    [string]$Path = "."
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath $Path).Path
$manifestPath = Join-Path $root "docs\source-of-truth.json"
$issues = New-Object System.Collections.Generic.List[string]

if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    $issues.Add("missing source-of-truth manifest: docs/source-of-truth.json")
}
else {
    try {
        $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
    }
    catch {
        $issues.Add("invalid source-of-truth JSON: $($_.Exception.Message)")
        $manifest = $null
    }

    if ($null -ne $manifest) {
        if ([string]$manifest.schema_version -ne "cm2.source-of-truth/1") {
            $issues.Add("unsupported source-of-truth schema_version")
        }
        if ([string]$manifest.product -ne "Content Mod 2") {
            $issues.Add("product must be Content Mod 2")
        }
        if ([string]$manifest.source_root -ne "Content Mod 2") {
            $issues.Add("source_root must be Content Mod 2")
        }
        if ([string]$manifest.generated_target -ne "Global Mod") {
            $issues.Add("generated_target must be Global Mod")
        }
        if ([string]$manifest.target_policy.manual_edits -ne "forbidden") {
            $issues.Add("target_policy.manual_edits must be forbidden")
        }

        $sourceRoot = Join-Path $root ([string]$manifest.source_root)
        $targetRoot = Join-Path $root ([string]$manifest.generated_target)
        if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) {
            $issues.Add("source root does not exist: $($manifest.source_root)")
        }
        if (-not (Test-Path -LiteralPath $targetRoot -PathType Container)) {
            $issues.Add("generated target does not exist: $($manifest.generated_target)")
        }

        foreach ($relativeFile in @($manifest.required_source_files)) {
            if ([string]::IsNullOrWhiteSpace([string]$relativeFile)) {
                $issues.Add("required_source_files contains an empty path")
                continue
            }
            $requiredPath = Join-Path $sourceRoot ([string]$relativeFile)
            if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
                $issues.Add("required source file does not exist: $($manifest.source_root)/$relativeFile")
            }
        }
    }
}

if ($issues.Count -gt 0) {
    Write-Error ("Source-of-truth check failed:`n - " + ($issues -join "`n - "))
    exit 1
}

Write-Host "Source-of-truth contract passed: Content Mod 2 -> Global Mod." -ForegroundColor Green
exit 0
