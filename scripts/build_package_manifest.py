#!/usr/bin/env python3
"""Regenerate PACKAGE_MANIFEST.sha256 from the current checkout.

Uses the exact exclusion rules of verify_package_manifest.py so that a fresh
manifest always verifies. Run this after adding, removing, or editing any
package file; never edit the manifest by hand.
"""
from __future__ import annotations

import hashlib
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from verify_package_manifest import MANIFEST, ROOT, is_excluded  # noqa: E402


def main() -> int:
    files = sorted(
        (path.relative_to(ROOT) for path in ROOT.rglob("*")
         if path.is_file() and not is_excluded(path.relative_to(ROOT))
         and ".git" not in path.parts),
        key=lambda rel: rel.as_posix(),
    )
    lines = []
    for rel in files:
        digest = hashlib.sha256((ROOT / rel).read_bytes()).hexdigest()
        lines.append(f"{digest}  {rel.as_posix()}\n")
    MANIFEST.write_text("".join(lines), encoding="utf-8")
    print(f"WROTE\t{MANIFEST}\t{len(files)} files")
    return 0


if __name__ == "__main__":
    sys.exit(main())
