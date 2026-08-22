#!/usr/bin/env python3
"""Static package checks that do not require R or image-analysis dependencies."""
from __future__ import annotations

import csv
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

REQUIRED = [
    "SKILL.md",
    "README.md",
    "README_EN.md",
    "CHANGELOG.md",
    "LICENSE",
    "CITATION.cff",
    "DESCRIPTION",
    "CONTRIBUTING.md",
    "SECURITY.md",
    "GITHUB_RELEASE_CHECKLIST.md",
    "UPLOAD_TO_GITHUB.md",
    ".gitignore",
    ".gitattributes",
    ".private_tokens.example",
    "renv.lock",
    ".github/workflows/ci.yml",
    "RUNTIME_COMPATIBILITY.md",
    "RUNTIME_VALIDATION_SUMMARY.md",
    "MIGRATION_v2.1_to_v2.2.md",
    "VERSION",
    "RELEASE_STATUS.md",
    "PUBLIC_RELEASE_PREFLIGHT.txt",
    "PUBLIC_RELEASE_AUDIT.md",
    "agents/openai.yaml",
    "scripts/path_utils.R",
    "scripts/ihc_helpers.R",
    "scripts/ihc_plot_helpers.R",
    "scripts/run_ihc_quantification.R",
    "scripts/plot_ihc_comparison.R",
    "scripts/annotate_ihc_rois.R",
    "scripts/validate_ihc_inputs.R",
    "scripts/run_quantification.R",
    "scripts/run_if_quantification.R",
    "scripts/if_io_helpers.R",
    "scripts/if_preprocessing.R",
    "scripts/if_segmentation.R",
    "scripts/if_quantification_helpers.R",
    "scripts/if_colocalization.R",
    "scripts/if_puncta.R",
    "scripts/if_qc_helpers.R",
    "scripts/if_plot_helpers.R",
    "scripts/preflight_public_release.py",
    "scripts/verify_package_manifest.py",
    "scripts/bootstrap_renv.R",
    "references/templates/manifest_template.csv",
    "references/templates/roi_annotations_template.csv",
    "references/templates/analysis_parameters_template.csv",
    "references/templates/if_manifest_template.csv",
    "references/templates/if_analysis_parameters_template.csv",
    "references/templates/if_manual_qc_template.csv",
    "references/templates/if_roi_annotations_template.csv",
    "tests/synthetic_fixture/manifest.csv",
    "tests/synthetic_fixture/roi_annotations.csv",
    "tests/synthetic_if_fixture/manifest.csv",
    "tests/verify_synthetic_output.R",
    "tests/verify_if_synthetic_output.R",
    "tests/verify_if_advanced_modules.R",
    "tests/verify_if_runtime_repairs.R",
    "tests/verify_backward_compatibility.R",
    "tests/verify_plot_contract.R",
    "tests/verify_path_contract.R",
    "docs/immunofluorescence_methodology.md",
    "docs/if_input_guide.md",
    "docs/if_channel_mapping.md",
    "docs/if_segmentation_guide.md",
    "docs/if_colocalization_guide.md",
    "docs/if_puncta_guide.md",
    "docs/if_qc_guide.md",
    "docs/if_validation_datasets.md",
    "VALIDATION_CLOSEOUT_REPORT.md",
    "IF_IO_VALIDATION_REPORT.md",
    "SEGMENTATION_BENCHMARK_REPORT.md",
    "COLOCALIZATION_VALIDATION_REPORT.md",
    "PUNCTA_VALIDATION_REPORT.md",
    "BACKWARD_COMPATIBILITY_REPORT_FINAL.md",
    "GATE_MATRIX_FINAL.csv",
    "GATE_MATRIX_RC1_FINAL.csv",
    "segmentation_benchmark.csv",
    "scripts/download_and_verify_public_images.R",
    "scripts/verify_if_io_bitdepth_contract.R",
    "scripts/benchmark_bbbc039_segmentation.R",
    "RC1_BASELINE_REPORT.md",
    "CI_PROVENANCE_REPORT.md",
    "FINAL_RELEASE_DECISION.md",
    "RELEASE_NOTES_v2.3.0-rc1.md",
]

CSV_SCHEMAS = {
    "references/templates/manifest_template.csv": {
        "image_id", "biological_unit_id", "condition", "field_id", "source_file"
    },
    "references/templates/roi_annotations_template.csv": {
        "image_id", "roi_id", "compartment", "action", "selection_source",
        "selection_method", "reviewer", "annotation_status", "vertex_order", "x", "y"
    },
    "references/templates/analysis_parameters_template.csv": {"parameter", "value"},
    "references/templates/if_manifest_template.csv": {
        "image_id", "biological_unit_id", "condition", "modality", "marker",
        "channel_name", "channel_index", "channel_role", "pixel_size_um", "file_path"
    },
    "references/templates/if_analysis_parameters_template.csv": {"parameter", "value"},
    "references/templates/if_manual_qc_template.csv": {
        "image_id", "HUMAN_APPROVED", "reviewer", "review_date",
        "channel_mapping_approved", "segmentation_approved", "threshold_approved"
    },
}

