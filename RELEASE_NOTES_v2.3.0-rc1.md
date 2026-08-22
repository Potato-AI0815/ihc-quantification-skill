# IHC & Immunofluorescence Quantification Skill v2.3.0-rc1

## Overview

This release introduces a validated dual-modality workflow for:

- DAB immunohistochemistry quantification
- Multi-channel immunofluorescence quantification

with emphasis on:

- QC-first analysis
- reproducibility
- biological interpretation boundaries
- publication-oriented outputs


## Validated capabilities


### DAB-IHC

- global quantification
- ROI-aware measurement
- intensity and area-based metrics
- backward compatibility with v2.2.2 baseline


### Immunofluorescence

Validated modules:

- TIFF/ImageJ-compatible input workflow
- preprocessing and saturation QC
- classical cell segmentation
- four-compartment quantification

including:

- global
- nucleus
- cytoplasm
- extracellular


Advanced modules:

- Pearson correlation
- Manders M1/M2
- puncta counting workflow


## Benchmark validation


### BBBC039 nucleus segmentation benchmark

Official 50-image validation partition:

Results:

Dice:
0.8953

IoU:
0.8390

Object F1:
0.8919

Count error:
13.0%


Important:

This benchmark validates the implemented workflow on the specified validation partition.
It does not represent universal performance across all microscopy datasets.


## Scientific limitations


Clearly state:

- Colocalization does not establish molecular binding.
- Puncta module validated for synthetic aggregate counting workflow.
- OME-TIFF metadata-aware workflows remain under validation.


## Reproducibility


Validated:

- Python static validation
- R contract tests
- backward compatibility tests
- BBBC039 benchmark
- cross-platform CI


Commit:

27fc23a
