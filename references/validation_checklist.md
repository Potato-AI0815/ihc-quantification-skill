# Validation checklist — IHC Quantification Skill v2.2.2

## A. Input integrity

- [ ] Raw images are read-only and unchanged.
- [ ] Every image has a unique `image_id`.
- [ ] Every image has a valid `biological_unit_id`, condition, field ID, and source file.
- [ ] Literal condition labels have not been biologically reinterpreted without confirmation.
- [ ] Pixel size is supplied or pixel fallback is explicitly accepted.
- [ ] Native whole-slide files have been tiled/exported before analysis.

## B. Exclusion and ROI audit

- [ ] Scale bars, labels, glass, folds, debris, and other exclusions have coordinates.
- [ ] Every ROI has an action, source, method, status, and reviewer where required.
- [ ] Tumor/stroma/interface labels have manual or validated external-model provenance.
- [ ] ROI overview on RGB is correct.
- [ ] ROI overview on H-DAB is correct.
- [ ] RGB/H-DAB/selection crops identify the intended location.
- [ ] Overlapping include ROIs are absent or justified.

## C. H-DAB and tissue QC

- [ ] White balance is plausible.
- [ ] H-DAB reconstruction preserves expected blue/brown separation.
- [ ] Tissue mask excludes glass and retains true tissue.
- [ ] DAB channel does not visibly track hematoxylin-only structures excessively.
- [ ] High extracellular background is reviewed.

## D. Segmentation QC

- [ ] Nuclei are not systematically merged.
- [ ] Nuclei are not systematically split.
- [ ] Nuclear detection does not miss a major cell population.
- [ ] Cell propagation does not cross neighboring cells excessively.
- [ ] Cell propagation does not absorb large extracellular regions.
- [ ] Nuclear red, cytoplasmic green, extracellular orange, and global blue overlays match their intended masks.

## E. Threshold QC

- [ ] DAB thresholds were prespecified or calibrated without using group differences.
- [ ] Negative controls or low-expression controls were inspected.
- [ ] Threshold sensitivity was assessed when conclusions depend on positivity.
- [ ] Batch-specific background and intensity shifts were assessed.
- [ ] Marker localization and `cell_scoring_domain` are biologically defensible.

## F. Result semantics

- [ ] Global result is interpreted as pixel-based tissue DAB burden.
- [ ] Nuclear result is interpreted as nuclear cell H-score.
- [ ] Cytoplasmic result is interpreted as cytoplasmic cell H-score.
- [ ] Extracellular result is interpreted as pixel-based DAB burden, not H-score.
- [ ] Extracellular tissue is not called stroma without reviewed provenance.
- [ ] Positive area, mean OD, integrated OD, positive-cell fraction, and H-score are not conflated.

## G. Statistical unit

- [ ] Biological unit—not cells, fields, or ROIs—is used for comparison.
- [ ] Pairing is based on the same biological unit across conditions.
- [ ] Condition order is documented.
- [ ] With fewer than two paired units, inference is marked not evaluable.
- [ ] Any confirmatory model accounts for pairing, batches, repeated fields, and multiplicity where applicable.

## H. Output completeness

- [ ] `ihc_region_summary.csv` exists.
- [ ] `ihc_biological_unit_summary.csv` exists.
- [ ] `ihc_primary_domain_summary_long.csv` exists.
- [ ] `ihc_image_qc.csv` exists.
- [ ] `ihc_manual_qc_template.csv` is completed.
- [ ] Four main figures and their source CSV files exist.
- [ ] H-DAB reconstruction and eight-panel QC overview exist for every analyzed image.
- [ ] Configuration, manifest, ROI file, run summary, and R session information are archived.

## Final decision

- [ ] PASS — approved for the prespecified research analysis.
- [ ] PASS WITH LIMITATIONS — descriptive use only, limitations documented.
- [ ] FAIL — revise parameters/annotations and rerun from raw images.

Reviewer: ____________________  Date: ____________________
