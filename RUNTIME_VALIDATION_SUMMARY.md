# Runtime Validation Summary

## Scope

This file records where the quantitative core has actually been executed and
what each run does and does not demonstrate. `v2.3.1` is the canonical stable
release; `v2.3.2` is a pre-release scientific-contract hotfix candidate on
`main`.

## v2.3.1 stable release provenance

- Exact-SHA main CI: run [33504060489](https://github.com/Potato-AI0815/ihc-quantification-skill/actions/runs/33504060489) — `success`
- Exact-tag CI: run [33505086731](https://github.com/Potato-AI0815/ihc-quantification-skill/actions/runs/33505086731) — `success`
- tag-version-contract: `2.3.1 == 2.3.1`
- GitHub Release: `prerelease = false`.

## Immutable external-validation evidence

External validation evidence originates from `v2.3.0-rc3`
(`b025b3805800dbf1f6d3850e881a40c8e6ebac71`):
- BBBC013 `PASS`
- BBBC007, BBBC016, and HPA `PASS_WITH_WARNINGS`
No external dataset is re-run for the v2.3.2 patch because DAB analytics,
IF segmentation, puncta detection, and external benchmark analytical inputs
are unchanged; the frozen-core guard and the full regression suite are the
preservation evidence.

## v2.3.2 local runtime validation

- Physical-scale contract regression: **PASS** (calibrated, missing, `0`,
  negative, `Inf`, `NaN`)
- Colocalization production QC regression: **PASS** (aligned, low, shifted,
  low dynamic range, low pixel count)
- Synthetic DAB + IF smoke test: **PASS**
- HPA checkpoint/resume regression: **PASS**
- DAB 11-table v2.2.2 compatibility: **PASS**; observed max numeric deviation
  `0`; acceptance tolerance `<= 1e-6`
- IF I/O contract and BBBC039 regression: **PASS**
- Cross-platform CI: pending exact-SHA main run; no v2.3.2 tag exists.

## Confirmed safeguards (unchanged)

- unknown pixel scale must not produce finite physical-unit metrics;
- registration suspect must not produce interpretable colocalization metrics;
- low dynamic range must not produce interpretable colocalization metrics;
- empty target must not become 100% positive;
- cells/pixels are not inferential biological n;
- fluorescence metrics are not labelled OD/IOD;
- DAB v2.2.2 compatibility remains intact;
- literal condition labels are not biologically reinterpreted;
- low-n paired inference is blocked;
- manual review remains required.

Runtime success validates software execution, not universal validity across
markers, tissues, scanners, magnifications, or staining batches.
