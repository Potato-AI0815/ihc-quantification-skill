#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
FIXTURE="$ROOT/tests/synthetic_fixture"
OUT="${1:-$ROOT/tests/synthetic_output}"
LOCAL_LIB="${2:-$ROOT/Rlib}"
[[ -d "$LOCAL_LIB" ]] || LOCAL_LIB=""
rm -rf "$OUT"
"$ROOT/run_one_click.sh" \
  "$FIXTURE/manifest.csv" \
  "$OUT" \
  "$FIXTURE/roi_annotations.csv" \
  "$ROOT/references/templates/analysis_parameters_template.csv" \
  "$LOCAL_LIB" \
  "control,treatment"
[[ -n "$LOCAL_LIB" ]] && export R_LIBS_USER="$LOCAL_LIB"
Rscript "$ROOT/tests/verify_synthetic_output.R" "$OUT"
Rscript "$ROOT/tests/verify_plot_contract.R"
Rscript "$ROOT/tests/verify_path_contract.R"
printf 'Synthetic smoke test complete: %s\n' "$OUT"
