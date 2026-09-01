#!/usr/bin/env python3
"""Frozen-core non-comment executable diff guard.

Compares the frozen analytical R scripts with immutable baselines after
stripping R comments and blank lines and normalizing intra-line whitespace
and line endings.

- DAB / unchanged frozen files are compared with the immutable
  ``v2.3.0-rc3`` tag.  A small exact allow-list covers the release version
  constant in ``scripts/ihc_helpers.R``.
- The five IF files intentionally changed by the reviewed v2.3.2
  scientific-contract patch are compared with the immutable ``v2.3.1`` tag
  and must exactly match ``tests/approved_v232_if_core.patch``.  Any future
  executable change to those files fails until a reviewed patch file is
  regenerated with ``--write-approved-patch``.

Honest scope: this is a *non-comment executable diff guard*, not a formal
semantic-equivalence proof.  It cannot reason about R semantics; it
guarantees that no executable (non-comment, non-blank) line differs beyond
the reviewed allowances.
"""
from __future__ import annotations

import argparse
import difflib
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

FROZEN_FILES = (
    "scripts/if_segmentation.R",
    "scripts/if_quantification_helpers.R",
    "scripts/if_puncta.R",
    "scripts/if_preprocessing.R",
    "scripts/if_colocalization.R",
    "scripts/if_qc_helpers.R",
    "scripts/run_if_quantification.R",
    "scripts/run_ihc_quantification.R",
    "scripts/ihc_helpers.R",
)

APPROVED_PATCH_BASE = "v2.3.1"
APPROVED_IF_FILES = (
    "scripts/if_quantification_helpers.R",
    "scripts/if_puncta.R",
    "scripts/if_preprocessing.R",
    "scripts/if_colocalization.R",
    "scripts/run_if_quantification.R",
)
APPROVED_PATCH_FILE = ROOT / "tests" / "approved_v232_if_core.patch"

# Exact allow-list of normalized non-comment line pairs permitted to differ
# from v2.3.0-rc3.  Keep this minimal; entries require release-review
# justification.  Comment-only and blank-line changes never appear here
# because comments are stripped.
ALLOWED_LINE_CHANGES: tuple[tuple[str, str, str], ...] = (
    # Release identity metadata, not an analytical parameter or threshold.
    ("scripts/ihc_helpers.R", 'version = "2.3.0-rc3",', 'version = "2.3.2",'),
)


def fail(message: str) -> None:
    print(f"FAIL\tfrozen-core-diff\t{message}")
    raise SystemExit(1)


def git_show(ref: str, path: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(ROOT), "show", f"{ref}:{path}"],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        fail(f"cannot read {path} from {ref}: {result.stderr.strip()}")
    return result.stdout


def strip_comments(text: str) -> list[str]:
    """Drop R comments (quote-aware) and blank lines; collapse whitespace."""
    lines: list[str] = []
    for raw in text.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
        quote = None
        cut = len(raw)
        i = 0
        while i < len(raw):
            ch = raw[i]
            if quote is not None:
                if ch == "\\" and i + 1 < len(raw):
                    i += 2
                    continue
                if ch == quote:
                    quote = None
            elif ch in ("'", '"'):
                quote = ch
            elif ch == "#":
                cut = i
                break
            i += 1
        line = " ".join(raw[:cut].split())
        if line:
            lines.append(line)
    return lines


def normalized_diff(path: str, base: str) -> str:
    base_lines = strip_comments(git_show(base, path))
    current_file = ROOT / path
    if not current_file.is_file():
        fail(f"frozen file missing from working tree: {path}")
    curr_lines = strip_comments(current_file.read_text(encoding="utf-8"))
    diff = difflib.unified_diff(
        [ln + "\n" for ln in base_lines],
        [ln + "\n" for ln in curr_lines],
        fromfile=f"{base}:{path}", tofile=f"worktree:{path}",
        lineterm="\n",
    )
    return "".join(diff).rstrip("\n") + "\n"


def approved_patch_sections() -> dict[str, str]:
    sections: dict[str, str] = {}
    for path in APPROVED_IF_FILES:
        sections[path] = normalized_diff(path, APPROVED_PATCH_BASE)
    return sections


def write_approved_patch() -> None:
    chunks = ["# Approved v2.3.2 IF analytical-core patch vs immutable "
              "v2.3.1 (normalized non-comment executable lines).\n"]
    for path in APPROVED_IF_FILES:
        text = normalized_diff(path, APPROVED_PATCH_BASE)
        chunks.append(f"\n@@ {path}\n")
        chunks.append(text)
    APPROVED_PATCH_FILE.write_text("".join(chunks), encoding="utf-8")
    print(f"WROTE\t{APPROVED_PATCH_FILE}")


