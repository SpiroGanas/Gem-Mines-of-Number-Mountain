"""Static performance checks for Gem Mines of Number Mountain (P1-S11-03).

Run:  python tools/ci/perf_check.py [--root PATH]

Fails (exit code 1) when:

  1. A `_process` or `_physics_process` function in scenes/, scripts/ or autoload/ allocates
     every frame: `.new(`, an Array or Dictionary literal, a Packed*Array constructor, string
     formatting or str(). CLAUDE.md: no allocations in `_process` hot paths.
  1b. The same, in the `_draw` of a script whose property setter calls queue_redraw() (peer review
     02, section 4.5) and whose property some `tween_property(..., "name", ...)` animates: that
     `_draw` runs every frame of the animation; the project has no `_process`, so these are its real per-frame paths. A `_draw`
     that only runs after a one-off change (a new problem, a resize) is not a hot path and may
     allocate. Put shapes and style boxes in member variables built once.
  2. Audio under assets/ is not OGG (CLAUDE.md: OGG audio).
  3. The files the Android export ships (everything but the preset's exclude_filter) are over
     CONTENT_BUDGET_MB. The engine for two ABIs adds about 70 MB, so this keeps the download
     well under the 150 MB limit.

Frame rate itself is measured on the devices with the Godot profiler (docs/decisions.md).
"""
from __future__ import annotations

import argparse
import fnmatch
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CODE_DIRS = ("scenes", "scripts", "autoload")
HOT_FUNCTIONS = ("_process", "_physics_process")
AUDIO_SUFFIXES = (".wav", ".mp3", ".flac", ".aiff", ".ogg")
CONTENT_BUDGET_MB = 60.0
# Never part of an export, whatever the preset says.
ALWAYS_SKIPPED = (".git", ".godot", "build", ".claude", "reports", "__pycache__")

_FUNC_RE = re.compile(r"^(\s*)(?:static\s+)?func\s+(\w+)\s*\(")
_ALLOCATION_RE = re.compile(r"\.new\(|\[\s*\]|\{\s*\}|\bPacked\w+Array\(|\bstr\(|\"\s*%|\bString\(|\.format\(")


_VAR_RE = re.compile(r"^\s*(?:@\w+(?:\([^)]*\))?\s+)*var\s+(\w+)")
_SETTER_INLINE_RE = re.compile(r"^(\s*)set\s*\(\s*\w+\s*\)\s*(?::\s*\w+\s*)?:")
_SETTER_NAMED_RE = re.compile(r"\bvar\s+(\w+)[^\n]*\bset\s*=\s*(\w+)")
_TWEENED_RE = re.compile(r"tween_property\(\s*[\w.]+\s*,\s*[\"^]*\"?\^?\"?(\w+)")


def tweened_properties(sources: list[str]) -> set[str]:
    """Every property name a `tween_property(object, "name", ...)` call animates."""
    names: set[str] = set()
    for source in sources:
        names.update(_TWEENED_RE.findall(source))
    return names


def _body_redraws(lines: list[str], index: int, indent: str) -> bool:
    if "queue_redraw()" in lines[index].split(":", 1)[-1]:
        return True
    for body in lines[index + 1:]:
        if body.strip() and not body.startswith(indent + "\t") and not body.startswith(indent + "    "):
            return False
        if "queue_redraw()" in re.sub(r"\s#.*$", "", body):
            return True
    return False


def redrawing_setters(source: str) -> set[str]:
    """Properties whose setter (inline `set(value):` or `set = _named`) calls queue_redraw()."""
    lines = source.splitlines()
    found: set[str] = set()
    named = {setter: prop for prop, setter in _SETTER_NAMED_RE.findall(source)}
    last_var = ""
    for index, line in enumerate(lines):
        declared = _VAR_RE.match(line)
        if declared:
            last_var = declared.group(1)
        inline = _SETTER_INLINE_RE.match(line)
        header = _FUNC_RE.match(line)
        if inline and last_var and _body_redraws(lines, index, inline.group(1)):
            found.add(last_var)
        elif header and header.group(2) in named and _body_redraws(lines, index, header.group(1)):
            found.add(named[header.group(2)])
    return found


