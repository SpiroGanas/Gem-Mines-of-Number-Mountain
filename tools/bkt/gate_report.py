#!/usr/bin/env python3
"""The decision-gate numbers from a parent-exported progress bundle (offline; Sprints 12-14).

The MVP decision gate (Friday Feb 19, 2027) asks four questions. Two of them are numbers the play
log can answer; this prints them as Markdown ready to paste into docs/decisions.md:

  * does he play on at least 3 days a week?         days played per week, from attempts.jsonl
  * is his mastered-skill count rising?              mastered skills by week, from the profile
  * (Sprint 12 tuning) which skills sit at a ceiling or a floor?   first-try accuracy per skill
  * (Sprint 13/14 handwriting) how often did Bolt have to ask?    answers by input and "Try again"s

"Does Charlie ask to play?" and "Is the MVP pace fast enough?" are Spiro's own observations: the
report lists them as open questions rather than guessing.

    python tools/bkt/gate_report.py progress-bundle.json [--utc-offset-minutes -300] [--since 2027-01-29]
"""
from __future__ import annotations

import argparse
import datetime
import json
import sys
from collections import defaultdict
from pathlib import Path

CEILING = 0.95  # first-try accuracy at or above this (with MIN_ATTEMPTS answers) = too easy
FLOOR = 0.40    # at or below this = too hard
MIN_ATTEMPTS = 30
IDLE_CAP_SECONDS = 120


def load_bundle(path: Path) -> tuple[dict, list[dict]]:
    doc = json.loads(path.read_text(encoding="utf-8"))
    if doc.get("format") != "gem-mines-progress":
        raise SystemExit(f"{path} is not a gem-mines-progress bundle")
    return doc.get("profile", {}), [a for a in doc.get("attempts", []) if isinstance(a, dict)]


def _parse(ts: str, offset_minutes: int) -> datetime.datetime | None:
    try:
        return datetime.datetime.strptime(ts.rstrip("Z"), "%Y-%m-%dT%H:%M:%S") + datetime.timedelta(minutes=offset_minutes)
    except ValueError:
        return None


def week_start(day: datetime.date) -> datetime.date:
    return day - datetime.timedelta(days=day.weekday())  # Monday


def days_played_per_week(attempts: list[dict], offset_minutes: int = 0, since: str = "") -> dict[str, int]:
    weeks: dict[str, set] = defaultdict(set)
    for a in attempts:
        when = _parse(str(a.get("ts", "")), offset_minutes)
        if when is None or (since and when.date().isoformat() < since):
            continue
        if a.get("low_confidence_rejected"):
            continue
        weeks[week_start(when.date()).isoformat()].add(when.date().isoformat())
    return {week: len(days) for week, days in sorted(weeks.items())}


def minutes_per_week(attempts: list[dict], offset_minutes: int = 0, since: str = "") -> dict[str, int]:
    """Minutes played per week: each answer adds the time since the previous one in its session, capped."""
    last: dict[str, datetime.datetime] = {}
    seconds: dict[str, float] = defaultdict(float)
    for a in sorted(attempts, key=lambda x: str(x.get("ts", ""))):
        when = _parse(str(a.get("ts", "")), offset_minutes)
        if when is None or (since and when.date().isoformat() < since):
            continue
        session = str(a.get("session_id", ""))
        week = week_start(when.date()).isoformat()
        if session in last:
            seconds[week] += min(max((when - last[session]).total_seconds(), 0.0), IDLE_CAP_SECONDS)
        else:
            seconds[week] += min(float(a.get("latency_ms", 0)) / 1000.0, IDLE_CAP_SECONDS)
        last[session] = when
    return {week: round(s / 60) for week, s in sorted(seconds.items())}


def mastered_by_week(profile: dict, offset_minutes: int = 0) -> dict[str, int]:
    """Cumulative number of skills first mastered by the end of each week that had a mastery."""
    per_week: dict[str, int] = defaultdict(int)
    for record in profile.get("skills", {}).values():
        when = _parse(str(record.get("mastered_at") or ""), offset_minutes)
        if when is not None:
            per_week[week_start(when.date()).isoformat()] += 1
    total, result = 0, {}
    for week in sorted(per_week):
        total += per_week[week]
        result[week] = total
    return result


