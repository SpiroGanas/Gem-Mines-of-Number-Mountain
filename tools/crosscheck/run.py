#!/usr/bin/env python3
"""Independent cross-check of the problem generators (CLAUDE.md rule 10: math must be correct).

  python tools/crosscheck/run.py --all --n 10000
  python tools/crosscheck/run.py --skill pv.tens_ones.build --n 500 --seed 7

For every skill with a built generator this runs the Godot exporter (export_problems.gd) to
write problems as JSON lines, then re-derives each answer and distractor in Python
(checkers/*.py), written separately from the GDScript. Failures print the skill and seed, so a
bad problem can be reproduced with GeneratorRegistry.make_problem(skill, seed).

Needs the Godot 4.7.2 binary in $GODOT (or $GODOT_BIN, or --godot) and an imported project
(`"$GODOT" --headless --path . --import`). Exit code 0 means every problem passed.
The checkers and the generators share nothing but the exported JSON lines; this runner reads
curriculum/skills only to know which skills exist, what each lists as allowed, and the policy
list of misconception names (never to compute an answer).
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))

from checkers import (  # noqa: E402
    addition,
    arrays,
    balance,
    common,
    compare,
    counting,
    fact_family,
    missing_part,
    multiplication,
    parity,
    place_value,
    regroup,
    skip_count,
    subtraction,
)

CHECKERS = {
    "CountingGenerator": counting.check,
    "CompareGenerator": compare.check,
    "PlaceValueGenerator": place_value.check,
    "RegroupGenerator": regroup.check,
    "FactFamilyGenerator": fact_family.check,
    "MissingPartGenerator": missing_part.check,
    "BalanceGenerator": balance.check,
    "AdditionGenerator": addition.check,
    "SubtractionGenerator": subtraction.check,
    "SkipCountGenerator": skip_count.check,
    "ParityGenerator": parity.check,
    "ArraysGenerator": arrays.check,
    "MultiplicationGenerator": multiplication.check,
}
EXIT_NOT_BUILT = 3
MAX_ERRORS_SHOWN = 10


def load_skills(root: Path = ROOT) -> list[dict]:
    """Every detailed skill record, in curriculum order, with its zone number."""
    skills: list[dict] = []
    for path in sorted((root / "curriculum" / "skills").glob("z*.json")):
        zone = json.loads(path.read_text(encoding="utf-8"))
        if zone["status"] == "detailed":
            skills += [dict(skill, zone=zone["zone"]) for skill in zone["skills"]]
    return skills


def allowed_misconceptions(root: Path = ROOT) -> set[str]:
    data = json.loads((root / "curriculum" / "misconceptions.json").read_text(encoding="utf-8"))
    return set(data["misconceptions"])


def check_problem(problem: dict, skill: dict, allowed: set[str]) -> list[str]:
    """All violations in one exported problem: structure first, then the generator's own math."""
    errors = common.check_structure(problem, skill, allowed)
    if errors and errors[0].startswith("missing keys"):
        return errors
    checker = CHECKERS.get(skill["generator"])
    if checker is None:
        return errors + [f"no independent checker for generator {skill['generator']}"]
    try:
        errors += checker(problem)
    except (KeyError, TypeError, IndexError, ValueError) as exc:  # a malformed export is a failure, not a crash
        errors.append(f"checker could not read the problem: {type(exc).__name__}: {exc}")
    return errors


def export(godot: str, skill_id: str, n: int, seed: int, out: Path) -> int:
    """Runs the Godot exporter; returns its exit code."""
    out.parent.mkdir(parents=True, exist_ok=True)
    command = [
        godot, "--headless", "--path", str(ROOT), "--script", "res://tools/crosscheck/export_problems.gd", "--",
        "--skill", skill_id, "--n", str(n), "--seed", str(seed), "--out", str(out),
    ]
    return subprocess.run(command, capture_output=True, text=True, check=False).returncode


def check_file(path: Path, skill: dict, allowed: set[str]) -> tuple[int, list[str]]:
    """(problems checked, error messages each prefixed with the skill and seed)."""
    count = 0
    messages: list[str] = []
    with path.open(encoding="utf-8") as handle:
        for line in handle:
            problem = json.loads(line)
            count += 1
            for error in check_problem(problem, skill, allowed):
                messages.append(f"{skill['id']} seed {problem.get('seed')}: {error}")
    return count, messages


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[1])
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--all", action="store_true", help="check every skill that has a generator")
    group.add_argument("--skill", help="check one skill id")
    parser.add_argument("--n", type=int, default=10000, help="problems per skill (default 10000)")
    parser.add_argument("--seed", type=int, default=1, help="first seed (default 1)")
    parser.add_argument("--godot", default=os.environ.get("GODOT") or os.environ.get("GODOT_BIN"), help="Godot executable")
    parser.add_argument("--out", type=Path, default=ROOT / "build" / "crosscheck", help="folder for the exported files")
    parser.add_argument("--keep", action="store_true", help="keep the exported .jsonl files")
    args = parser.parse_args(argv)

    if not args.godot:
        print("Set GODOT (or GODOT_BIN, or pass --godot) to the Godot 4.7.2 executable.", file=sys.stderr)
        return 2
    skills = load_skills()
    if args.skill:
        skills = [skill for skill in skills if skill["id"] == args.skill]
        if not skills:
            print(f"unknown or outline-only skill: {args.skill}", file=sys.stderr)
            return 2
    allowed = allowed_misconceptions()
    failed = False
    checked_skills = 0
    for skill in skills:
        path = args.out / f"{skill['id']}.jsonl"
        code = export(args.godot, skill["id"], args.n, args.seed, path)
        if code == EXIT_NOT_BUILT:
            print(f"skip   {skill['id']}: generator not built yet")
            continue
        if code != 0:
            print(f"FAIL   {skill['id']}: the Godot exporter exited with code {code}")
            failed = True
            continue
        count, messages = check_file(path, skill, allowed)
        checked_skills += 1
        if messages:
            failed = True
            print(f"FAIL   {skill['id']}: {len(messages)} problem(s) in {count}")
            for message in messages[:MAX_ERRORS_SHOWN]:
                print("         " + message)
        else:
            print(f"ok     {skill['id']}: {count} problems")
        if not args.keep:
            path.unlink(missing_ok=True)
    print(f"cross-check: {checked_skills} skill(s) checked, {'FAILED' if failed else 'all passed'}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
