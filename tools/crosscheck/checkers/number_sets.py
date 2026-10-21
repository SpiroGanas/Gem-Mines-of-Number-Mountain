"""Independent re-derivation of the NumberSetsGenerator problems (Zone 12, skills sets.*).

A card is classified with exact arithmetic: a fraction is rational by its form and an integer only when the bottom divides
the top; a decimal a / 10^scale is rational and is an integer only when 10^scale divides a; a root is whole exactly when
math.isqrt(a) squared is a, and irrational otherwise (a root of a whole number is rational only if that number is a perfect
square). Nothing here is ported from scripts/generators/number_sets.gd."""
from __future__ import annotations

import math
from fractions import Fraction

from .common import distractor_pairs, filtered

RINGS = ["integer", "rational", "real"]


def ring(card: dict) -> str:
    form, a = card["form"], card["a"]
    if form == "int":
        return "integer"
    if form == "frac":
        return "integer" if Fraction(a, card["b"]).denominator == 1 else "rational"
    if form == "decimal":
        return "integer" if Fraction(a, 10 ** card["scale"]).denominator == 1 else "rational"
    root = math.isqrt(a)
    return "integer" if root * root == a else "real"


def check(problem: dict) -> list[str]:
    mode = problem["params"]["mode"]
    card = problem["visual"]
    errors: list[str] = []
    if card.get("type") != "number_card" or problem["prompt_params"]:
        return ["the question shows a number card and has no numbers in its words"]
    if card["form"] == "frac" and Fraction(card["a"], card["b"]).denominator == 1:
        errors.append("a fraction card never reduces to a whole number")
    if card["form"] == "decimal" and (card["a"] % 10 == 0 or card["scale"] not in (1, 2)):
        errors.append("a decimal card has no trailing zero")
    if card["form"] == "root" and not 2 <= card["a"] <= 99:
        errors.append("a root card is the root of 2 to 99")
    smallest = ring(card)
    answer = problem["answer"]
    if mode == "integer":
        if problem["prompt_line_id"] != "z12.sets.prompt_integer" or answer is not (smallest == "integer"):
            errors.append(f"{card}: integer is {smallest == 'integer'}, not {answer!r}")
        if problem["meta"].get("label_lines") != {"true": "ui.common.yes", "false": "ui.common.no"}:
            errors.append("the buttons read Yes and No")
        if distractor_pairs(problem) != [(distractor_pairs(problem)[0][0], not answer)]:
            errors.append("one wrong answer: the other truth value")
    elif mode == "rational":
        if problem["prompt_line_id"] != "z12.sets.prompt_rational" or answer is not (smallest != "real"):
            errors.append(f"{card}: rational is {smallest != 'real'}, not {answer!r}")
        if distractor_pairs(problem) != [(distractor_pairs(problem)[0][0], not answer)]:
            errors.append("one wrong answer: the other truth value")
    else:
        if problem["prompt_line_id"] != "z12.sets.prompt_real" or answer != smallest:
            errors.append(f"{card}: the smallest ring is {smallest}, not {answer!r}")
        wrong = [(name, ring_name) for name, ring_name in distractor_pairs(problem)]
        if sorted(value for _, value in wrong) != sorted(r for r in RINGS if r != smallest):
            errors.append("the wrong answers are the other two rings")
        if problem["meta"].get("label_lines") != {"integer": "z12.sets.ring_integer", "rational": "z12.sets.ring_rational", "real": "z12.sets.ring_real"}:
            errors.append("the ring buttons read z12.sets.ring_*")
    model = problem["hint_steps"][1]["visual"]
    want = dict(card, rings=True, lit=smallest)
    if model != want:
        errors.append(f"the rung 2 model should be {want}")
    if problem["visual"] != card or "rings" in card:
        errors.append("the question card has no rings")
    return errors
