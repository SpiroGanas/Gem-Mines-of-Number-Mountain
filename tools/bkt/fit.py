#!/usr/bin/env python3
"""Fit Bayesian Knowledge Tracing parameters from a parent-exported play log (offline only).

The game never fits anything. A parent exports the progress bundle (gem-mines-progress JSON, or
the raw attempts.jsonl); this script runs expectation-maximization (Baum-Welch on a two-state
hidden Markov model) per skill and writes curriculum/bkt_fitted.json. The game loads that file at
startup and uses a skill's fitted values only when the skill has at least MIN_SAMPLES observations
(autoload/adaptive.gd, scripts/adaptive/adaptive_engine.gd).

Model (same as scripts/adaptive/bkt.gd):
    hidden state   known / not known
    prior          P(known) before the first answer
    learn          P(not known -> known) after each answer; knowing is never forgotten
    guess          P(right | not known)
    slip           P(wrong | known)

Observations are FIRST-TRY answers only (hints_used == 0, not a rejected handwriting reading),
in time order. That is what the game's own BKT update sees too.

A single child gives one short sequence per skill, which cannot pin down four numbers on its own.
So the M-step is MAP: `--prior-strength` pseudo-observations pull each value toward the current
default (curriculum/bkt_defaults.json). With strength 0 it is plain maximum likelihood, which the
tests use on synthetic learners to check that known parameters are recovered.

Usage:
    python tools/bkt/fit.py path/to/bundle.json            # writes curriculum/bkt_fitted.json
    python tools/bkt/fit.py attempts.jsonl --out /tmp/x.json --prior-strength 0
Pure standard library; nothing here ships in the game.
"""
from __future__ import annotations

import argparse
import datetime
import json
import math
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
DEFAULTS_PATH = REPO / "curriculum" / "bkt_defaults.json"
SKILLS_DIR = REPO / "curriculum" / "skills"
FITTED_PATH = REPO / "curriculum" / "bkt_fitted.json"

PARAM_KEYS = ("prior", "learn", "guess", "slip")
# The game reads a skill's fitted values only from this many observations up.
MIN_SAMPLES = 30
# Identifiability bounds (the usual BKT "no degenerate fits" limits).
BOUNDS = {
    "prior": (0.01, 0.99),
    "learn": (0.01, 0.90),
    "guess": (0.01, 0.60),
    "slip": (0.01, 0.30),
}
SCHEMA_VERSION = 1


def clamp_params(p: dict[str, float]) -> dict[str, float]:
    return {k: min(max(p[k], BOUNDS[k][0]), BOUNDS[k][1]) for k in PARAM_KEYS}


# --- Expectation-maximization ------------------------------------------------------------------


def _forward_backward(obs: list[bool], p: dict[str, float]):
    """Scaled forward-backward for one sequence. State 1 = known.

    Returns (gamma, xi01, log_likelihood): gamma[t] = (P(unknown), P(known)) after seeing the
    whole sequence, xi01[t] = P(state t is unknown and t+1 is known).
    """
    n = len(obs)
    prior, learn, guess, slip = p["prior"], p["learn"], p["guess"], p["slip"]

    def emit(correct: bool) -> tuple[float, float]:
        if correct:
            return guess, 1.0 - slip
        return 1.0 - guess, slip

    alpha = []
    scale = []
    e0, e1 = emit(obs[0])
    a0, a1 = (1.0 - prior) * e0, prior * e1
    c = a0 + a1
    scale.append(c)
    alpha.append((a0 / c, a1 / c))
    for t in range(1, n):
        prev0, prev1 = alpha[-1]
        # transition: unknown -> known with `learn`; known stays known
        n0 = prev0 * (1.0 - learn)
        n1 = prev1 + prev0 * learn
        e0, e1 = emit(obs[t])
        a0, a1 = n0 * e0, n1 * e1
        c = a0 + a1
        scale.append(c)
        alpha.append((a0 / c, a1 / c))
    beta = [(1.0, 1.0)] * n
    for t in range(n - 2, -1, -1):
        e0, e1 = emit(obs[t + 1])
        b0n, b1n = beta[t + 1]
        # from unknown: stay (1-learn) or learn; from known: stay
        b0 = ((1.0 - learn) * e0 * b0n + learn * e1 * b1n) / scale[t + 1]
        b1 = (e1 * b1n) / scale[t + 1]
        beta[t] = (b0, b1)
    gamma = []
    for t in range(n):
        g0, g1 = alpha[t][0] * beta[t][0], alpha[t][1] * beta[t][1]
        z = g0 + g1
        gamma.append((g0 / z, g1 / z))
    xi01 = []
    for t in range(n - 1):
        e0, e1 = emit(obs[t + 1])
        x = alpha[t][0] * learn * e1 * beta[t + 1][1] / scale[t + 1]
        xi01.append(x)
    log_likelihood = sum(math.log(c) for c in scale)
    return gamma, xi01, log_likelihood


