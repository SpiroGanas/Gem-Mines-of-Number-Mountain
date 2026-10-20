"""Independent re-derivation of the NegativeGenerator problems (Zone 7 skills negative.depth.*).

The depth gauge is a number line with 0 at the mountain's base: up is plus, down is minus. Moves
are re-done by stepping one meter at a time; "greater" means higher on the gauge."""
from __future__ import annotations

from .common import is_int


def by_name(problem: dict) -> dict[str, object]:
    return {entry["misconception"]: entry["value"] for entry in problem["distractors"]}


def levels(params: dict) -> tuple[int, int]:
    """The authored lowest and highest levels (the gauge's full range at difficulty 0)."""
    if "range" in params:
        return params["range"][0], params["range"][1]
    return params.get("min_depth", -30), -params.get("min_depth", -30)


def check(problem: dict) -> list[str]:
    mode = problem["params"].get("mode")
    checker = {"read": _read, "compare": _compare, "move": _move}.get(mode)
    if checker is None:
        return [f"unknown depth mode {mode!r}"]
    errors = checker(problem)
    if not is_int(problem["answer"]):
        errors.append("a depth answer is a whole number")
    gauge = problem["hint_steps"][1]["visual"]
    if gauge.get("type") != "depth_gauge" or gauge["min"] % 10 or gauge["max"] % 10 or gauge["labeled_every"] != 5:
        errors.append("the rung 2 model should be a depth gauge from a multiple of 10 to a multiple of 10, labeled every 5")
    return errors


def _read(problem: dict) -> list[str]:
    depth = problem["answer"]
    low, high = levels(problem["params"])
    errors = []
    if depth == 0 or not low <= depth <= high:
        errors.append(f"the cab at {depth} is off the gauge or at zero")
    if problem["meta"].get("signed") is not True:
        errors.append("a depth answer needs the minus key (meta.signed)")
    if problem["visual"].get("markers") != [depth] or not problem["visual"]["min"] < 0 < problem["visual"]["max"]:
        errors.append("the gauge should mark the cab")
    got = by_name(problem)
    if got.get("dropped_sign") != -depth:
        errors.append(f"dropped_sign should be {-depth}")
    if abs(got.get("off_by_one", depth) - depth) != 1:
        errors.append("off_by_one should be one mark away")
    q = problem["hint_steps"][2]["example"]
    params = q["answer_params"]
    below = q["answer"] < 0
    if q["answer_line_id"] != ("z7.hint.example_depth_below" if below else "z7.hint.example_depth_above") or params["d"] != q["answer"] or params["m"] != abs(q["answer"]):
        errors.append("the worked example does not read its own depth")
    return errors


def _compare(problem: dict) -> list[str]:
    a, b = problem["prompt_params"]["a"], problem["prompt_params"]["b"]
    low, high = levels(problem["params"])
    errors = []
    greater, lower = (a, b) if a > b else (b, a)
    if a == b or not (low <= lower and greater <= high):
        errors.append(f"{a} and {b} are equal or off the gauge")
    if problem["answer"] != greater:
        errors.append(f"{greater} is higher on the gauge than {lower}, but the answer is {problem['answer']}")
    if not abs(lower) > abs(greater):
        errors.append(f"{lower} should be farther from zero than {greater} (the trap)")
    if by_name(problem) != {"bigger_magnitude_bigger": lower}:
        errors.append(f"the wrong answer should be {lower}, named bigger_magnitude_bigger")
    if sorted(problem["hint_steps"][1]["visual"]["markers"]) != sorted([a, b]):
        errors.append("the gauge should mark both numbers")
    params = problem["hint_steps"][2]["example"]["answer_params"]
    if not params["a"] > params["b"]:
        errors.append("the worked example should name the greater number first")
    return errors


def _move(problem: dict) -> list[str]:
    s, t = problem["prompt_params"]["s"], problem["prompt_params"]["t"]
    down = problem["prompt_line_id"] == "z7.depth.prompt_down"
    low, high = levels(problem["params"])
    errors = []
    if problem["prompt_line_id"] not in ("z7.depth.prompt_down", "z7.depth.prompt_up"):
        errors.append("the prompt should move the cab up or down")
    at = s
    for _ in range(t):
        at += -1 if down else 1
    if problem["answer"] != at:
        errors.append(f"from {s}, {'down' if down else 'up'} {t} is {at}, not {problem['answer']}")
    if not (low <= s <= high and low <= at <= high and 1 <= t <= problem["params"].get("step", 15)):
        errors.append(f"the trip {s} -> {at} leaves the gauge or the step is out of range")
    wanted = {"wrong_direction": s + t if down else s - t}
    if at != 0 and -at != wanted["wrong_direction"]:  # one button per number
        wanted["dropped_sign"] = -at
    if by_name(problem) != wanted:
        errors.append(f"the wrong answers should be {wanted}, got {by_name(problem)}")
    ride = problem["meta"].get("depth_gauge")
    if problem["representation"] == "pictorial":
        if ride is None or ride["start"] != s or not ride["min"] <= at <= ride["max"]:
            errors.append("the cab ride should start at s and reach the answer")
    elif ride is not None:
        errors.append("only pictorial problems ride the cab")
    jumps = problem["hint_steps"][1]["visual"].get("jumps")
    if jumps != [{"from": s, "to": at}]:
        errors.append("the rung 2 model should show the trip as a jump")
    q = problem["hint_steps"][2]["example"]["answer_params"]
    went_down = problem["hint_steps"][2]["example"]["answer_line_id"] == "z7.hint.example_move_down"
    if q["e"] != q["s"] + (-q["t"] if went_down else q["t"]):
        errors.append("the worked example's trip is wrong")
    return errors
