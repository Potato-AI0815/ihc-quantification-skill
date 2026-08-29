# Runtime compatibility — dual-modality workflow (current `main`)

## Compatibility summary

The repository ships two modalities behind one router:

- **Brightfield DAB-IHC** — the maintained DAB workflow, provenance-tracked to
  the v2.2.2 release line: backward compatibility against a clean v2.2.2
  checkout is part of every regression run (`tests/verify_backward_compatibility.R`,
  observed delta 0, tolerance 1e-6). v2.2.2 is used **only** as the DAB baseline
  provenance reference, not as the current version label.
- **Multi-channel immunofluorescence (IF)** — TIFF/ImageJ multi-channel and
  hyperstack inputs, 8/16/32-bit plus 12-bit-in-16-bit-container values,
  Z-projection contracts, 4-compartment quantification, colocalization, and
  puncta modules. OME-TIFF metadata-aware ingestion and packed native-12-bit
  encodings remain experimental and are not advertised as validated.

## Bundled image assets

Bundled images are limited to (a) deterministic synthetic fixtures generated
in-repo and (b) small derived demo/QC figures from explicitly licensed public
datasets with per-asset provenance (`docs/assets/public_validation/provenance.csv`,
`THIRD_PARTY_ASSETS.md`). Raw external datasets (BBBC, HPA, CIL originals) are
not bundled and are not redistributed.

## Portable path contract

Command-line entry points now:

- derive their repository location from the executing script rather than the current working directory;
- accept relative paths, Unix/macOS absolute paths, Windows drive paths, UNC paths, and tilde-expanded paths;
- preserve spaces in repository, input, output, and local-library paths;
- use `file.path`/`Join-Path` and quoted Bash arrays rather than hand-built separators;
- default the local R library to `<repository>/Rlib` rather than the caller's working directory.

The bundled `tests/verify_path_contract.R` checks path classification and a real relative file path inside a directory containing spaces. GitHub Actions runs the full synthetic workflow on Ubuntu and Windows.

## Dependency reproducibility

`renv.lock` records the direct dependency baseline. Each real study must also archive `work/R_sessionInfo.txt`, `config/analysis_parameters_used.csv`, its manifest, and reviewed ROI annotations.
