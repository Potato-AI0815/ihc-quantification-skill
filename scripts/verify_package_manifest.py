#!/usr/bin/env python3
"""Verify PACKAGE_MANIFEST.sha256 and detect missing or unlisted release files."""
from __future__ import annotations

import hashlib
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "PACKAGE_MANIFEST.sha256"
EXCLUDED = {Path("PACKAGE_MANIFEST.sha256")}


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> int:
    if not MANIFEST.is_file():
        print("ERROR\tmanifest\tPACKAGE_MANIFEST.sha256 is missing")
        return 1
    expected: dict[Path, str] = {}
    for line_number, line in enumerate(MANIFEST.read_text(encoding="utf-8").splitlines(), start=1):
        if not line.strip():
            continue
        try:
            hash_value, rel = line.split("  ", 1)
        except ValueError:
            print(f"ERROR\tmanifest\tinvalid line {line_number}: {line}")
            return 1
        expected[Path(rel)] = hash_value
    actual_files = {
        path.relative_to(ROOT)
        for path in ROOT.rglob("*")
        if path.is_file() and path.relative_to(ROOT) not in EXCLUDED and ".git" not in path.parts
    }
    missing = sorted(set(expected) - actual_files)
    unlisted = sorted(actual_files - set(expected))
    mismatched = []
    for rel, expected_hash in expected.items():
        path = ROOT / rel
        if path.is_file() and digest(path) != expected_hash:
            mismatched.append(rel)
    if missing or unlisted or mismatched:
        for rel in missing:
            print(f"ERROR\tmissing\t{rel}")
        for rel in unlisted:
            print(f"ERROR\tunlisted\t{rel}")
        for rel in mismatched:
            print(f"ERROR\thash_mismatch\t{rel}")
        return 1
    print(f"PASS\tmanifest\t{len(expected)} files verified")
    return 0


if __name__ == "__main__":
    sys.exit(main())