def read_approved_patch() -> dict[str, str]:
    if not APPROVED_PATCH_FILE.is_file():
        fail(f"approved IF patch file missing: {APPROVED_PATCH_FILE}; "
             f"review changes and run {Path(__file__).name} --write-approved-patch")
    text = APPROVED_PATCH_FILE.read_text(encoding="utf-8")
    sections: dict[str, str] = {}
    current_path = None
    current_lines: list[str] = []
    for raw in text.splitlines():
        if raw.startswith("@@ ") and not raw.startswith("@@ -"):
            if current_path is not None:
                sections[current_path] = "\n".join(current_lines).rstrip("\n") + "\n"
            current_path = raw[3:].strip()
            current_lines = []
        elif current_path is not None:
            current_lines.append(raw)
    if current_path is not None:
        sections[current_path] = "\n".join(current_lines).rstrip("\n") + "\n"
    return sections


def check_approved(path: str) -> str:
    expected_sections = read_approved_patch()
    current_sections = approved_patch_sections()
    current = current_sections.get(path, "")
    expected = expected_sections.get(path)
    if expected == current:
        return "WARN"
    if expected is None:
        print(f"FAIL\tfrozen-core-diff\t{path}: file is not covered by the "
              f"approved v2.3.2 IF patch")
    else:
        print(f"FAIL\tfrozen-core-diff\t{path}: executable content differs "
              f"from the approved v2.3.2 patch vs {APPROVED_PATCH_BASE}")
        diff = difflib.unified_diff(
            (expected or "").splitlines(keepends=True),
            (current or "").splitlines(keepends=True),
            fromfile=f"approved:{path}", tofile=f"worktree:{path}",
        )
        for chunk in diff:
            print(chunk, end="")
    return "FAIL"


def check_file(path: str, base: str) -> str:
    if path in APPROVED_IF_FILES:
        return check_approved(path)

    current_file = ROOT / path
    if not current_file.is_file():
        fail(f"frozen file missing from working tree: {path}")
    base_lines = strip_comments(git_show(base, path))
    curr_lines = strip_comments(current_file.read_text(encoding="utf-8"))
    if base_lines == curr_lines:
        return "PASS"

    allowed = {(p, b, c) for p, b, c in ALLOWED_LINE_CHANGES}
    matcher = difflib.SequenceMatcher(a=base_lines, b=curr_lines, autojunk=False)
    unexplained: list[str] = []
    for tag, i1, i2, j1, j2 in matcher.get_opcodes():
        if tag == "equal":
            continue
        if (tag == "replace" and (i2 - i1) == 1 and (j2 - j1) == 1
                and (path, base_lines[i1], curr_lines[j1]) in allowed):
            unexplained.append(
                f"allow-listed: {base_lines[i1]!r} -> {curr_lines[j1]!r}")
            continue
        unexplained.append(f"{tag}: base[{i1}:{i2}]={base_lines[i1:i2]} "
                           f"curr[{j1}:{j2}]={curr_lines[j1:j2]}")
    if all(item.startswith("allow-listed:") for item in unexplained):
        return "WARN"

    print(f"FAIL\tfrozen-core-diff\t{path}: non-comment executable text "
          f"differs from {base}")
    diff = difflib.unified_diff(
        [ln + "\n" for ln in base_lines],
        [ln + "\n" for ln in curr_lines],
        fromfile=f"{base}:{path}", tofile=f"worktree:{path}",
    )
    for chunk in diff:
        print(chunk, end="")
    for item in unexplained:
        print(f"  {path}: {item}")
    return "FAIL"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", default="v2.3.0-rc3")
    parser.add_argument("--write-approved-patch", action="store_true")
    args = parser.parse_args()
    base = args.base

    if args.write_approved_patch:
        write_approved_patch()
        return

    for ref in (base, APPROVED_PATCH_BASE):
        verify = subprocess.run(
            ["git", "-C", str(ROOT), "rev-parse", "--verify", "--quiet",
             f"{ref}^{{commit}}"],
            capture_output=True, text=True,
        )
        if verify.returncode != 0:
            fail(f"base ref {ref!r} is not available; run `git fetch origin --tags`")

    print(f"INFO\tfrozen-core-diff\tnon-comment executable diff guard vs "
          f"{base} and approved IF patch vs {APPROVED_PATCH_BASE} "
          f"(not a formal semantic proof)")
    results = [check_file(path, base) for path in FROZEN_FILES]
    if "FAIL" in results:
        fail(f"summary: {results.count('FAIL')} frozen file(s) carry "
             f"unexplained non-comment differences")
    warns = results.count("WARN")
    warn_note = f" ({warns} reviewed file(s)/line(s) accounted for)" if warns else ""
    print(f"PASS\tfrozen-core-diff\tall {len(FROZEN_FILES)} frozen analysis "
          f"files match their reviewed baselines outside comments/blank lines{warn_note}")


if __name__ == "__main__":
    main()