def draw_path_allocations(source: str, tweened: set[str]) -> list[tuple[int, str]]:
    """(line number, line) for each allocating line in `_draw`, when a tweened setter redraws (rule 1b)."""
    if not redrawing_setters(source) & tweened:
        return []
    return hot_path_allocations(source, ("_draw",))


def hot_path_allocations(source: str, functions: tuple[str, ...] = HOT_FUNCTIONS) -> list[tuple[int, str]]:
    """(line number, line) for each allocating line inside the body of one of `functions`."""
    found: list[tuple[int, str]] = []
    inside: str | None = None
    indent = ""
    for number, line in enumerate(source.splitlines(), start=1):
        header = _FUNC_RE.match(line)
        if header:
            inside = header.group(2) if header.group(2) in functions else None
            indent = header.group(1)
            continue
        if inside is None:
            continue
        if line.strip() and not line.startswith(indent + "\t") and not line.startswith(indent + "    "):
            inside = None # the body ended (a line at the function's own indent or less)
            continue
        code = re.sub(r"\s#.*$", "", line)
        if code.lstrip().startswith("#"):
            continue
        if _ALLOCATION_RE.search(code):
            found.append((number, line.strip()))
    return found


def check_hot_paths(root: Path) -> list[str]:
    errors: list[str] = []
    paths = [path for directory in CODE_DIRS if (root / directory).is_dir() for path in sorted((root / directory).rglob("*.gd"))]
    sources = {path: path.read_text(encoding="utf-8") for path in paths}
    tweened = tweened_properties(list(sources.values()))
    for path, source in sources.items():
        for number, line in hot_path_allocations(source):
            errors.append(f"{path.relative_to(root).as_posix()}:{number}: allocates every frame: {line}")
        for number, line in draw_path_allocations(source, tweened):
            errors.append(f"{path.relative_to(root).as_posix()}:{number}: allocates in a _draw a tweened setter redraws: {line}")
    return errors


def check_audio_format(root: Path) -> list[str]:
    assets = root / "assets"
    if not assets.is_dir():
        return []
    return [
        f"{path.relative_to(root).as_posix()}: audio must be OGG"
        for path in sorted(assets.rglob("*"))
        if path.is_file() and path.suffix.lower() in AUDIO_SUFFIXES and path.suffix.lower() != ".ogg"
    ]


def exclude_patterns(root: Path) -> list[str]:
    """The Android preset's exclude_filter patterns (the first one in export_presets.cfg)."""
    presets = root / "export_presets.cfg"
    if not presets.is_file():
        return []
    match = re.search(r'^exclude_filter="([^"]*)"', presets.read_text(encoding="utf-8"), re.MULTILINE)
    return [pattern.strip() for pattern in match.group(1).split(",") if pattern.strip()] if match else []


def shipped_bytes(root: Path) -> int:
    patterns = exclude_patterns(root)
    # Godot never imports or exports a folder holding a .gdignore (marketing/, docs/qa/).
    ignored = [marker.parent.relative_to(root).as_posix() + "/" for marker in root.rglob(".gdignore")]
    total = 0
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        rel = path.relative_to(root).as_posix()
        if rel.split("/")[0] in ALWAYS_SKIPPED or any(fnmatch.fnmatch(rel, pattern) for pattern in patterns):
            continue
        if any(rel.startswith(folder) for folder in ignored):
            continue
        total += path.stat().st_size
    return total


def check_content_budget(root: Path, budget_mb: float = CONTENT_BUDGET_MB) -> list[str]:
    size_mb = shipped_bytes(root) / (1024 * 1024)
    if size_mb > budget_mb:
        return [f"exported files are {size_mb:.1f} MB, over the {budget_mb:.0f} MB content budget"]
    return []


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Static performance checks")
    parser.add_argument("--root", type=Path, default=ROOT)
    args = parser.parse_args(argv)
    errors = check_hot_paths(args.root) + check_audio_format(args.root) + check_content_budget(args.root)
    for error in errors:
        print("ERROR:", error)
    print(f"perf check: {len(errors)} problem(s); exported files {shipped_bytes(args.root) / (1024 * 1024):.1f} MB")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