def _em_run(sequences: list[list[bool]], start: dict[str, float], defaults: dict[str, float],
            strength: float, iterations: int, tolerance: float):
    p = clamp_params(start)
    last_ll = -math.inf
    for _ in range(iterations):
        n_seq = 0.0
        init_known = 0.0
        learn_num = learn_den = 0.0
        guess_num = guess_den = 0.0
        slip_num = slip_den = 0.0
        total_ll = 0.0
        for obs in sequences:
            if not obs:
                continue
            gamma, xi01, ll = _forward_backward(obs, p)
            total_ll += ll
            n_seq += 1.0
            init_known += gamma[0][1]
            for t, x in enumerate(obs):
                g0, g1 = gamma[t]
                if x:
                    guess_num += g0
                else:
                    slip_num += g1
                guess_den += g0
                slip_den += g1
            for t in range(len(obs) - 1):
                learn_num += xi01[t]
                learn_den += gamma[t][0]
        if n_seq == 0:
            return p, -math.inf
        # MAP: `strength` pseudo-observations at the default value for every parameter.
        s = strength
        p = clamp_params({
            "prior": (init_known + s * defaults["prior"]) / (n_seq + s),
            "learn": (learn_num + s * defaults["learn"]) / (learn_den + s) if learn_den + s > 0 else defaults["learn"],
            "guess": (guess_num + s * defaults["guess"]) / (guess_den + s) if guess_den + s > 0 else defaults["guess"],
            "slip": (slip_num + s * defaults["slip"]) / (slip_den + s) if slip_den + s > 0 else defaults["slip"],
        })
        if abs(total_ll - last_ll) < tolerance:
            last_ll = total_ll
            break
        last_ll = total_ll
    return p, last_ll


def fit_sequences(sequences: list[list[bool]], defaults: dict[str, float], prior_strength: float = 5.0,
                  iterations: int = 300, tolerance: float = 1e-7) -> dict:
    """Fits the four parameters to `sequences` (lists of first-try right/wrong, oldest first).

    Runs EM from several starting points and keeps the best log likelihood, so a poor start cannot
    trap the fit in a bad local optimum. Deterministic.
    """
    starts = [dict(defaults)]
    for prior in (0.1, 0.5):
        for guess, slip, learn in ((0.1, 0.05, 0.1), (0.25, 0.1, 0.3), (0.4, 0.15, 0.05)):
            starts.append({"prior": prior, "learn": learn, "guess": guess, "slip": slip})
    best_p, best_ll = None, -math.inf
    for start in starts:
        p, ll = _em_run(sequences, start, defaults, prior_strength, iterations, tolerance)
        if best_p is None or ll > best_ll:
            best_p, best_ll = p, ll
    n = sum(len(s) for s in sequences)
    return {**{k: round(best_p[k], 4) for k in PARAM_KEYS}, "n": n,
            "sequences": sum(1 for s in sequences if s), "log_likelihood": round(best_ll, 3)}


# --- Reading logs ------------------------------------------------------------------------------


def load_attempts(path: Path) -> list[dict]:
    """Attempts from a progress bundle (.json) or an attempts.jsonl file."""
    text = path.read_text(encoding="utf-8")
    stripped = text.lstrip()
    if stripped.startswith("{") and '"format"' in stripped[:200] and "gem-mines-progress" in stripped[:200]:
        bundle = json.loads(text)
        return [a for a in bundle.get("attempts", []) if isinstance(a, dict)]
    attempts = []
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(entry, dict):
            attempts.append(entry)
    return attempts