CORE_R = [
    "scripts/path_utils.R",
    "scripts/ihc_helpers.R",
    "scripts/ihc_plot_helpers.R",
    "scripts/run_ihc_quantification.R",
    "scripts/plot_ihc_comparison.R",
    "scripts/annotate_ihc_rois.R",
    "scripts/validate_ihc_inputs.R",
    "scripts/run_quantification.R",
    "scripts/run_if_quantification.R",
    "scripts/if_io_helpers.R",
    "scripts/if_preprocessing.R",
    "scripts/if_segmentation.R",
    "scripts/if_quantification_helpers.R",
    "scripts/if_colocalization.R",
    "scripts/if_puncta.R",
    "scripts/if_qc_helpers.R",
    "scripts/if_plot_helpers.R",
    "tests/verify_synthetic_output.R",
    "tests/verify_if_synthetic_output.R",
    "tests/verify_if_advanced_modules.R",
    "tests/verify_if_runtime_repairs.R",
    "tests/verify_backward_compatibility.R",
    "tests/verify_plot_contract.R",
    "tests/verify_path_contract.R",
]


def delimiter_errors(path: Path) -> list[str]:
    text = path.read_text(encoding="utf-8")
    stack: list[tuple[str, int, int]] = []
    pairs = {")": "(", "]": "[", "}": "{"}
    quote: str | None = None
    escaped = False
    in_comment = False
    line = 1
    column = 0
    errors: list[str] = []
    for char in text:
        column += 1
        if char == "\n":
            line += 1
            column = 0
            in_comment = False
            continue
        if in_comment:
            continue
        if quote is not None:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = None
            continue
        if char == "#":
            in_comment = True
            continue
        if char in {"'", '"'}:
            quote = char
            continue
        if char in "([{":
            stack.append((char, line, column))
        elif char in ")]}":
            if not stack or stack[-1][0] != pairs[char]:
                errors.append(f"unmatched {char} at {line}:{column}")
            else:
                stack.pop()
    if quote is not None:
        errors.append("unclosed string literal")
    errors.extend(f"unclosed {char} at {line}:{column}" for char, line, column in stack)
    return errors


def read_header(path: Path) -> set[str]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        return set(next(csv.reader(handle)))


def read_parameter_names(path: Path) -> set[str]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        rows = csv.DictReader(handle)
        return {row["parameter"] for row in rows}


def extract_simple_version(path: Path, pattern: str) -> str | None:
    if not path.is_file():
        return None
    match = re.search(pattern, path.read_text(encoding="utf-8"), flags=re.MULTILINE)
    return match.group(1).strip() if match else None


