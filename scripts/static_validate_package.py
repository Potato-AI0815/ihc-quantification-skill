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
    "scripts/preflight_public_release.py",
    "scripts/verify_package_manifest.py",
    "scripts/bootstrap_renv.R",
    "references/templates/manifest_template.csv",
    "references/templates/roi_annotations_template.csv",
    "references/templates/analysis_parameters_template.csv",
    "tests/synthetic_fixture/manifest.csv",
    "tests/synthetic_fixture/roi_annotations.csv",
    "tests/verify_synthetic_output.R",
    "tests/verify_plot_contract.R",
    "tests/verify_path_contract.R",
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
}

CORE_R = [
    "scripts/path_utils.R",
    "scripts/ihc_helpers.R",
    "scripts/ihc_plot_helpers.R",
    "scripts/run_ihc_quantification.R",
    "scripts/plot_ihc_comparison.R",
    "scripts/annotate_ihc_rois.R",
    "scripts/validate_ihc_inputs.R",
    "tests/verify_synthetic_output.R",
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
    }
    for term, detail in required_core_terms.items():
        if term not in core_text:
            findings.append(("ERROR", "core", detail))

    skill_path = ROOT / "SKILL.md"
    if skill_path.is_file():
        skill = skill_path.read_text(encoding="utf-8")
        required_contracts = {
            "GLOBAL": "whole-tissue default is not documented",
            "H-DAB reconstruction": "H-DAB QC is not documented",
            "bar": "bar-background plot contract is not documented",
            "0–100%": "fixed fraction-axis contract is not documented",
            "0–300": "fixed H-score-axis contract is not documented",
            "zoomed": "diagnostic zoom semantics are not documented",
            "nuclear_h_score": "nuclear main metric is not documented",
            "cytoplasm_h_score": "cytoplasmic main metric is not documented",
            "Extracellular": "extracellular semantics are not documented",
            "ihc_manual_qc_template.csv": "manual QC output is not documented",
        }
        for term, detail in required_contracts.items():
            if term not in skill:
                findings.append(("ERROR", "SKILL.md", detail))

    version_path = ROOT / "VERSION"
    package_version = version_path.read_text(encoding="utf-8").strip() if version_path.is_file() else None
    if package_version != "2.2.2":
        findings.append(("ERROR", "VERSION", f"expected 2.2.2, found {package_version!r}"))

    version_sources = {
        "scripts/ihc_helpers.R": extract_simple_version(ROOT / "scripts/ihc_helpers.R", r'version\s*=\s*"([^"]+)"'),
        "SKILL.md": extract_simple_version(ROOT / "SKILL.md", r'^version:\s*([^\s]+)'),
        "DESCRIPTION": extract_simple_version(ROOT / "DESCRIPTION", r'^Version:\s*([^\s]+)'),
        "CITATION.cff": extract_simple_version(ROOT / "CITATION.cff", r'^version:\s*([^\s]+)'),
    }
    for scope, found_version in version_sources.items():
        if found_version != package_version:
            findings.append(("ERROR", scope, f"version {found_version!r} does not match VERSION {package_version!r}"))
    version_match = re.match(r"(.+)", package_version or "")

    renv_path = ROOT / "renv.lock"
    if renv_path.is_file():
        try:
            lock = json.loads(renv_path.read_text(encoding="utf-8"))
            direct = set(lock.get("Packages", {}))
            required_direct = {"EBImage", "data.table", "ggplot2", "ragg", "svglite"}
            if missing_direct := required_direct - direct:
                findings.append(("ERROR", "renv.lock", "missing direct packages: " + ", ".join(sorted(missing_direct))))
        except json.JSONDecodeError as exc:
            findings.append(("ERROR", "renv.lock", f"invalid JSON: {exc}"))

    if findings:
        for level, scope, detail in findings:
            print(f"{level}\t{scope}\t{detail}")
        return 1 if any(level == "ERROR" for level, _, _ in findings) else 0

    print("PASS\tpackage\tStatic structure, delimiters, schemas, GitHub files, portable-path contracts, v2.2.2 contracts, and generic-core checks passed")
    if version_match:
        print(f"INFO\tversion\t{package_version}")
    print("INFO\tdefault_figures\tglobal,nucleus,cytoplasm,extracellular")
    print("LIMITATION\truntime\tR parser, EBImage execution, and graphics rendering are checked by the bundled synthetic smoke test, not by this static checker")
    return 0


if __name__ == "__main__":
    sys.exit(main())
