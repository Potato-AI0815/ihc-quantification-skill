# RC1 Preflight Baseline

**Repository**: `Potato-AI0815/ihc-quantification-skill`
**Baseline branch**: `main`
**Baseline commit**: `0948b0e4f9574df6a78325be151804a6e700bce3`
**Baseline version**: `2.3.0-alpha.2`
**Baseline date**: 2026-08-22

## Current release state

The repository is publicly released as `v2.3.0-alpha.2` with an
`ALPHA_VALIDATED_WITH_WARNINGS` status. The task text refers to Alpha.1, but
the current main/release state has already advanced to Alpha.2; no historical
tag is moved or rewritten.

## Gates already supported by evidence

- G0 DAB baseline and G9 DAB backward compatibility: PASS.
- G2 preprocessing/saturation, G4 four-domain IF quantification, and G6
  Pearson/Manders colocalization: PASS.
- G5 IF QC/publication figures and G8 public-image validation: PASS_WITH_WARNINGS.
- G10 exact `main@0948b0e` Ubuntu/Windows synthetic CI, including the I/O
  contract: PASS in Actions run 32553865914.
- Puncta aggregate-count recovery: PASS_WITH_WARNINGS with an explicit
  non-object-detector claim.

## Gates requiring RC1 preflight work

- BBBC039 evidence needs a standalone regression fixture and final report that
  explicitly record instance decoding, one-to-one matching, TP/FP/FN, and the
  official validation split.
- OME-TIFF metadata-aware parsing and packed native-12-bit TIFF are not yet
  formally validated; claims must remain experimental unless new fixtures
  provide evidence.
- The final gate matrix and readiness report must be regenerated after the
  preflight changes.

## Frozen constraints

No new analysis algorithms, no Cellpose/StarDist/deep-learning dependency, no
DAB algorithm or output-format changes, and no deletion of warnings or failed
benchmark records.
