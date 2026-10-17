"""Independent re-derivation of the ArraysGenerator problems (skills arr.rows_cols.*).

The number of gems in an array is found by laying it out, one row at a time, rather than by the
generator's multiplication; the wrong answers are rebuilt from the same rows and columns."""
from __future__ import annotations

from .common import distractors_by_name, is_int

MIN_SIDE = 2


def gems_in(rows: int, cols: int) -> int:
    """Count the gems of a rows-by-columns array cell by cell."""
    return len([(row, col) for row in range(rows) for col in range(cols)])


def check(problem: dict) -> list[str]:
    mode = problem["params"]["mode"]
    handler = {"count": _count, "build": _build}.get(mode)
    if handler is None:
        return [f"unknown arrays mode {mode!r}"]
    return handler(problem)


def _sides_ok(rows: object, cols: object, params: dict) -> bool:
    return is_int(rows) and is_int(cols) and MIN_SIDE <= rows <= params["max_rows"] and MIN_SIDE <= cols <= params["max_cols"]


def _count(problem: dict) -> list[str]:
    errors: list[str] = []
    visual = problem["visual"]
    rows, cols = visual.get("rows"), visual.get("cols")
    if visual.get("type") != "array" or set(visual) != {"type", "rows", "cols"}:
        return [f"the picture should be a plain array, got {visual!r}"]
    if not _sides_ok(rows, cols, problem["params"]):
        errors.append(f"a {rows}x{cols} array is outside {MIN_SIDE}..{problem['params']['max_rows']} by {MIN_SIDE}..{problem['params']['max_cols']}")
    if problem["prompt_line_id"] != "z3.arr.prompt_count" or problem["prompt_params"]:
        errors.append("counting an array should use z3.arr.prompt_count with no parameters")
    total = gems_in(rows, cols)
    if problem["answer"] != total:
        errors.append(f"a {rows}x{cols} array holds {total} gems, not {problem['answer']}")
    wrong = distractors_by_name(problem)
    if rows + cols != total and wrong.get("rows_plus_cols") != [rows + cols]:
        errors.append(f"rows_plus_cols should be {rows} + {cols} = {rows + cols}")
    if not wrong.get("off_by_row"):
        errors.append("off_by_row is missing")
    for value in wrong.get("off_by_row", []):
        if value not in (gems_in(rows - 1, cols), gems_in(rows + 1, cols)):
            errors.append(f"off_by_row {value} is not one row of {cols} too few or too many")
    for name in wrong:
        if name not in ("rows_plus_cols", "off_by_row"):
            errors.append(f"unexpected misconception {name}")
    if problem["hint_steps"][1]["visual"] != {"type": "array", "rows": rows, "cols": cols, "outline_rows": True}:
        errors.append("the rung 2 model should be the same array with its rows outlined")
    example = problem["hint_steps"][2]["example"]
    shown = problem["hint_steps"][2]["visual"]
    expected = {"rows": shown.get("rows"), "cols": shown.get("cols"), "total": gems_in(shown.get("rows", 0), shown.get("cols", 0))}
    if example["answer_line_id"] != "z3.hint.example_array_total" or example["answer_params"] != expected \
            or example["answer"] != expected["total"]:
        errors.append("the worked example does not state its own array's total")
    return errors


def _build(problem: dict) -> list[str]:
    errors: list[str] = []
    params = problem["params"]
    asked = problem["prompt_params"]
    rows, cols = asked.get("rows"), asked.get("cols")
    if problem["prompt_line_id"] != "z3.arr.prompt_build" or set(asked) != {"rows", "cols"}:
        return ["building an array should use z3.arr.prompt_build with {rows} and {cols}"]
    if not _sides_ok(rows, cols, params):
        errors.append(f"a {rows}x{cols} array is outside the allowed sizes")
    if rows == cols:
        errors.append(f"rows and columns should differ so a swap is a real mistake ({rows}x{cols})")
    if problem["answer"] != {"rows": rows, "cols": cols}:
        errors.append(f"the answer {problem['answer']} is not the {rows} rows and {cols} columns asked for")
    if problem["visual"]:
        errors.append("a build problem has no picture (the builder is the picture)")
    if problem["meta"].get("array_builder") != {"max_rows": params["max_rows"], "max_cols": params["max_cols"]}:
        errors.append("the array builder should be the skill's full size")
    if problem["distractors"] != [{"value": {"rows": cols, "cols": rows}, "misconception": "rows_cols_swapped"}]:
        errors.append(f"the only wrong answer should be the swapped array {cols}x{rows}")
    if problem["hint_steps"][1]["visual"] != {"type": "array", "rows": rows, "cols": cols, "outline_rows": True}:
        errors.append("the rung 2 model should show the array asked for with its rows outlined")
    example = problem["hint_steps"][2]["example"]
    if example["answer_line_id"] != "z3.hint.example_array_shape" or example["answer_params"] != example["prompt_params"] \
            or example["answer"] != example["prompt_params"]:
        errors.append("the worked example should build exactly the array it asks for")
    return errors
