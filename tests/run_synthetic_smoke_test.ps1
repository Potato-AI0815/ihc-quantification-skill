param(
  [string]$Outdir = "",
  [string]$LocalLib = ""
)
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$DabFixture = Join-Path $Root "tests/synthetic_fixture"
$IfFixture = Join-Path $Root "tests/synthetic_if_fixture"

if (-not $Outdir) { $Outdir = Join-Path $Root "tests/synthetic_output" }
$IfOutdir = Join-Path $Root "tests/synthetic_if_output"

if (-not $LocalLib) {
  $CandidateLib = Join-Path $Root "Rlib"
  if (Test-Path $CandidateLib) { $LocalLib = $CandidateLib }
}
if ($LocalLib) { $env:R_LIBS_USER = $LocalLib }

if (Test-Path $Outdir) { Remove-Item -Recurse -Force $Outdir }
if (Test-Path $IfOutdir) { Remove-Item -Recurse -Force $IfOutdir }

Write-Host "=== 1. Running Brightfield DAB-IHC Smoke Test on Windows ==="
$dabRun = @{
  Manifest = Join-Path $DabFixture "manifest.csv"
  Outdir = $Outdir
  Roi = Join-Path $DabFixture "roi_annotations.csv"
  Config = Join-Path $Root "references/templates/analysis_parameters_template.csv"
  ConditionOrder = "control,treatment"
}
if ($LocalLib) { $dabRun.LocalLib = $LocalLib }
& (Join-Path $Root "run_one_click.ps1") @dabRun
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$verifyArgs = @((Join-Path $Root "tests/verify_synthetic_output.R"), $Outdir)
& Rscript @verifyArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "=== 2. Running Immunofluorescence (IF) Smoke Test on Windows ==="
& Rscript (Join-Path $Root "scripts/generate_synthetic_if_fixtures.R")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$ifRun = @{
  Manifest = Join-Path $IfFixture "manifest.csv"
  Outdir = $IfOutdir
  ConditionOrder = "control,treatment"
}
if ($LocalLib) { $ifRun.LocalLib = $LocalLib }
& (Join-Path $Root "run_one_click.ps1") @ifRun
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$verifyIfArgs = @((Join-Path $Root "tests/verify_if_synthetic_output.R"), $IfOutdir)
& Rscript @verifyIfArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "=== 3. Running Advanced IF Modules (Coloc & Puncta) on Windows ==="
& Rscript (Join-Path $Root "tests/verify_if_advanced_modules.R")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "=== 3b. Running IF Runtime Repair Regression Contracts on Windows ==="
& Rscript (Join-Path $Root "tests/verify_if_runtime_repairs.R")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "=== 4. Running Contract & Style Verifications on Windows ==="
& Rscript (Join-Path $Root "tests/verify_plot_contract.R")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& Rscript (Join-Path $Root "tests/verify_path_contract.R")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "=== 5. Verifying 100% DAB Backward Compatibility on Windows ==="
& Rscript (Join-Path $Root "tests/verify_backward_compatibility.R")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "ALL DUAL-MODALITY SMOKE TESTS PASSED ON WINDOWS!"
exit 0
