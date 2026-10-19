"""Independent re-derivation of the GearGenerator problems (Zone 6, skills gear.*).

Gear facts are simulated, not looked up: a gear's turns are counted tooth by tooth as the driver's
teeth pass, and the marked teeth are stepped one tooth at a time until both are back at the meeting
point. math.gcd checks the used_gcf mistake. Nothing here is ported from scripts/generators/gears.gd.
"""
from __future__ import annotations

import math

from .common import distractors_by_name
from .numbers import hops

MAX_TURNS = 12


def turns_while(teeth_passing: int, gear_teeth: int) -> tuple[int, int]:
    """(whole turns, teeth left over) of a gear while `teeth_passing` teeth pass it."""
    turns, at = 0, 0
    for _ in range(teeth_passing):
        at += 1
        if at == gear_teeth:
            turns, at = turns + 1, 0
    return turns, at


def teeth_until_marks_meet(a: int, b: int) -> int:
    passed = 1
    while passed % a or passed % b:
        passed += 1
    return passed


def multiples_up_to(a: int, b: int, upto: int, marked: list[int]) -> dict:
    rows = [{"n": n, "items": list(range(n, upto + 1, n))} for n in (a, b)]
    return {"type": "lists", "kind": "multiples", "rows": rows, "marked": marked}


def check(problem: dict) -> list[str]:
    handler = {"ratio": _ratio, "sync": _sync}.get(problem["params"].get("mode"))
    if handler is None:
        return [f"unknown gear mode {problem['params'].get('mode')!r}"]
    return handler(problem)


def _ratio(problem: dict) -> list[str]:
    params = problem["prompt_params"]
    if problem["prompt_line_id"] != "z6.gear.prompt_ratio" or set(params) != {"a", "k"}:
        return ["the prompt should be z6.gear.prompt_ratio with {a, k}"]
    a, k = params["a"], params["k"]
    skill = problem["params"]
    errors: list[str] = []
    if a not in skill["teeth"] or k not in skill["turns"]:
        errors.append(f"{a} teeth and {k} turns should come from the skill's lists")
    small = problem["answer"]
    if turns_while(a, small) != (k, 0) or small < skill["min_teeth"]:
        errors.append(f"a {small}-tooth gear does not turn exactly {k} times while {a} teeth pass (or is too small)")
    wrong = distractors_by_name(problem)
    expected = {"inverted_ratio": [a * k], "subtracted_teeth": [a - k], "same_size_gear": [a]}
    if wrong != expected:
        errors.append(f"the wrong gears should be {expected}, got {wrong}")
    values = [small] + [entry["value"] for entry in problem["distractors"]]
    if problem["representation"] == "concrete":
        if problem["meta"].get("gear_bench") != {"driver": a, "turns": k, "tray": sorted(values)}:
            errors.append("the concrete problem is the gear bench with every gear in the tray, smallest first")
        if problem["visual"]:
            errors.append("the gear bench is the picture; the problem has no other visual")
    else:
        if "gear_bench" in problem["meta"] or problem["visual"] != {"type": "gears", "teeth": [a]}:
            errors.append("a pictorial problem shows the big gear and uses answer buttons")
    wanted_model = hops(k, small, [a])
    if problem["hint_steps"][1]["visual"] != wanted_model:
        errors.append(f"the rung 2 model should be {k} hops of {small} to {a}")
    example = problem["hint_steps"][2]["example"]
    ea, ek = example["prompt_params"]["a"], example["prompt_params"]["k"]
    if example["answer_line_id"] != "z6.hint.example_ratio" or example["answer_params"] != {"a": ea, "b": ea // ek, "k": ek}:
        errors.append("the worked example should name both gears and the turns")
    return errors


def _sync(problem: dict) -> list[str]:
    params = problem["prompt_params"]
    if problem["prompt_line_id"] != "z6.gear.prompt_sync" or set(params) != {"a", "b"}:
        return ["the prompt should be z6.gear.prompt_sync with {a, b}"]
    a, b = params["a"], params["b"]
    skill = problem["params"]
    errors: list[str] = []
    if a == b or not (skill["min_teeth"] <= a <= skill["max_teeth"] and skill["min_teeth"] <= b <= skill["max_teeth"]):
        errors.append(f"{a} and {b} should be different gears from {skill['min_teeth']} to {skill['max_teeth']} teeth")
    passed = teeth_until_marks_meet(a, b)
    turns_a, left_a = turns_while(passed, a)
    turns_b, left_b = turns_while(passed, b)
    if left_a or left_b or problem["answer"] != turns_a:
        errors.append(f"the marks meet after {passed} teeth, {turns_a} turns of the {a}-tooth gear, not {problem['answer']}")
    if not 2 <= turns_a <= MAX_TURNS or turns_b > MAX_TURNS:
        errors.append(f"both gears should turn at most {MAX_TURNS} times, the first at least twice")
    candidates = [("used_gcf", math.gcd(a, b)), ("counted_other_gear", turns_b), ("teeth_not_turns", passed)]
    wanted: dict[str, list] = {}
    taken = {turns_a}
    for name, value in candidates:
        if value not in taken:
            wanted[name] = [value]
            taken.add(value)
    if distractors_by_name(problem) != wanted:
        errors.append(f"the wrong answers should be {wanted}, got {distractors_by_name(problem)}")
    if problem["visual"] != {"type": "gears", "teeth": [a, b], "marks": True}:
        errors.append("the problem shows both gears with their marks")
    if problem["hint_steps"][1]["visual"] != multiples_up_to(a, b, passed, [passed]):
        errors.append("the rung 2 model should be both lists of multiples up to where the marks meet")
    example = problem["hint_steps"][2]["example"]
    ea, eb = example["prompt_params"]["a"], example["prompt_params"]["b"]
    meet = teeth_until_marks_meet(ea, eb)
    if example["answer_line_id"] != "z6.hint.example_sync" or example["answer_params"] != {"a": ea, "l": meet, "t": meet // ea}:
        errors.append("the worked example should say how many teeth pass and how many turns that is")
    return errors


