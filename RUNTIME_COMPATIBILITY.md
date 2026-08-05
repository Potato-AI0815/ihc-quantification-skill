# Runtime compatibility — v2.2.2

## Baseline evidence

The v2.2 quantitative core was exercised under Windows 11, R 4.5.3, EBImage 4.52.0, and data.table 1.18.2.1. Private images and identifiers are not distributed. The bundled synthetic fixture is the only public image dataset.

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
