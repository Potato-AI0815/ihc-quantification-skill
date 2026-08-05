param(
  [string]$Outdir = "",
  [string]$LocalLib = ""
)
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Fixture = Join-Path $Root "tests/synthetic_fixture"
if (-not $Outdir) { $Outdir = Join-Path $Root "tests/synthetic_output" }
if (-not $LocalLib) {
  $CandidateLib = Join-Path $Root "Rlib"
  if (Test-Path $CandidateLib) { $LocalLib = $CandidateLib }
}
if (Test-Path $Outdir) { Remove-Item -Recurse -Force $Outdir }
$run = @{
  Manifest = Join-Path $Fixture "manifest.csv"
  Outdir = $Outdir
  Roi = Join-Path $Fixture "roi_annotations.csv"
  Config = Join-Path $Root "references/templates/analysis_parameters_template.csv"
  ConditionOrder = "control,treatment"
}
if ($LocalLib) { $run.LocalLib = $LocalLib }
& (Join-Path $Root "run_one_click.ps1") @run
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$verifyArgs = @((Join-Path $Root "tests/verify_synthetic_output.R"), $Outdir)
if ($LocalLib) { $env:R_LIBS_USER = $LocalLib }
& Rscript @verifyArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& Rscript (Join-Path $Root "tests/verify_plot_contract.R")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& Rscript (Join-Path $Root "tests/verify_path_contract.R")
exit $LASTEXITCODE
