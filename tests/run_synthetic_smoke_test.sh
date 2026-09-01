#!/usr/bin/env bash
# run_synthetic_smoke_test.sh
# Dual-Modality Smoke Test for DAB-IHC and Immunofluorescence (IF).
# Part of the IHC/IF Quantification Skill

set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
DAB_FIXTURE="$ROOT/tests/synthetic_fixture"
DAB_OUT="${1:-$ROOT/tests/synthetic_output}"
IF_FIXTURE="$ROOT/tests/synthetic_if_fixture"
IF_OUT="$ROOT/tests/synthetic_if_output"
LOCAL_LIB="${2:-$ROOT/Rlib}"
[[ -d "$LOCAL_LIB" ]] || LOCAL_LIB=""
[[ -n "$LOCAL_LIB" ]] && export R_LIBS_USER="$LOCAL_LIB"

rm -rf "$DAB_OUT" "$IF_OUT"

echo "=== 1. Running Brightfield DAB-IHC Smoke Test ==="
bash "$ROOT/run_one_click.sh" \
  "$DAB_FIXTURE/manifest.csv" \
  "$DAB_OUT" \
  "$DAB_FIXTURE/roi_annotations.csv" \
  "$ROOT/references/templates/analysis_parameters_template.csv" \
  "$LOCAL_LIB" \
  "control,treatment"

Rscript "$ROOT/tests/verify_synthetic_output.R" "$DAB_OUT"

echo "=== 2. Running Immunofluorescence (IF) Smoke Test ==="
Rscript "$ROOT/scripts/generate_synthetic_if_fixtures.R"
bash "$ROOT/run_one_click.sh" \
  "$IF_FIXTURE/manifest.csv" \
  "$IF_OUT" \
  "" \
  "" \
  "$LOCAL_LIB" \
  "control,treatment"

Rscript "$ROOT/tests/verify_if_synthetic_output.R" "$IF_OUT"

echo "=== 3. Running Advanced IF Modules (Colocalization & Puncta) ==="
Rscript "$ROOT/tests/verify_if_advanced_modules.R"

echo "=== 3a. Running IF Scientific Contract Regressions ==="
Rscript "$ROOT/tests/verify_if_physical_scale_contract.R"
Rscript "$ROOT/tests/verify_if_colocalization_qc_contract.R"

echo "=== 3b. Running IF Runtime Repair Regression Contracts ==="
Rscript "$ROOT/tests/verify_if_runtime_repairs.R"

echo "=== 4. Running Contract & Style Verifications ==="
Rscript "$ROOT/tests/verify_plot_contract.R"
Rscript "$ROOT/tests/verify_path_contract.R"

echo "=== 5. Verifying 100% DAB Backward Compatibility ==="
Rscript "$ROOT/tests/verify_backward_compatibility.R"

printf '\nALL DUAL-MODALITY (DAB + IF) SMOKE TESTS PASSED SUCCESSFULLY!\n'
