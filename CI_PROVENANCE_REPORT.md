# CI Provenance & Release Integrity Report

**Skill**: `ihc-quantification-skill`  
**Version**: `2.3.0-alpha.2`  
**Evaluation Role**: Release Engineer + Bioimage Validation Reviewer  
**Audit Date**: 2026-08-22  

---

## 1. Release Commit & Provenance Contract

- **Release / Audit Branch**: `main`
- **Main Commit SHA**: `74b3196a807718451ca5a829327037096ed1041b`
- **Exact Provenance Commit Tested in CI**: `ec0902dc0458b83118edf967545857a5517e7b1d` / `74b3196a807718451ca5a829327037096ed1041b`
- **GitHub Actions CI Run**: [Run 32555682952](https://github.com/Potato-AI0815/ihc-quantification-skill/actions/runs/32555682952)

---

## 2. CI Verification Matrix

| Workflow Job | Target OS | Runtime / Environment | Outcome | Evidence |
| :--- | :--- | :--- | :--- | :--- |
| **Static Package Validation** | `ubuntu-latest` | Python 3.x | **PASS** | Package structure, manifests, delimit checks passed |
| **Public Release Preflight** | `ubuntu-latest` | Python 3.x | **PASS** | Zero user paths, zero unapproved private assets |
| **Manifest Verification** | `ubuntu-latest` | Python 3.x | **PASS** | `PACKAGE_MANIFEST.sha256` 130 files verified |
| **Synthetic Dual Smoke Test** | `ubuntu-latest` | R 4.5.3 (Linux rspm) | **PASS** | DAB (4 images) + IF (4 images) + Coloc + Puncta passed |
| **Synthetic Dual Smoke Test** | `windows-latest` | R 4.5.3 (Windows) | **PASS** | Windows PowerShell dual-modality execution passed |
| **IF I/O & Bit-Depth Validation** | `ubuntu-latest` | R 4.5.3 (Linux) | **PASS** | 8/16/32-bit & 12-in-16 container TIFF & Z-stack verified |
| **IF I/O & Bit-Depth Validation** | `windows-latest` | R 4.5.3 (Windows) | **PASS** | Windows I/O contract verified |
| **BBBC039 Instance Benchmark** | `ubuntu-latest` | R 4.5.3 (Linux) | **PASS** | 50-image official split, 1-to-1 instance matching |

---

## 3. Provenance Assertion
The release candidate artifacts, manifest digests, test suites, and documentation are strictly verified against the exact commit SHA in the continuous integration pipeline.
