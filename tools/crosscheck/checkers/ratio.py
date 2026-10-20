"""Independent re-derivation of the RatioGenerator problems (Zone 7 skills ratio.*).

A ratio {a, b} is checked with math.gcd (lowest terms, copper first) and equal ratios by
cross-multiplying; the alloy recipe is scaled by counting how many whole recipes the copper makes."""
from __future__ import annotations

from math import gcd

from .common import is_int


def lowest(a: int, b: int) -> dict:
    g = gcd(a, b)
    return {"a": a // g, "b": b // g}


def same_ratio(x: dict, y: dict) -> bool:
    return x["a"] * y["b"] == y["a"] * x["b"]


def by_name(problem: dict) -> dict[str, object]:
    return {entry["misconception"]: entry["value"] for entry in problem["distractors"]}


def check(problem: dict) -> list[str]:
    if problem["params"].get("mode") == "scale_up":
        return _scale_up(problem)
    return _part_to_part(problem)


def _part_to_part(problem: dict) -> list[str]:
    a, b = problem["prompt_params"]["a"], problem["prompt_params"]["b"]
    errors = []
    if problem["prompt_line_id"] != "z7.ratio.prompt" or not (1 <= a <= problem["params"].get("max_count", 12) and 1 <= b <= problem["params"].get("max_count", 12)) or a == b:
        errors.append(f"{a} copper and {b} tin is out of range")
    if problem["answer"] != lowest(a, b):
        errors.append(f"{a} copper to {b} tin is {lowest(a, b)}, not {problem['answer']}")
    if problem["params"].get("reduce_share", 0) == 0 and gcd(a, b) != 1:
        errors.append("with reduce_share 0 the counts share no factor")
    wanted = {"part_to_whole": lowest(a, a + b), "inverted_ratio": lowest(b, a)}
    got = by_name(problem)
    if got != wanted:
        errors.append(f"the wrong ratios should be {wanted}, got {got}")
    for value in got.values():
        if same_ratio(value, problem["answer"]):
            errors.append(f"wrong ratio {value} equals the answer")
    picture = problem["visual"]
    groups = gcd(a, b)
    if picture.get("type") != "ore_mix" or (picture["a"], picture["b"]) != (a, b):
        errors.append("the picture should show a copper and b tin")
    if problem["representation"] == "pictorial" and picture.get("groups", 1) != groups:
        errors.append(f"the pictorial ores should be ringed into {groups} groups")
    model = problem["hint_steps"][1]["visual"]
    if (model.get("a"), model.get("b"), model.get("groups", 1)) != (a, b, groups):
        errors.append("the rung 2 model should ring the ores into their equal mixes")
    example = problem["hint_steps"][2]["example"]
    q = example["answer_params"]
    if q["r"] != lowest(q["a"], q["b"]):
        errors.append("the worked example's ratio is wrong")
    return errors


def _scale_up(problem: dict) -> list[str]:
    p = problem["prompt_params"]
    a, b, c = p["a"], p["b"], p["c"]
    errors = []
    if problem["prompt_line_id"] != "z7.alloy.prompt":
        errors.append("the prompt should be z7.alloy.prompt")
    if gcd(a, b) != 1 or a == b:
        errors.append(f"the recipe {a} : {b} should be in lowest terms with two different parts")
    recipes = 0
    copper = 0
    while copper < c:
        copper += a
        recipes += 1
    if copper != c or not 2 <= recipes <= problem["params"].get("max_factor", 6):
        errors.append(f"{c} copper is not a whole number of {a}-copper recipes in range")
    tin = recipes * b
    if not is_int(problem["answer"]) or problem["answer"] != tin:
        errors.append(f"{recipes} recipes need {tin} tin, not {problem['answer']}")
    wanted = {"added_instead_of_scaled": b + c - a, "scaled_one_part": b}
    if by_name(problem) != {name: value for name, value in wanted.items() if value != tin}:
        errors.append(f"the wrong answers should be {wanted}, got {by_name(problem)}")
    mixer = problem["meta"].get("alloy")
    if problem["representation"] == "concrete":
        if mixer is None or (mixer["a"], mixer["b"], mixer["given"]) != (a, b, c) or not mixer["max"] > tin:
            errors.append("the alloy mixer should hold the recipe, the copper and room for the tin")
    elif mixer is not None:
        errors.append("only concrete problems use the alloy mixer")
    model = problem["hint_steps"][1]["visual"]
    if (model.get("type"), model.get("a"), model.get("b"), model.get("groups")) != ("ore_mix", c, tin, recipes):
        errors.append("the rung 2 model should show the copper and tin in equal mixes")
    q = problem["hint_steps"][2]["example"]["answer_params"]
    if q["c"] != q["a"] * q["k"] or q["t"] != q["b"] * q["k"]:
        errors.append("the worked example's scaling is wrong")
    return errors
