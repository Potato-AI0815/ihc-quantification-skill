# External real-data validation

This directory contains reproducible download/conversion scripts, fixed
manifests, derived numerical results, compact audit figures where redistribution
is permitted, and validation reports for the `v2.3.0-rc3` decision gate.

Large raw public datasets are downloaded to `.external_validation_cache/`,
which is ignored by Git. No raw BBBC, HPA, or IDR microscopy archive is bundled
in a release.

Evidence is reported in three levels:

1. **Level A — ground-truth benchmark**: BBBC007 and BBBC039.
2. **Level B — biological-response/ordinal concordance**: BBBC013, BBBC016,
   and HPA DAB.
3. **Level C — real-world stress test**: IDR0150 if completed.

Synthetic fixtures remain regression and known-count tests; they are never
presented as external validation.