def main() -> int:
    findings: list[tuple[str, str, str]] = []

    for rel in REQUIRED:
        if not (ROOT / rel).is_file():
            findings.append(("ERROR", rel, "required file is missing"))

    for rel in CORE_R:
        path = ROOT / rel
        if path.is_file():
            for error in delimiter_errors(path):
                findings.append(("ERROR", rel, error))

    for rel, required_columns in CSV_SCHEMAS.items():
        path = ROOT / rel
        if path.is_file():
            missing = required_columns - read_header(path)
            if missing:
                findings.append(("ERROR", rel, "missing CSV columns: " + ", ".join(sorted(missing))))

    config_path = ROOT / "references/templates/analysis_parameters_template.csv"
    if config_path.is_file():
        required_parameters = {
            "generate_qc_overview", "generate_roi_triplets", "generate_main_plots",
            "write_stain_channels", "plot_summary_stat", "plot_errorbar",
            "plot_axis_mode", "generate_zoomed_plots", "plot_subtitle_width", "plot_caption_width",
            "qc_include_dab_positive_mask", "qc_od_display_upper_quantile",
            "qc_overlay_fill_alpha", "qc_overlay_boundary_alpha",
        }
        missing_parameters = required_parameters - read_parameter_names(config_path)
        if missing_parameters:
            findings.append(("ERROR", str(config_path.relative_to(ROOT)), "missing v2.2 parameters: " + ", ".join(sorted(missing_parameters))))

    core_text = "\n".join((ROOT / rel).read_text(encoding="utf-8") for rel in CORE_R if (ROOT / rel).is_file())
    forbidden = {
        "plasma_like": "project-specific morphology gate remains in the core",
        "wide$EMM": "IMM/EMM-specific comparison remains in the core",
        "..image_id": "collision-prone data.table image lookup remains in the core",
        "..compartment": "collision-prone data.table compartment lookup remains in the core",
    }
    for term, detail in forbidden.items():
        if term in core_text:
            findings.append(("ERROR", "core", detail))

    required_core_terms = {
        "reconstruct_hdab_image": "H-DAB reconstruction function is absent",
        "paint_compartment_overlay": "color-coded compartment overlay is absent",
        "nuclear_h_score": "nuclear H-score is absent",
        "cytoplasm_h_score": "cytoplasmic H-score is absent",
        "extracellular_positive_area_fraction": "extracellular burden metric is absent",
        "write_default_domain_plots": "four-domain plotting helper is absent",
        "NO_FINITE_VALUES_PLACEHOLDER": "empty-domain plotting fallback is absent",
        "plot_axis_mode": "publication-axis mode is absent",
        "generate_zoomed_plots": "optional zoomed QC plotting is absent",
        "dab_positive_mask": "DAB-positive QC mask is absent",
        "each condition has n=1": "low-n caption contract is absent",
        "annotation_colour": "semantic-color ROI annotation proof is absent",
        "NOT_EVALUABLE_N_LT_2": "low-n inferential guardrail is absent",
        "normalize_path_portable": "portable path normalization is absent",
        "read_if_image": "IF image reader is absent",
        "segment_if_image": "IF segmentation helper is absent",
        "quantify_if_compartments": "IF 4-compartment quantification is absent",
    }
    for term, detail in required_core_terms.items():
        if term not in core_text:
            findings.append(("ERROR", "core", detail))

    version_path = ROOT / "VERSION"
    package_version = version_path.read_text(encoding="utf-8").strip() if version_path.is_file() else None
    if not package_version:
        findings.append(("ERROR", "VERSION", "VERSION file is missing or empty"))

    version_sources = {
        "scripts/ihc_helpers.R": extract_simple_version(ROOT / "scripts/ihc_helpers.R", r'version\s*=\s*"([^"]+)"'),
        "SKILL.md": extract_simple_version(ROOT / "SKILL.md", r'^version:\s*([^\s]+)'),
        "CITATION.cff": extract_simple_version(ROOT / "CITATION.cff", r'^version:\s*([^\s]+)'),
    }
    for scope, found_version in version_sources.items():
        if found_version != package_version:
            findings.append(("ERROR", scope, f"version {found_version!r} does not match VERSION {package_version!r}"))

    # DESCRIPTION is consumed by R's package tooling, whose Version field
    # rejects prerelease hyphens (e.g. 2.3.0-alpha.2). Keep a valid numeric
    # package version there while requiring an explicit public release label.
    description_version = extract_simple_version(ROOT / "DESCRIPTION", r'^Version:\s*([^\s]+)')
    description_release_version = extract_simple_version(ROOT / "DESCRIPTION", r'^X-Release-Version:\s*([^\s]+)')
    r_compatible_version = re.sub(r"-(?:alpha|beta|rc)\.?", ".", package_version)
    if description_release_version != package_version:
        findings.append(("ERROR", "DESCRIPTION", f"X-Release-Version {description_release_version!r} does not match VERSION {package_version!r}"))
    if description_version not in {package_version, r_compatible_version}:
        findings.append(("ERROR", "DESCRIPTION", f"R package Version {description_version!r} is not compatible with VERSION {package_version!r}"))

    renv_path = ROOT / "renv.lock"
    if renv_path.is_file():
        try:
            lock = json.loads(renv_path.read_text(encoding="utf-8"))
            direct = set(lock.get("Packages", {}))
            required_direct = {"EBImage", "data.table", "ggplot2", "ragg", "svglite", "tiff"}
            if missing_direct := required_direct - direct:
                findings.append(("ERROR", "renv.lock", "missing direct packages: " + ", ".join(sorted(missing_direct))))
        except json.JSONDecodeError as exc:
            findings.append(("ERROR", "renv.lock", f"invalid JSON: {exc}"))

    if findings:
        for level, scope, detail in findings:
            print(f"{level}\t{scope}\t{detail}")
        return 1 if any(level == "ERROR" for level, _, _ in findings) else 0

    print("PASS\tpackage\tStatic structure, delimiters, schemas, GitHub files, portable-path contracts, v2.3.0-alpha.2 contracts, and dual-modality core checks passed")
    if package_version:
        print(f"INFO\tversion\t{package_version}")
    print("INFO\tmodalities\tbrightfield_dab,immunofluorescence")
    print("INFO\tdefault_figures\tglobal,nucleus,cytoplasm,extracellular,colocalization,puncta")
    print("LIMITATION\truntime\tR parser, EBImage execution, and graphics rendering are checked by the bundled synthetic smoke test, not by this static checker")
    return 0


if __name__ == "__main__":
    sys.exit(main())
