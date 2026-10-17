"""Checks every exported problem must pass whatever the skill (structure, distractors, hints,
visuals). Independent of the GDScript generators; see checkers/__init__.py."""
from __future__ import annotations

REQUIRED_KEYS = (
    "skill_id", "seed", "representation", "prompt_line_id", "prompt_params", "answer",
    "answer_modes", "distractors", "visual", "hint_steps", "params", "meta",
)
HINT_KINDS = ("repeat_highlight", "visual_model", "worked_example", "easier_problem")
VISUAL_TYPES = ("gem_piles", "ten_frame", "number_line")


def is_int(value: object) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def pile_total(pile: dict) -> int:
    """Value of one gem pile: hundreds, tens and ones."""
    return pile["hundreds"] * 100 + pile["tens"] * 10 + pile["ones"]


def distractors_by_name(problem: dict) -> dict[str, list]:
    """{misconception name: [values]} in the order given."""
    result: dict[str, list] = {}
    for entry in problem["distractors"]:
        result.setdefault(entry["misconception"], []).append(entry["value"])
    return result


def check_structure(problem: dict, skill: dict, allowed_names: set[str]) -> list[str]:
    errors: list[str] = []
    missing = [key for key in REQUIRED_KEYS if key not in problem]
    if missing:
        return [f"missing keys {missing}"]
    if problem["skill_id"] != skill["id"]:
        errors.append(f"skill_id {problem['skill_id']!r} is not {skill['id']!r}")
    if not is_int(problem["seed"]):
        errors.append("seed is not an integer")
    if problem["representation"] not in skill["representations"]:
        errors.append(f"representation {problem['representation']!r} is not allowed for the skill")
    if problem["answer_modes"] != skill["answer_modes"]:
        errors.append("answer_modes differ from the skill's")
    if not isinstance(problem["prompt_line_id"], str) or not problem["prompt_line_id"]:
        errors.append("prompt_line_id is empty")
    for key, value in problem["prompt_params"].items():
        if not is_int(value):
            errors.append(f"prompt param {key!r} is not a whole number: {value!r}")
    errors += _check_distractors(problem, skill, allowed_names)
    errors += _check_hints(problem)
    errors += check_visual(problem["visual"], "visual")
    return errors


def _check_distractors(problem: dict, skill: dict, allowed_names: set[str]) -> list[str]:
    errors: list[str] = []
    seen: list = []
    for entry in problem["distractors"]:
        if set(entry) != {"value", "misconception"}:
            errors.append(f"malformed distractor {entry!r}")
            continue
        name = entry["misconception"]
        if name not in allowed_names:
            errors.append(f"unknown misconception {name!r}")
        if name not in skill["misconceptions"]:
            errors.append(f"misconception {name!r} is not listed for the skill")
        if entry["value"] == problem["answer"]:
            errors.append(f"distractor equals the answer: {entry['value']!r}")
        if entry["value"] in seen:
            errors.append(f"duplicate distractor value {entry['value']!r}")
        seen.append(entry["value"])
    if "tap" in problem["answer_modes"] and not problem["distractors"]:
        errors.append("a tap problem needs at least one distractor")
    return errors


def _check_hints(problem: dict) -> list[str]:
    errors: list[str] = []
    steps = problem["hint_steps"]
    if [step.get("kind") for step in steps] != list(HINT_KINDS):
        return [f"hint rungs must be {list(HINT_KINDS)}, got {[step.get('kind') for step in steps]}"]
    for number, step in enumerate(steps, start=1):
        if not isinstance(step.get("line_id"), str) or not step["line_id"]:
            errors.append(f"rung {number} has no line_id")
    if not steps[1]["visual"]:
        errors.append("rung 2 has no visual model")
    errors += check_visual(steps[1]["visual"], "rung 2 visual")
    example = steps[2].get("example")
    if not isinstance(example, dict) or not {"prompt_line_id", "prompt_params", "answer", "answer_line_id", "answer_params"} <= set(example):
        errors.append("rung 3 has no complete worked example")
    elif example["prompt_params"] == problem["prompt_params"] and example["prompt_line_id"] == problem["prompt_line_id"] and steps[2]["visual"] == problem["visual"]:
        errors.append("the worked example is the same problem")
    wanted = problem["params"].get("difficulty", 0) - 1
    if steps[3].get("easier_params", {}).get("difficulty") != wanted:
        errors.append(f"rung 4 must set difficulty to {wanted}")
    if steps[0].get("line_id") != problem["prompt_line_id"] or steps[0].get("params") != problem["prompt_params"]:
        errors.append("rung 1 must repeat the prompt with its parameters")
    return errors


def check_visual(visual: dict, where: str) -> list[str]:
    errors: list[str] = []
    if not visual:
        return errors
    kind = visual.get("type")
    if kind not in VISUAL_TYPES:
        return [f"{where}: unknown visual type {kind!r}"]
    if kind == "gem_piles":
        if not visual["piles"]:
            errors.append(f"{where}: no piles")
        for pile in visual["piles"]:
            for key in ("hundreds", "tens", "ones"):
                if not is_int(pile.get(key)) or pile[key] < 0:
                    errors.append(f"{where}: pile {key} must be a whole number of at least 0")
    elif kind == "ten_frame":
        if not 0 <= visual["count"] <= 10 * visual["frames"]:
            errors.append(f"{where}: count {visual['count']} does not fit {visual['frames']} frame(s)")
    elif kind == "number_line":
        low, high = visual["min"], visual["max"]
        if low >= high:
            errors.append(f"{where}: min must be below max")
        for value in visual["markers"] + visual["blanks"]:
            if not low <= value <= high:
                errors.append(f"{where}: value {value} is off the line {low}..{high}")
        if visual["labeled_every"] < 1:
            errors.append(f"{where}: labeled_every must be at least 1")
    return errors
