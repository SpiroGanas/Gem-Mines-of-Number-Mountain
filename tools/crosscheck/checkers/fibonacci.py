"""Independent re-derivation of the FibGenerator problems (Zone 9 skills fib.sequence.* and fib.ratio.*).

Fibonacci numbers are rebuilt with a loop (F(1) = F(2) = 1). Ratios are exact fractions.Fraction values
rounded half up by hand (floor(x + 1/2)); Python's round() rounds a tie to even, so it is never used,
and nothing goes through a float."""
from __future__ import annotations

import math
from fractions import Fraction

from .common import exact_value

KEYS = ("a", "b", "c", "d", "e")


def fibonacci(count: int) -> list[int]:
    """F(1) to F(count)."""
    numbers = [1, 1]
    while len(numbers) < count:
        numbers.append(numbers[-1] + numbers[-2])
    return numbers[:count]


FIB = fibonacci(40)


def half_up(value: Fraction) -> int:
    return math.floor(value + Fraction(1, 2))


def by_name(problem: dict) -> dict[str, list]:
    named: dict[str, list] = {}
    for entry in problem["distractors"]:
        named.setdefault(entry["misconception"], []).append(entry["value"])
    return named


def run_index(terms: list) -> int | None:
    """The index i (1-based) with F(i), F(i + 1), ... matching the known terms (None for a gap)."""
    for start in range(1, len(FIB) - len(terms)):
        if all(t is None or t == FIB[start - 1 + k] for k, t in enumerate(terms)):
            return start
    return None


def check(problem: dict) -> list[str]:
    mode = problem["params"].get("mode")
    checker = {"next": _next, "missing": _missing, "ratio": _ratio}.get(mode)
    if checker is None:
        return [f"unknown Fibonacci mode {mode!r}"]
    return checker(problem)


def _next(problem: dict) -> list[str]:
    p = problem["prompt_params"]
    terms = [p[key] for key in KEYS[:4]]
    start = run_index(terms)
    if start is None:
        return [f"{terms} are not Fibonacci numbers in a row"]
    errors = []
    answer = terms[2] + terms[3]
    if problem["answer"] != answer or start + 4 > problem["params"].get("max_index", 15):
        errors.append(f"after {terms} comes {answer} (by F({problem['params'].get('max_index', 15)})), not {problem['answer']}")
    wanted = {"added_wrong_pair": [terms[1] + terms[3]], "doubled_last": [terms[3] + terms[3]]}
    if by_name(problem) != {name: value for name, value in wanted.items() if value != [answer]}:
        errors.append(f"the wrong answers should be {wanted}, got {by_name(problem)}")
    if problem["representation"] == "concrete" and problem["meta"].get("pattern_wall", {}).get("terms") != terms + [None]:
        errors.append("the concrete problem's wall shows the four terms and a gap")
    q = problem["hint_steps"][2]["example"]["answer_params"]
    if q["e"] != q["c"] + q["d"]:
        errors.append("the worked example's sum is wrong")
    return errors


def _missing(problem: dict) -> list[str]:
    p = problem["prompt_params"]
    terms = [p.get(key) for key in KEYS]
    if terms.count(None) != 1:
        return ["exactly one term is missing"]
    blank = terms.index(None)
    start = run_index(terms)
    errors = []
    if start is None or not 1 <= blank <= 3 or problem["prompt_line_id"] != f"z9.fib.prompt_missing_{blank}":
        return [f"{terms} are not Fibonacci numbers in a row with an inside gap"]
    full = list(terms)
    if blank >= 2:
        full[blank] = full[blank - 1] + full[blank - 2]
    else:
        full[blank] = full[blank + 1] - full[blank - 1]
    if problem["answer"] != full[blank] or start + 4 > problem["params"].get("max_index", 15):
        errors.append(f"the missing number is {full[blank]}, not {problem['answer']}")
    named = by_name(problem)
    if named.get("added_wrong_pair") != [full[blank - 1] + full[blank + 1]]:
        errors.append("added_wrong_pair should add the gap's two neighbors")
    if named.get("doubled_last", [2 * full[blank - 1]]) != [2 * full[blank - 1]]:
        errors.append("doubled_last should double the number before the gap")
    return errors


def _ratio(problem: dict) -> list[str]:
    p = problem["prompt_params"]
    small, big = p["a"], p["b"]
    if small < 2 or small not in FIB or big != FIB[FIB.index(small) + 1]:
        return [f"{big} and {small} are not neighboring Fibonacci numbers"]
    errors = []
    n = FIB.index(small) + 1
    if not 3 <= n <= problem["params"].get("max_index", 12):
        errors.append(f"F({n}) is out of range")
    hundredths = half_up(Fraction(100 * big, small))
    if exact_value(problem["answer"]) != Fraction(hundredths, 100):
        errors.append(f"{big} / {small} to the nearest hundredth is {Fraction(hundredths, 100)}, not {problem['answer']}")
    answer = problem["answer"]
    if answer.get("scale", 0) > 0 and answer["mantissa"] % 10 == 0:
        errors.append("the answer keeps no trailing zero")
    named = {name: [exact_value(v) for v in values] for name, values in by_name(problem).items()}
    wanted = {
        "inverted_ratio": [Fraction(half_up(Fraction(100 * small, big)), 100)],
        "place_shift": [Fraction(hundredths, 10)],
    }
    cut = math.floor(Fraction(100 * big, small))
    if cut != hundredths:
        wanted["rounded_down"] = [Fraction(cut, 100)]
    if named != wanted:
        errors.append(f"the wrong answers should be {wanted}, got {named}")
    if problem["meta"].get("decimal_places") != 2:
        errors.append("the pad takes two places")
    model = problem["hint_steps"][1]["visual"]
    if model.get("type") != "fib_squares" or model["terms"][-1] != big:
        errors.append("the rung 2 model shows Fibonacci squares up to the bigger number")
    q = problem["hint_steps"][2]["example"]["answer_params"]
    if exact_value(q["d"]) != Fraction(half_up(Fraction(100 * q["b"], q["a"])), 100):
        errors.append("the worked example's ratio is wrong")
    return errors
