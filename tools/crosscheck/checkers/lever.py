"""Independent re-derivation of the LeverGenerator problems (Zone 8 lever.counterweight.balance).

A lever balances when weight × distance is the same on both sides. The checker walks the right
weight up from 1 until its moment reaches the left side's (no division), and rebuilds each named
mistake from the three numbers in the prompt."""
from __future__ import annotations

from .common import distractor_pairs, filtered, is_int

MAX_MOMENT = 255


def check(problem: dict) -> list[str]:
    w, d, r = problem["prompt_params"]["w"], problem["prompt_params"]["d"], problem["prompt_params"]["r"]
    params = problem["params"]
    errors = []
    if d == r or d not in params["distances"] or r not in params["distances"]:
        errors.append(f"distances {d} and {r} must differ and come from {params['distances']}")
    left = w * d
    weight = 1
    while weight * r < left:
        weight += 1
    if weight * r != left:
        return errors + [f"no whole weight at {r} balances {w} at {d}"]
    if problem["answer"] != weight:
        errors.append(f"{w} × {d} = {left}, so {weight} at {r} balances, not {problem['answer']}")
    if not (1 <= w <= params["max_weight"] and 1 <= weight <= params["max_weight"] and left <= MAX_MOMENT):
        errors.append(f"the weights {w} and {weight} or the moment {left} are out of range")
    candidates = [("matched_weight_only", w)]
    if w + d - r >= 1:
        candidates.append(("added_distance", w + d - r))
    if (w * r) % d == 0:
        candidates.append(("swapped_distances", w * r // d))
    wanted = filtered(problem["answer"], candidates)
    if distractor_pairs(problem) != wanted:
        errors.append(f"the wrong answers should be {wanted}, got {distractor_pairs(problem)}")
    lever = problem["meta"].get("lever")
    if problem["representation"] == "concrete":
        if lever is None or (lever["left_w"], lever["left_d"], lever["right_d"]) != (w, d, r) or not is_int(lever.get("max")):
            errors.append("a concrete problem is answered on the counterweight lever")
    elif problem["visual"] != {"type": "lever", "left": {"w": w, "d": d}, "right": {"w": 0, "d": r}, "tilt": "unknown"}:
        errors.append("a pictorial problem shows the lever with an empty right hook")
    q = problem["hint_steps"][2]["example"]["answer_params"]
    if q["w"] * q["d"] != q["p"] or q["x"] * q["r"] != q["p"]:
        errors.append("the worked example's lever does not balance")
    return errors
