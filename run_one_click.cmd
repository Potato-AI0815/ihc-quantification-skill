@echo off
setlocal EnableExtensions
if "%~2"=="" (
  echo Usage: run_one_click.cmd MANIFEST.csv OUTDIR [ROI.csv] [CONFIG.csv] [LOCAL_R_LIB] [CONDITION_ORDER]
  exit /b 2
)
set "ROOT=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%run_one_click.ps1" -Manifest "%~1" -Outdir "%~2" -Roi "%~3" -Config "%~4" -LocalLib "%~5" -ConditionOrder "%~6"
exit /b %errorlevel%