def first_try_sequences(attempts: list[dict]) -> dict[str, list[bool]]:
    """{skill_id: [right/wrong, ...]} of first tries in time order (the game's BKT evidence)."""
    ordered = sorted(attempts, key=lambda a: str(a.get("ts", "")))
    sequences: dict[str, list[bool]] = {}
    for a in ordered:
        if int(a.get("hints_used", 0)) != 0:
            continue
        if a.get("low_confidence_rejected") or a.get("outcome") == "rejected_recognition":
            continue
        skill = str(a.get("skill_id", ""))
        if not skill:
            continue
        sequences.setdefault(skill, []).append(bool(a.get("correct", False)))
    return sequences


def skill_types(skills_dir: Path = SKILLS_DIR) -> dict[str, str]:
    """{skill_id: bkt_type} from the detailed zone files."""
    types: dict[str, str] = {}
    for path in sorted(skills_dir.glob("z*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        for entry in data.get("skills", []) if isinstance(data, dict) else []:
            if isinstance(entry, dict) and "id" in entry and "generator" in entry:
                types[str(entry["id"])] = str(entry.get("bkt_type", "default"))
    return types


def defaults_for(defaults_file: dict, bkt_type: str) -> dict[str, float]:
    source = defaults_file.get(bkt_type) or defaults_file["default"]
    return {k: float(source[k]) for k in PARAM_KEYS}


def fit_log(attempts: list[dict], defaults_file: dict, types: dict[str, str], prior_strength: float = 5.0) -> dict:
    """Fits every skill with at least one observation. Returns the bkt_fitted.json structure."""
    result = {}
    for skill, seq in sorted(first_try_sequences(attempts).items()):
        base = defaults_for(defaults_file, types.get(skill, "default"))
        fitted = fit_sequences([seq], base, prior_strength)
        fitted["right"] = sum(seq)
        result[skill] = fitted
    return result


def report(fitted: dict) -> str:
    lines = [f"{'skill':34} {'n':>5} {'right':>5} {'prior':>6} {'learn':>6} {'guess':>6} {'slip':>6}  used"]
    for skill, f in fitted.items():
        used = "yes" if f["n"] >= MIN_SAMPLES else f"no (<{MIN_SAMPLES})"
        lines.append(f"{skill:34} {f['n']:>5} {f['right']:>5} {f['prior']:>6.3f} {f['learn']:>6.3f} "
                     f"{f['guess']:>6.3f} {f['slip']:>6.3f}  {used}")
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("log", type=Path, help="progress bundle (.json) or attempts.jsonl")
    ap.add_argument("--out", type=Path, default=FITTED_PATH)
    ap.add_argument("--defaults", type=Path, default=DEFAULTS_PATH)
    ap.add_argument("--skills-dir", type=Path, default=SKILLS_DIR)
    ap.add_argument("--prior-strength", type=float, default=5.0,
                    help="pseudo-observations pulling each value toward its default (0 = plain ML)")
    ap.add_argument("--date", default=None, help="fit date to record (default: today)")
    args = ap.parse_args(argv)

    attempts = load_attempts(args.log)
    if not attempts:
        print(f"no attempts found in {args.log}", file=sys.stderr)
        return 2
    defaults_file = json.loads(args.defaults.read_text(encoding="utf-8"))
    fitted = fit_log(attempts, defaults_file, skill_types(args.skills_dir), args.prior_strength)
    out = {
        "schema_version": SCHEMA_VERSION,
        "fit_date": args.date or datetime.date.today().isoformat(),
        "min_samples": MIN_SAMPLES,
        "prior_strength": args.prior_strength,
        "attempts_read": len(attempts),
        "skills": fitted,
    }
    args.out.write_text(json.dumps(out, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(report(fitted))
    print(f"\nwrote {args.out} ({len(fitted)} skills, {sum(1 for f in fitted.values() if f['n'] >= MIN_SAMPLES)} with >= {MIN_SAMPLES} observations)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
