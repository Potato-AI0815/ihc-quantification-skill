#!/usr/bin/env python3
"""Frozen-core non-comment executable diff guard.

Compares the frozen analytical R scripts at the immutable ``v2.3.0-rc3``
tag with the current working tree after stripping R comments and blank
lines and normalizing intra-line whitespace and line endings.

Honest scope: this is a *non-comment executable diff guard*, not a formal
semantic-equivalence proof. It cannot reason about R semantics; it
guarantees only that no executable (non-comment, non-blank) line differs
after whitespace normalization. Any real change to thresholds, parameter
defaults, formulas, or branching necessarily alters the normalized
non-comment text and is reported here. A reviewer must inspect the printed
unified diff when this guard fails.

Allowances:
- comment lines and blank lines (stripped before comparison), which covers
  the version-neutral source-header rewrite between the rc3 tag and main
- the explicit allow-list below for normalized non-comment lines that a
  release may legitimately change (currently empty; add exact normalized
  line pairs there only for constants approved in release review)

Usage: python tests/verify_frozen_core_diff.py [--base v2.3.0-rc3]
"""

from __future__ import annotations

import argparse
import difflib
import subprocess
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

# Explicit allow-list of normalized non-comment line pairs permitted to
# differ from the base tag: (file, base_line, current_line). Keep this
# minimal; entries require release-review justification. Comment-only and
# blank-line changes never appear here because comments are stripped.
ALLOWED_LINE_CHANGES: tuple[tuple[str, str, str], ...] = ()


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


def check_file(path: str, base: str) -> str:
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
    args = parser.parse_args()
    base = args.base

    verify = subprocess.run(
        ["git", "-C", str(ROOT), "rev-parse", "--verify", "--quiet",
         f"{base}^{{commit}}"],
        capture_output=True, text=True,
    )
    if verify.returncode != 0:
        fail(f"base ref {base!r} is not available; run `git fetch origin --tags`")

    print(f"INFO\tfrozen-core-diff\tnon-comment executable diff guard vs "
          f"{base} (not a formal semantic proof)")
    results = [check_file(path, base) for path in FROZEN_FILES]
    if "FAIL" in results:
        fail(f"summary: {results.count('FAIL')} frozen file(s) carry "
             f"unexplained non-comment differences vs {base}")
    warns = results.count("WARN")
    warn_note = f" ({warns} file(s) allow-listed)" if warns else ""
    print(f"PASS\tfrozen-core-diff\tall {len(FROZEN_FILES)} frozen analysis "
          f"files match {base} outside comments/blank lines{warn_note}")


if __name__ == "__main__":
    main()
