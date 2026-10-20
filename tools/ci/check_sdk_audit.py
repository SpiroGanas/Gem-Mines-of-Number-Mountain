"""Every dependency the project carries is in docs/sdk-audit.md (P3-S24-04, CLAUDE.md rule 3).

Run:  python tools/ci/check_sdk_audit.py [--root PATH]

Fails (exit code 1) when one of these is not named in the audit's tables:

  - a folder under addons/ (a Godot addon or plugin, shipped or dev-only);
  - a folder under android/plugins/ (an Android plugin, even an empty placeholder);
  - an editor plugin or autoload in project.godot that lives under res://addons/.

A name counts as listed when it appears (ignoring case) in a table row of the audit. Google Play's
Families Policy review relies on that table being complete.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
AUDIT = Path("docs") / "sdk-audit.md"

_ADDON_REF_RE = re.compile(r"res://addons/([^/\"]+)/")


def dependencies(root: Path) -> dict[str, str]:
    """{dependency name: where it was found}."""
    found: dict[str, str] = {}
    for folder in ("addons", "android/plugins"):
        base = root / folder
        if base.is_dir():
            for entry in sorted(base.iterdir()):
                if entry.is_dir() and not entry.name.startswith("."):
                    found.setdefault(entry.name, f"{folder}/{entry.name}/")
    project = root / "project.godot"
    if project.is_file():
        for name in _ADDON_REF_RE.findall(project.read_text(encoding="utf-8")):
            found.setdefault(name, "project.godot")
    return found


def audit_rows(root: Path) -> str:
    path = root / AUDIT
    if not path.is_file():
        return ""
    return "\n".join(line for line in path.read_text(encoding="utf-8").splitlines() if line.lstrip().startswith("|")).lower()


def missing(root: Path) -> list[str]:
    rows = audit_rows(root)
    return [f"{name} ({where}) is not in {AUDIT.as_posix()}" for name, where in dependencies(root).items() if name.lower() not in rows]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="SDK audit completeness check")
    parser.add_argument("--root", type=Path, default=ROOT)
    args = parser.parse_args(argv)
    if not (args.root / AUDIT).is_file():
        print(f"ERROR: {AUDIT.as_posix()} is missing")
        return 1
    problems = missing(args.root)
    for problem in problems:
        print("ERROR:", problem)
    print(f"sdk audit: {len(dependencies(args.root))} dependenc(ies) found, {len(problems)} missing from the audit")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
