#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 MANIFEST.csv OUTDIR [ROI.csv] [CONFIG.csv] [LOCAL_R_LIB] [CONDITION_ORDER]" >&2
  exit 2
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="$SCRIPT_DIR"
MANIFEST="$1"
OUTDIR="$2"
ROI="${3:-}"
CONFIG="${4:-}"
LOCAL_LIB="${5:-}"
CONDITION_ORDER="${6:-}"

R_ARGS=("--manifest=$MANIFEST" "--outdir=$OUTDIR")
[[ -n "$ROI" ]] && R_ARGS+=("--roi=$ROI")
[[ -n "$CONFIG" ]] && R_ARGS+=("--config=$CONFIG")
[[ -n "$LOCAL_LIB" ]] && R_ARGS+=("--local-lib=$LOCAL_LIB")
[[ -n "$CONDITION_ORDER" ]] && R_ARGS+=("--condition-order=$CONDITION_ORDER")

VALIDATE_ARGS=("--manifest=$MANIFEST" "--out=$OUTDIR/work/input_validation.tsv")
[[ -n "$ROI" ]] && VALIDATE_ARGS+=("--roi=$ROI")
[[ -n "$LOCAL_LIB" ]] && VALIDATE_ARGS+=("--local-lib=$LOCAL_LIB")
mkdir -p "$OUTDIR/work"
Rscript "$ROOT/scripts/validate_ihc_inputs.R" "${VALIDATE_ARGS[@]}"
Rscript "$ROOT/scripts/run_quantification.R" "${R_ARGS[@]}"
