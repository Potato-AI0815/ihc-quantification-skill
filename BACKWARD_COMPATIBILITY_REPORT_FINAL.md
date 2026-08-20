# DAB-IHC Final Backward Compatibility Audit Report (Clean v2.2.2 Provenance)

**Baseline Provenance**:
- Git Base Commit: `3ae199b8b333fd75d62739e835492a7334f5f016` (Clean checkout of tagged release v2.2.2)
- Baseline Manifest: [`tests/baseline_v222_reference/baseline_manifest.sha256`](tests/baseline_v222_reference/baseline_manifest.sha256)
- Comparison Method: Exact dimensions/column names/character fields plus numeric equality within an absolute tolerance of $1.0\times10^{-6}$ across all table cells

---

## 1. Table-by-Table Verification Matrix

| Table Name | Shape | Max Numeric Difference ($\Delta$) | Categorical Differences | Status |
| :--- | :--- | :--- | :--- | :--- |
| `source_data/ihc_biological_unit_summary.csv` | 12 rows $\times$ 26 cols | $0.000000\text{e}+00$ | 0 | **PASS** |
| `source_data/ihc_design_summary.csv` | 1 row $\times$ 6 cols | $0.000000\text{e}+00$ | 0 | **PASS** |
| `source_data/ihc_image_qc.csv` | 4 rows $\times$ 16 cols | $0.000000\text{e}+00$ | 0 | **PASS** |
| `source_data/ihc_manual_qc_template.csv` | 12 rows $\times$ 6 cols | $0.000000\text{e}+00$ | 0 | **PASS** |
| `source_data/ihc_metric_dictionary.csv` | 12 rows $\times$ 4 cols | $0.000000\text{e}+00$ | 0 | **PASS** |
| `source_data/ihc_paired_effects.csv` | 8 rows $\times$ 12 cols | $0.000000\text{e}+00$ | 0 | **PASS** |
| `source_data/ihc_primary_domain_summary_long.csv` | 48 rows $\times$ 16 cols | $0.000000\text{e}+00$ | 0 | **PASS** |
| `source_data/ihc_qc_color_legend.csv` | 8 rows $\times$ 3 cols | $0.000000\text{e}+00$ | 0 | **PASS** |
| `source_data/ihc_region_summary.csv` | 12 rows $\times$ 34 cols | $0.000000\text{e}+00$ | 0 | **PASS** |
| `source_data/ihc_roi_overlap_audit.csv` | 0 rows $\times$ 8 cols | $0.000000\text{e}+00$ | 0 | **PASS** |
| `source_data/ihc_roi_registry.csv` | 12 rows $\times$ 15 cols | $0.000000\text{e}+00$ | 0 | **PASS** |

---

## 2. Conclusion
The DAB-IHC pipeline in v2.3.0-alpha.1 generates results that are structurally and categorically identical to the original v2.2.2 release, with numeric values compatible within an absolute tolerance of $1.0\times10^{-6}$ to accommodate cross-platform floating-point serialization.
