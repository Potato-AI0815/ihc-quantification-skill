#!/usr/bin/env python3
"""Fail when a public release contains likely private paths, identifiers, or unapproved image assets."""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TEXT_SUFFIXES = {
    ".md", ".txt", ".csv", ".tsv", ".yaml", ".yml", ".json", ".cff",
    ".r", ".py", ".ps1", ".sh", ".cmd", ".lock", ""
}
IMAGE_SUFFIXES = {".png", ".jpg", ".jpeg", ".webp", ".tif", ".tiff", ".svs", ".ndpi", ".mrxs", ".scn", ".czi", ".lif"}
RAW_IMAGE_SUFFIXES = {".tif", ".tiff", ".svs", ".ndpi", ".mrxs", ".scn", ".czi", ".lif"}
PUBLIC_IMAGE_PREFIXES = {
    Path("tests/synthetic_fixture/images"),
    Path("tests/synthetic_if_fixture/images"),
    Path("tests/synthetic_coloc_fixture/images"),
    Path("tests/synthetic_puncta_fixture/images"),
    Path("docs/assets/synthetic"),
    # Small, derived PNGs from explicitly documented public teaching datasets.
    # Raw microscopy files remain blocked everywhere else.
    Path("docs/assets/public_validation"),
    Path("external_validation/results/figures")
}
PUBLIC_RAW_IMAGE_PREFIXES = {
    Path("tests/synthetic_fixture/images"),
    Path("tests/synthetic_if_fixture/images"),
    Path("tests/synthetic_coloc_fixture/images"),
    Path("tests/synthetic_puncta_fixture/images"),
}
PRIVATE_FILENAME_PATTERNS = [
    re.compile(r"^ASSET_MANIFEST", re.IGNORECASE),
    re.compile(r"^IHC_TEST_REPORT", re.IGNORECASE),
    re.compile(r"^SOURCE_NOTES", re.IGNORECASE),
    re.compile(r"(?:^|[_-])qc_overview\\.(?:png|jpe?g|webp)$", re.IGNORECASE),
    re.compile(r"^ihc_main_.*\\.(?:png|jpe?g|webp)$", re.IGNORECASE),
]
PATH_PATTERNS = {
    "Windows absolute path": re.compile(r"(?<![A-Za-z0-9_])(?:[A-Za-z]:[\\/]|\\\\\\\\[^\\/\s]+[\\/][^\\/\s]+)"),
    "Unix/macOS user path": re.compile(r"/(?:home|Users)/[^/\s]+/"),
}
PLACEHOLDER_PATH_ALLOW = re.compile(r"(?:example|placeholder|<[^>]+>|path/to)", re.IGNORECASE)
PRIVATE_TOKEN_FILE = ROOT / ".private_tokens.txt"


def relative(path: Path) -> Path:
    return path.relative_to(ROOT)


def under_prefix(rel: Path, prefixes: set[Path]) -> bool:
    return any(rel == prefix or prefix in rel.parents for prefix in prefixes)


def private_tokens() -> list[str]:
    tokens: list[str] = []
    if PRIVATE_TOKEN_FILE.is_file():
        tokens.extend(line.strip() for line in PRIVATE_TOKEN_FILE.read_text(encoding="utf-8").splitlines() if line.strip() and not line.lstrip().startswith("#"))
    env = os.environ.get("IHC_PRIVATE_TOKENS", "")
    if env:
        tokens.extend(token.strip() for token in env.split("||") if token.strip())
    return sorted(set(tokens), key=len, reverse=True)


def binary_text_probe(path: Path, max_bytes: int = 2_000_000) -> str:
    data = path.read_bytes()[:max_bytes]
    return data.decode("latin-1", errors="ignore")


def main() -> int:
    findings: list[str] = []
    tokens = private_tokens()
    for path in ROOT.rglob("*"):
        if not path.is_file():
            continue
        rel = relative(path)
        if rel in {Path("scripts/preflight_public_release.py"), Path("PACKAGE_MANIFEST.sha256"), Path(".private_tokens.txt")}:
            continue
        if any(part in {".git", "renv", "Rlib", "work", ".external_validation_cache", "synthetic_output", "synthetic_if_output", "synthetic_coloc_output", "synthetic_puncta_output", "__pycache__"} for part in rel.parts):
            continue

        for pattern in PRIVATE_FILENAME_PATTERNS:
            if pattern.search(path.name) and not under_prefix(rel, PUBLIC_IMAGE_PREFIXES):
                findings.append(f"PRIVATE_FILENAME\t{rel}\treview-derived or local asset filename")
                break

        suffix = path.suffix.lower()
        if suffix in IMAGE_SUFFIXES and not under_prefix(rel, PUBLIC_IMAGE_PREFIXES):
            findings.append(f"UNAPPROVED_IMAGE\t{rel}\tpublic images must live under an approved demo directory")
        if suffix in RAW_IMAGE_SUFFIXES and not under_prefix(rel, PUBLIC_RAW_IMAGE_PREFIXES):
            findings.append(f"RAW_IMAGE\t{rel}\traw microscopy/WSI file must not be public")
        if path.stat().st_size > 8_000_000 and not under_prefix(rel, PUBLIC_IMAGE_PREFIXES):
            findings.append(f"LARGE_FILE\t{rel}\tfile exceeds 8 MB; review for data leakage")

        text = None
        is_text_file = False
        if suffix in TEXT_SUFFIXES or path.name in {"VERSION", "DESCRIPTION", "LICENSE"}:
            try:
                text = path.read_text(encoding="utf-8")
                is_text_file = True
            except UnicodeDecodeError:
                text = None
        elif suffix in IMAGE_SUFFIXES:
            text = binary_text_probe(path)

        if text is None:
            continue
        if is_text_file and rel != Path("scripts/path_utils.R"):
          for label, pattern in PATH_PATTERNS.items():
            for match in pattern.finditer(text):
              context = text[max(0, match.start()-30):match.end()+30]
              if not PLACEHOLDER_PATH_ALLOW.search(context):
                findings.append(f"PRIVATE_PATH\t{rel}\t{label}: {match.group(0)}")
                break
        for token in tokens:
            if token in text or token in path.name:
                findings.append(f"PRIVATE_TOKEN\t{rel}\tmatched token supplied via .private_tokens.txt or IHC_PRIVATE_TOKENS")

    if findings:
        print("Public-release preflight failed:")
        for finding in sorted(set(findings)):
            print(finding)
        return 1
    print("PASS\tpublic_release\tOnly approved synthetic/public-validation demo images are present; no supplied private tokens or likely user-specific paths were found")
    return 0


if __name__ == "__main__":
    sys.exit(main())
