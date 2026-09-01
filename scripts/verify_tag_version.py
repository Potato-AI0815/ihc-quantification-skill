#!/usr/bin/env python3
"""Tag-to-package-version CI contract.

On branch pushes (no tag context) this verifies only that every internal
release-version source agrees with ``VERSION``.

On tag pushes (``GITHUB_REF_TYPE == "tag"``) it additionally requires that the
Git tag name, after removing a leading ``v``, equals ``VERSION`` exactly.  This
is the automated guard that prevents a repeat of the v2.3.0 incident, where a
``v2.3.0`` stable tag pointed at a commit whose internal metadata still said
``2.3.0-rc3``.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read_version(rel: str, pattern: str) -> str | None:
    path = ROOT / rel
    if not path.is_file():
        print(f"FAIL\tinternal-version-contract\t{rel} is missing")
        raise SystemExit(1)
    match = re.search(pattern, path.read_text(encoding="utf-8"), flags=re.MULTILINE)
    if not match:
        print(f"FAIL\tinternal-version-contract\t{rel} does not contain the expected version field")
        raise SystemExit(1)
    return match.group(1).strip()


def main() -> int:
    version = read_version("VERSION", r"^\s*([^\s]+)\s*$")

    # R package tooling also carries a numeric Version field in DESCRIPTION;
    # for a canonical stable line such as 2.3.2 it must equal VERSION exactly.
    sources = {
        "DESCRIPTION Version": (read_version("DESCRIPTION", r"^Version:\s*([^\s]+)"), "DESCRIPTION"),
        "DESCRIPTION X-Release-Version": (read_version("DESCRIPTION", r"^X-Release-Version:\s*([^\s]+)"), "DESCRIPTION"),
        "CITATION.cff version": (read_version("CITATION.cff", r"^version:\s*([^\s]+)"), "CITATION.cff"),
        "SKILL.md frontmatter version": (read_version("SKILL.md", r"^version:\s*([^\s]+)"), "SKILL.md"),
        "scripts/ihc_helpers.R release constant": (
            read_version("scripts/ihc_helpers.R", r'version\s*=\s*"([^"]+)"'),
            "scripts/ihc_helpers.R",
        ),
    }

    mismatches = []
    for label, (found, _) in sources.items():
        if found != version:
            mismatches.append(f"{label} {found} != VERSION {version}")

    if mismatches:
        for item in mismatches:
            print(f"FAIL\tinternal-version-contract\t{item}")
        return 1

    for label, (found, _scope) in sources.items():
        print(f"PASS\tinternal-version-contract\t{label} == {version}")

    if os.environ.get("GITHUB_REF_TYPE") == "tag":
        ref_name = os.environ.get("GITHUB_REF_NAME", "").strip()
        tag_version = ref_name[1:] if ref_name.startswith("v") else ref_name
        if not tag_version:
            print("FAIL\ttag-version-contract\tGITHUB_REF_NAME is empty on a tag event")
            return 1
        if tag_version == version:
            print(f"PASS\ttag-version-contract\t{tag_version} == {version}")
        else:
            print(f"FAIL\ttag-version-contract\ttag {ref_name} != VERSION {version}")
            return 1
    else:
        print("INFO\ttag-version-contract\tno tag context; internal version consistency only")

    return 0


if __name__ == "__main__":
    sys.exit(main())
