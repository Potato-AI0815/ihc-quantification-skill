# RC1 Readiness Report

**Current version**: `v2.3.0-alpha.2`
**Baseline/main commit audited**: `0948b0e4f9574df6a78325be151804a6e700bce3`
**Decision date**: 2026-08-22

## Gate decision

```text
STATUS: v2.3.0-alpha.2
RC1_READY: FALSE
```

The repository remains suitable for public Alpha use. It is not promoted to
`v2.3.0-rc1` because OME-TIFF metadata-aware ingestion and packed native
12-bit TIFF have not received a formal runtime contract with `SizeC`, `SizeZ`,
`SizeT`, and `DimensionOrder` assertions. The current evidence validates
standard TIFF/ImageJ hyperstacks and 12-bit detector-range values stored in a
16-bit container; the documentation correctly labels the remaining formats
experimental.

## Evidence summary

| Gate | Status | Evidence |
|---|---|---|
| DAB backward compatibility | PASS | Clean v2.2.2 baseline comparison; tolerance <= 1e-6 |
| BBBC039 instance benchmark | PASS_WITH_WARNINGS | Official validation split; color-instance decoding; one-to-one IoU matching; one zero-GT image marked non-evaluable |
| IF I/O contract | PASS_WITH_WARNINGS | TIFF/ImageJ, 8/16/32-bit, 12-bit-in-16-bit-container; OME/packed 12-bit experimental |
| Puncta | PASS_WITH_WARNINGS | Synthetic aggregate count recovery; no coordinate-level detector F1 claim |
| Colocalization | PASS | Pearson and Manders M1/M2 regression fixtures |
| Exact main CI | PASS | Ubuntu + Windows + static + I/O contract in Actions run 32553865914 |

## RC1 promotion requirements

1. Add a real OME-TIFF fixture with validated `SizeC`, `SizeZ`, `SizeT`, and
   `DimensionOrder` parsing, plus a documented packed/native-12-bit decision.
2. Rerun the exact main-commit CI after those changes.
3. Reissue the gate matrix and readiness report only if the new evidence meets
   the stated contract. Do not promote based on report wording alone.
