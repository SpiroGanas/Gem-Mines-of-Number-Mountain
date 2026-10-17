"""Checks every exported problem must pass whatever the skill (structure, distractors, hints,
visuals). Independent of the GDScript generators; see checkers/__init__.py."""
from __future__ import annotations

REQUIRED_KEYS = (
    "skill_id", "seed", "representation", "prompt_line_id", "prompt_params", "answer",
    "answer_modes", "distractors", "visual", "hint_steps", "params", "meta",
)
HINT_KINDS = ("repeat_highlight", "visual_model", "worked_example", "easier_problem")
VISUAL_TYPES = ("gem_piles", "ten_frame", "number_line", "balance", "array", "groups", "pairs")
TILTS = ("unknown", "level", "left", "right")


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
    errors += check_input_meta(problem)
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
        second = visual.get("second", 0)
        if visual["count"] < 0 or second < 0 or visual["count"] + second > 10 * visual["frames"]:
            errors.append(f"{where}: count {visual['count']} + {second} does not fit {visual['frames']} frame(s)")
    elif kind == "number_line":
        low, high = visual["min"], visual["max"]
        if low >= high:
            errors.append(f"{where}: min must be below max")
        for value in visual["markers"] + visual["blanks"]:
            if not low <= value <= high:
                errors.append(f"{where}: value {value} is off the line {low}..{high}")
        if visual["labeled_every"] < 1:
            errors.append(f"{where}: labeled_every must be at least 1")
        for jump in visual.get("jumps", []):
            for end in ("from", "to"):
                if not is_int(jump.get(end)) or not low <= jump[end] <= high:
                    errors.append(f"{where}: jump {end} {jump.get(end)!r} is off the line {low}..{high}")
    elif kind == "balance":
        totals = []
        for side in ("left", "right"):
            terms = visual.get(side)
            if not isinstance(terms, list) or not 1 <= len(terms) <= 3 or not all(is_int(t) and t >= 0 for t in terms):
                return errors + [f"{where}: the {side} pan needs 1 to 3 whole numbers, got {terms!r}"]
            totals.append(sum(terms))
        tilt = visual.get("tilt")
        if tilt not in TILTS:
            errors.append(f"{where}: unknown tilt {tilt!r}")
        elif tilt != "unknown":
            expected = "level" if totals[0] == totals[1] else ("left" if totals[0] > totals[1] else "right")
            if tilt != expected:
                errors.append(f"{where}: pans of {totals[0]} and {totals[1]} should tilt {expected}, not {tilt}")
    elif kind == "array":
        for key in ("rows", "cols"):
            if not is_int(visual.get(key)) or not 1 <= visual[key] <= 10:
                errors.append(f"{where}: array {key} must be 1 to 10")
    elif kind == "groups":
        for key in ("groups", "size"):
            if not is_int(visual.get(key)) or not 1 <= visual[key] <= 10:
                errors.append(f"{where}: {key} must be 1 to 10")
    elif kind == "pairs":
        if not is_int(visual.get("count")) or not 0 <= visual["count"] <= 40:
            errors.append(f"{where}: pairs count must be 0 to 40")
    return errors


def label_key(value: object) -> str:
    """The key an answer value has in meta.label_lines (see Problem.label_key in GDScript)."""
    if isinstance(value, bool):
        return "true" if value else "false"
    return str(value)


def sort_key(value: object) -> tuple:
    """Numbers before text, each in natural order: the order of an unordered tile answer."""
    return (0, value, "") if is_int(value) else (1, 0, str(value))


def check_input_meta(problem: dict) -> list[str]:
    """The meta keys that pick the answer input must agree with the answer and distractors."""
    errors: list[str] = []
    meta = problem["meta"]
    values = [problem["answer"]] + [entry["value"] for entry in problem["distractors"]]
    board = meta.get("tile_board")
    if board is not None:
        tiles, slots = board.get("tiles", []), board.get("slots")
        if not is_int(slots) or not slots <= len(tiles) <= 8:
            errors.append(f"tile board: {len(tiles)} tiles for {slots} slots (needs slots..8)")
        if len(tiles) != len({repr(t) for t in tiles}):
            errors.append("tile board: a tile is listed twice")
        for value in values:
            if not isinstance(value, list) or len(value) != slots:
                errors.append(f"tile board: {value!r} must fill exactly {slots} slots")
                continue
            spare = list(tiles)
            for item in value:
                if item in spare:
                    spare.remove(item)
                else:
                    errors.append(f"tile board: {value!r} needs a tile {item!r} that is not on the board")
            if not board.get("ordered", True) and value != sorted(value, key=sort_key):
                errors.append(f"tile board: unordered answer {value!r} is not sorted")
    builder = meta.get("array_builder")
    if builder is not None:
        for value in values:
            if not isinstance(value, dict) or set(value) != {"rows", "cols"}:
                errors.append(f"array builder: {value!r} must be {{rows, cols}}")
            elif not (1 <= value["rows"] <= builder["max_rows"] and 1 <= value["cols"] <= builder["max_cols"]):
                errors.append(f"array builder: {value!r} does not fit {builder['max_rows']}x{builder['max_cols']}")
    labels = meta.get("label_lines")
    if labels is not None:
        for value in values:
            if label_key(value) not in labels:
                errors.append(f"no label line for answer {label_key(value)!r}")
    return errors