def ceiling_floor(attempts: list[dict]) -> dict[str, list[dict]]:
    tries: dict[str, list[bool]] = defaultdict(list)
    for a in attempts:
        if int(a.get("hints_used", 0)) == 0 and not a.get("low_confidence_rejected"):
            tries[str(a.get("skill_id", ""))].append(bool(a.get("correct", False)))
    ceiling, floor = [], []
    for skill, results in sorted(tries.items()):
        if len(results) < MIN_ATTEMPTS:
            continue
        accuracy = sum(results) / len(results)
        row = {"skill": skill, "first_tries": len(results), "accuracy": round(accuracy, 3)}
        if accuracy >= CEILING:
            ceiling.append(row)
        elif accuracy <= FLOOR:
            floor.append(row)
    return {"ceiling": ceiling, "floor": floor}


def input_summary(attempts: list[dict]) -> dict[str, dict[str, int]]:
    summary: dict[str, dict[str, int]] = defaultdict(lambda: {"answers": 0, "rejected": 0})
    for a in attempts:
        mode = str(a.get("answer_mode", ""))
        if a.get("low_confidence_rejected"):
            summary[mode]["rejected"] += 1
        else:
            summary[mode]["answers"] += 1
    return dict(summary)


def render(profile: dict, attempts: list[dict], offset_minutes: int = 0, since: str = "") -> str:
    out = ["## MVP decision gate: numbers from the play log", ""]
    weeks = days_played_per_week(attempts, offset_minutes, since)
    minutes = minutes_per_week(attempts, offset_minutes, since)
    out += ["| Week starting (Mon) | Days played | Minutes |", "|---|---|---|"]
    for week in weeks:
        out.append(f"| {week} | {weeks[week]} | {minutes.get(week, 0)} |")
    if not weeks:
        out.append("| (no answers in range) | 0 | 0 |")
    full = [w for w, d in weeks.items() if d >= 3]
    out += ["", f"Weeks with 3 or more days played: {len(full)} of {len(weeks)}.", ""]
    mastered = mastered_by_week(profile, offset_minutes)
    out += ["| Week | Skills mastered so far |", "|---|---|"]
    for week, total in mastered.items():
        out.append(f"| {week} | {total} |")
    if not mastered:
        out.append("| (none yet) | 0 |")
    flags = ceiling_floor(attempts)
    out += ["", f"### Difficulty review (first-try accuracy with {MIN_ATTEMPTS}+ first tries)", ""]
    for name, label in (("ceiling", f"At or above {CEILING:.0%}: too easy, widen the range"), ("floor", f"At or below {FLOOR:.0%}: too hard, ease the range or add a step")):
        out.append(f"**{label}**")
        out += [f"- `{r['skill']}`: {r['accuracy']:.0%} of {r['first_tries']} first tries" for r in flags[name]] or ["- none"]
        out.append("")
    out += ["### Answers by input", "", "| Input | Answers | Rejected readings (\"Try again\") |", "|---|---|---|"]
    for mode, row in sorted(input_summary(attempts).items()):
        out.append(f"| {mode or '(unknown)'} | {row['answers']} | {row['rejected']} |")
    out += ["", "### Questions only Spiro can answer", "",
            "- Does Charlie ask to play? (yes / sometimes / no)",
            "- Is the MVP pace fast enough for Sprints 12-52 at the same speed?",
            "- Decision: continue as planned / adjust / pause / stop", ""]
    return "\n".join(out)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("bundle", type=Path)
    ap.add_argument("--utc-offset-minutes", type=int, default=0, help="local time minus UTC, e.g. -300 for US Eastern in winter")
    ap.add_argument("--since", default="", help="first day to count, YYYY-MM-DD (e.g. the MVP release day)")
    args = ap.parse_args(argv)
    profile, attempts = load_bundle(args.bundle)
    print(render(profile, attempts, args.utc_offset_minutes, args.since))
    return 0


if __name__ == "__main__":
    sys.exit(main())
