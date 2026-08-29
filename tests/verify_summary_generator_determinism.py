#!/usr/bin/env python3
"""Determinism regression test for the external summary report generator.

external_validation/scripts/build_summary_reports.py must be a pure function
of its inputs: the result CSVs plus external_validation/VALIDATION_METADATA.json.
Rebuilding on a different wall-clock date must produce byte-identical
EXTERNAL_VALIDATION_MATRIX.csv and EXTERNAL_REALDATA_VALIDATION_REPORT.md;
otherwise the release manifest would drift for zero content change.
"""
from __future__ import annotations

import hashlib
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GENERATOR = ROOT / "external_validation" / "scripts" / "build_summary_reports.py"
ARTIFACTS = [
    ROOT / "EXTERNAL_VALIDATION_MATRIX.csv",
    ROOT / "EXTERNAL_REALDATA_VALIDATION_REPORT.md",
]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def build() -> dict[Path, str]:
    result = subprocess.run(
        [sys.executable, str(GENERATOR)],
        capture_output=True, text=True, timeout=120,
    )
    if result.returncode != 0:
        print(result.stdout)
        print(result.stderr)
        raise SystemExit("FAIL\tsummary-determinism\tgenerator exited non-zero")
    return {path: sha256(path) for path in ARTIFACTS}


def main() -> int:
    if not Path(GENERATOR).is_file():
        print("FAIL\tsummary-determinism\tgenerator missing")
        return 1

    first = build()
    second = build()

    failures = []
    for path in ARTIFACTS:
        if first[path] != second[path]:
            failures.append(f"{path.name} rebuild differs ({first[path][:12]} -> {second[path][:12]})")
        else:
            print(f"PASS\tsummary-determinism\t{path.name} byte-identical across rebuilds ({first[path][:12]}...)")

    source = (ROOT / "external_validation" / "VALIDATION_METADATA.json").read_text(encoding="utf-8")
    if '"validation_date"' not in source or '"release_milestone"' not in source:
        failures.append("VALIDATION_METADATA.json is missing validation_date/release_milestone")
    else:
        print("PASS\tsummary-determinism\tvalidation date sourced from VALIDATION_METADATA.json")

    generator_text = GENERATOR.read_text(encoding="utf-8")
    if "date.today" in generator_text or "datetime.now" in generator_text:
        failures.append("generator still derives the report date from the wall clock")
    else:
        print("PASS\tsummary-determinism\tgenerator contains no wall-clock date source")

    if failures:
        for item in failures:
            print(f"FAIL\tsummary-determinism\t{item}")
        return 1
    print("PASS\tsummary-determinism\tgenerator output is deterministic")
    return 0


if __name__ == "__main__":
    sys.exit(main())
