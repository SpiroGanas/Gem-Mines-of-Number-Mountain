"""Independent re-derivation of the SimplifyGenerator problems (Zone 6, skills simplify.*).

Simplest form comes from Python's fractions.Fraction (which always keeps lowest terms) and math.gcd.
Each wrong answer is judged against the mistake it names: the right value but not in lowest terms
(partially_simplified), only the top or first number divided, or written back to front. Every problem
must ask for simplest form (meta.simplest_form), so the shared rules judge 6/9 by its form and keep it
a wrong answer to 2/3. Nothing here is ported from scripts/generators/simplify.gd.
"""
from __future__ import annotations

import math
from fractions import Fraction

from .common import distractors_by_name
from .numbers import divisors


def factor_lists(a: int, b: int) -> dict:
    shared = [d for d in divisors(a) if b % d == 0]
    return {"type": "lists", "kind": "factors", "rows": [{"n": a, "items": divisors(a)}, {"n": b, "items": divisors(b)}], "marked": shared}


def largest_partial(g: int) -> int | None:
    """The largest common factor above 1 and below the GCF, or None when the GCF is prime."""
    inside = [d for d in divisors(g) if 1 < d < g]
    return inside[-1] if inside else None


def check(problem: dict) -> list[str]:
    handler = {"fraction": _fraction, "ratio": _ratio}.get(problem["params"].get("mode"))
    if handler is None:
        return [f"unknown simplify mode {problem['params'].get('mode')!r}"]
    errors: list[str] = []
    if problem["meta"].get("simplest_form") is not True:
        errors.append("a simplest-form question must set meta.simplest_form")
    return errors + handler(problem)


def _expected(wanted: dict, problem: dict) -> list[str]:
    got = distractors_by_name(problem)
    if got != wanted:
        return [f"the wrong answers should be {wanted}, got {got}"]
    return []


def _example(problem: dict, line: str) -> list[str]:
    example = problem["hint_steps"][2]["example"]
    a, b = example["prompt_params"]["a"], example["prompt_params"]["b"]
    g = math.gcd(a, b)
    if example["answer_line_id"] != line or example["answer_params"] != {"g": g, "a": a, "b": b, "c": a // g, "d": b // g}:
        return [f"the worked example should be {line} dividing {a} and {b} by {g}"]
    return []


def _fraction(problem: dict) -> list[str]:
    params = problem["prompt_params"]
    if problem["prompt_line_id"] != "z6.simplify.prompt_fraction" or set(params) != {"a", "b"}:
        return ["the prompt should be z6.simplify.prompt_fraction with {a, b}"]
    a, b = params["a"], params["b"]
    skill = problem["params"]
    errors: list[str] = []
    g = math.gcd(a, b)
    if not (0 < a < b and max(skill["min_den"], 4) <= b <= skill["max_den"]) or g == 1:
        errors.append(f"{a}/{b} should be a fraction below 1 with a bottom in range and a common factor")
    simplest = Fraction(a, b)
    if problem["answer"] != {"num": simplest.numerator, "den": simplest.denominator}:
        errors.append(f"{a}/{b} in simplest form is {simplest}, not {problem['answer']}")
    wanted: dict[str, list] = {}
    part = largest_partial(g)
    if part:
        halfway = {"num": a // part, "den": b // part}
        if Fraction(halfway["num"], halfway["den"]) != simplest or math.gcd(halfway["num"], halfway["den"]) == 1:
            errors.append("partially_simplified should be the same value, not yet in lowest terms")
        wanted["partially_simplified"] = [halfway]
    wanted["divided_numerator_only"] = [{"num": simplest.numerator, "den": b}]
    wanted["swapped_num_den"] = [{"num": simplest.denominator, "den": simplest.numerator}]
    errors += _expected(wanted, problem)
    picture = {"type": "gears", "teeth": [b], "shaded": a} if problem["representation"] == "pictorial" else {}
    if problem["visual"] != picture:
        errors.append("a pictorial problem shows a gear with the bottom number of teeth and the top number shaded")
    if problem["hint_steps"][1]["visual"] != factor_lists(a, b):
        errors.append("the rung 2 model should be both factor lists with the common factors marked")
    return errors + _example(problem, "z6.hint.example_fraction")


def _ratio(problem: dict) -> list[str]:
    params = problem["prompt_params"]
    if problem["prompt_line_id"] != "z6.simplify.prompt_ratio" or set(params) != {"a", "b"}:
        return ["the prompt should be z6.simplify.prompt_ratio with {a, b}"]
    a, b = params["a"], params["b"]
    skill = problem["params"]
    errors: list[str] = []
    g = math.gcd(a, b)
    low = max(skill["min_term"], 2)
    if a == b or g == 1 or not (low <= a <= skill["max_term"] and low <= b <= skill["max_term"]):
        errors.append(f"{a} : {b} should be two different terms in range with a common factor")
    x, y = a // g, b // g
    if problem["answer"] != {"a": x, "b": y} or math.gcd(x, y) != 1 or Fraction(x, y) != Fraction(a, b):
        errors.append(f"{a} : {b} in simplest form is {x} : {y}, not {problem['answer']}")
    wanted: dict[str, list] = {}
    part = largest_partial(g)
    if part:
        wanted["partially_simplified"] = [{"a": a // part, "b": b // part}]
    wanted["inverted_ratio"] = [{"a": y, "b": x}]
    wanted["divided_one_term_only"] = [{"a": x, "b": b}]
    errors += _expected(wanted, problem)
    picture = {"type": "gears", "teeth": [a, b]} if problem["representation"] == "concrete" else {}
    if problem["visual"] != picture:
        errors.append("a concrete problem shows two gears with the ratio's teeth")
    if problem["hint_steps"][1]["visual"] != factor_lists(min(a, b), max(a, b)):
        errors.append("the rung 2 model should be both factor lists, smaller number first")
    return errors + _example(problem, "z6.hint.example_ratio_simplify")
