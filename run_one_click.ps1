param(
  [Parameter(Mandatory=$true)][string]$Manifest,
  [Parameter(Mandatory=$true)][string]$Outdir,
  [string]$Roi = "",
  [string]$Config = "",
  [string]$LocalLib = "",
  [string]$ConditionOrder = ""
)

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot
if (-not $Root) { $Root = Split-Path -Parent $MyInvocation.MyCommand.Path }
New-Item -ItemType Directory -Force -Path (Join-Path $Outdir "work") | Out-Null

$validateArgs = @(
  (Join-Path $Root "scripts/validate_ihc_inputs.R"),
  "--manifest=$Manifest",
  "--out=$(Join-Path $Outdir 'work/input_validation.tsv')"
)
if ($Roi) { $validateArgs += "--roi=$Roi" }
if ($LocalLib) { $validateArgs += "--local-lib=$LocalLib" }
& Rscript @validateArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$runArgs = @(
  (Join-Path $Root "scripts/run_quantification.R"),
  "--manifest=$Manifest",
  "--outdir=$Outdir"
)
if ($Roi) { $runArgs += "--roi=$Roi" }
if ($Config) { $runArgs += "--config=$Config" }
if ($LocalLib) { $runArgs += "--local-lib=$LocalLib" }
if ($ConditionOrder) { $runArgs += "--condition-order=$ConditionOrder" }
& Rscript @runArgs
exit $LASTEXITCODE
