"""Independent re-derivation of the MultiplicationGenerator problems (skills mult.*).

Totals are found by adding equal groups one at a time (not by the generator's multiplication), and
a fact label such as "5 × 3" is parsed back into its two numbers. For repeated addition the prompt's
text in text/lines.csv is read too, so the number of addends the child sees is checked, not only
the line id."""
from __future__ import annotations

import csv
import re
from functools import lru_cache
from pathlib import Path

from .common import distractors_by_name, is_int

LINES_CSV = Path(__file__).resolve().parents[3] / "text" / "lines.csv"
TIMES = "×"
FACT_RE = re.compile(r"^(\d+) × (\d+)$")
MAX_SIDE = 10


@lru_cache(maxsize=1)
def line_texts() -> dict[str, str]:
    with LINES_CSV.open(encoding="utf-8", newline="") as handle:
        return {row["id"]: row["text"] for row in csv.DictReader(handle)}


def add_groups(groups: int, size: int) -> int:
    """size + size + ... (groups times)."""
    total = 0
    for _ in range(groups):
        total += size
    return total


def parse_fact(label: object) -> tuple[int, int] | None:
    """'5 × 3' -> (5, 3); anything else -> None."""
    match = FACT_RE.match(label) if isinstance(label, str) else None
    return (int(match.group(1)), int(match.group(2))) if match else None


def check(problem: dict) -> list[str]:
    mode = problem["params"]["mode"]
    handler = {"repeated_add": _repeated_add, "equal_groups": _equal_groups,
               "commutative": _commutative, "facts": _facts}.get(mode)
    if handler is None:
        return [f"unknown multiplication mode {mode!r}"]
    return handler(problem)


def _groups_picture(visual: dict) -> tuple[int, int] | None:
    if visual.get("type") != "groups" or set(visual) != {"type", "groups", "size"}:
        return None
    return visual["groups"], visual["size"]


def _example_total_ok(problem: dict) -> bool:
    example = problem["hint_steps"][2]["example"]
    picture = _groups_picture(problem["hint_steps"][2]["visual"])
    if picture is None:
        return False
    groups, size = picture
    return example["answer_line_id"] == "z3.hint.example_groups_total" and example["answer"] == add_groups(groups, size) \
        and example["answer_params"] == {"groups": groups, "size": size, "total": add_groups(groups, size)}


def _repeated_add(problem: dict) -> list[str]:
    errors: list[str] = []
    picture = _groups_picture(problem["visual"])
    if picture is None:
        return [f"the picture should be equal groups, got {problem['visual']!r}"]
    groups, size = picture
    params = problem["params"]
    if not (2 <= groups <= params["max_groups"] and 2 <= size <= params["max_size"]):
        errors.append(f"{groups} groups of {size} is outside the allowed sizes")
    if problem["prompt_params"] != {"n": size}:
        errors.append(f"the prompt should add {size} each time, got {problem['prompt_params']}")
    text = line_texts().get(problem["prompt_line_id"], "")
    if text.count("{n}") != groups or text.count("+") != groups - 1:
        errors.append(f"the prompt {problem['prompt_line_id']!r} does not add {groups} numbers: {text!r}")
    total = add_groups(groups, size)
    if problem["answer"] != total:
        errors.append(f"{groups} groups of {size} make {total}, not {problem['answer']}")
    wrong = distractors_by_name(problem)
    if wrong.get("counted_groups") != [groups]:
        errors.append(f"counted_groups should be the {groups} groups")
    if not wrong.get("off_by_group"):
        errors.append("off_by_group is missing")
    for value in wrong.get("off_by_group", []):
        if value not in (add_groups(groups - 1, size), add_groups(groups + 1, size)):
            errors.append(f"off_by_group {value} is not one group of {size} too few or too many")
    for name in wrong:
        if name not in ("counted_groups", "off_by_group"):
            errors.append(f"unexpected misconception {name}")
    hops = [{"from": add_groups(i, size), "to": add_groups(i + 1, size)} for i in range(groups)]
    expected = {"type": "number_line", "min": 0, "max": total, "labeled_every": size, "markers": [], "blanks": [], "jumps": hops}
    if problem["hint_steps"][1]["visual"] != expected:
        errors.append("the rung 2 model should hop by the group size from 0 to the total")
    if not _example_total_ok(problem):
        errors.append("the worked example does not state its own total")
    return errors


def _equal_groups(problem: dict) -> list[str]:
    errors: list[str] = []
    picture = _groups_picture(problem["visual"])
    if picture is None:
        return [f"the picture should be equal groups, got {problem['visual']!r}"]
    groups, size = picture
    if problem["prompt_line_id"] != "z3.mult.prompt_equal_groups" or problem["prompt_params"] != {"groups": groups, "size": size}:
        errors.append("the prompt should name the groups and size that are shown")
    total = add_groups(groups, size)
    if problem["answer"] != total:
        errors.append(f"{groups} groups of {size} make {total}, not {problem['answer']}")
    if not (groups >= 2 and size >= 2 and total <= problem["params"]["max"]):
        errors.append(f"{groups} groups of {size} is outside the allowed sizes (total at most {problem['params']['max']})")
    wrong = distractors_by_name(problem)
    if wrong.get("counted_groups") != [groups]:
        errors.append(f"counted_groups should be the {groups} groups")
    if groups + size != total and wrong.get("rows_plus_cols") != [groups + size]:
        errors.append(f"rows_plus_cols should be {groups} + {size} = {groups + size}")
    for name in wrong:
        if name not in ("counted_groups", "rows_plus_cols"):
            errors.append(f"unexpected misconception {name}")
    if problem["hint_steps"][1]["visual"] != {"type": "array", "rows": groups, "cols": size, "outline_rows": True}:
        errors.append("the rung 2 model should line the groups up as rows of an array")
    if not _example_total_ok(problem):
        errors.append("the worked example does not state its own total")
    return errors


def _commutative(problem: dict) -> list[str]:
    errors: list[str] = []
    visual = problem["visual"]
    rows, cols = visual.get("rows"), visual.get("cols")
    if visual.get("type") != "array" or set(visual) != {"type", "rows", "cols"} or not is_int(rows) or not is_int(cols):
        return [f"the picture should be a plain array, got {visual!r}"]
    if rows == cols or not (2 <= rows <= 5 and 2 <= cols <= 5):
        errors.append(f"a {rows}x{cols} array should have different sides from 2 to 5")
    if problem["prompt_line_id"] != "z3.mult.prompt_commutative" or problem["prompt_params"] != {"rows": rows, "cols": cols}:
        errors.append("the prompt should name the array's rows and columns")
    shown_total = add_groups(rows, cols)
    answer = parse_fact(problem["answer"])
    if answer != (cols, rows):
        errors.append(f"the answer {problem['answer']!r} should be '{cols} {TIMES} {rows}'")
    elif add_groups(*answer) != shown_total:
        errors.append(f"the answer {problem['answer']!r} does not make {shown_total}")
    totals = [shown_total]
    if len(problem["distractors"]) != 3:
        errors.append(f"there should be three wrong facts, got {len(problem['distractors'])}")
    for entry in problem["distractors"]:
        fact = parse_fact(entry["value"])
        if entry["misconception"] != "rows_cols_swapped_wrong":
            errors.append(f"unexpected misconception {entry['misconception']}")
        if fact is None:
            errors.append(f"{entry['value']!r} is not a fact like '3 {TIMES} 5'")
            continue
        first, second = fact
        swapped_then_changed = (first == cols and abs(second - rows) == 1) or (second == rows and abs(first - cols) == 1)
        if not swapped_then_changed:
            errors.append(f"{entry['value']!r} is not '{cols} {TIMES} {rows}' with one number changed by one")
        total = add_groups(first, second)
        if total in totals:
            errors.append(f"{entry['value']!r} makes {total}, which another option already makes")
        totals.append(total)
    if problem["hint_steps"][1]["visual"] != {"type": "array", "rows": cols, "cols": rows, "outline_rows": True}:
        errors.append("the rung 2 model should be the array turned on its side")
    example = problem["hint_steps"][2]["example"]
    e_rows, e_cols = example["prompt_params"]["rows"], example["prompt_params"]["cols"]
    if parse_fact(example["answer"]) != (e_cols, e_rows) or example["answer_line_id"] != "z3.hint.example_commutative" \
            or example["answer_params"] != {"rows": e_rows, "cols": e_cols, "total": add_groups(e_rows, e_cols)}:
        errors.append("the worked example does not match its own array")
    return errors


def _facts(problem: dict) -> list[str]:
    errors: list[str] = []
    params, meta = problem["params"], problem["meta"]
    a, b = problem["prompt_params"].get("a"), problem["prompt_params"].get("b")
    if problem["prompt_line_id"] != "z3.mult.prompt_fact" or set(problem["prompt_params"]) != {"a", "b"}:
        return ["a fact should use z3.mult.prompt_fact with {a} and {b}"]
    table = meta.get("table")
    if table not in params["tables"]:
        errors.append(f"meta.table {table!r} is not one of the tables {params['tables']}")
    table_first = meta.get("table_first")
    if (a if table_first else b) != table:
        errors.append(f"meta says the table {table} comes {'first' if table_first else 'second'} in {a} {TIMES} {b}")
    other = b if table_first else a
    if not 1 <= other <= params["max_factor"]:
        errors.append(f"the other factor {other} is outside 1..{params['max_factor']}")
    product = add_groups(a, b)
    if problem["answer"] != product:
        errors.append(f"{a} {TIMES} {b} is {product}, not {problem['answer']}")
    if problem["visual"]:
        errors.append("an abstract fact has no picture")
    wrong = distractors_by_name(problem)
    off, tables = wrong.get("off_by_group", []), wrong.get("wrong_table", [])
    if not off or not tables:
        errors.append("a fact needs both an off_by_group and a wrong_table answer")
    for value in off:
        if value not in (product - table, product + table) or value <= 0:
            errors.append(f"off_by_group {value} is not {product} plus or minus one {table}")
    for value in tables:
        if value not in [add_groups(other, t) for t in params["tables"] if t != table]:
            errors.append(f"wrong_table {value} is not {other} times another table's number")
    for name in wrong:
        if name not in ("off_by_group", "wrong_table"):
            errors.append(f"unexpected misconception {name}")
    first_three = {entry["misconception"] for entry in problem["distractors"][:3]}
    if first_three != {"off_by_group", "wrong_table"}:
        errors.append("the three answer buttons should show both kinds of mistake")
    model = problem["hint_steps"][1]["visual"]
    if model != {"type": "groups", "groups": a, "size": b} or not (1 <= a <= MAX_SIDE and 1 <= b <= MAX_SIDE):
        errors.append(f"the rung 2 model should be {a} groups of {b}")
    example = problem["hint_steps"][2]["example"]
    e_a, e_b = example["prompt_params"]["a"], example["prompt_params"]["b"]
    if example["answer"] != add_groups(e_a, e_b) or example["answer_line_id"] != "z3.hint.example_fact" \
            or example["answer_params"] != {"a": e_a, "b": e_b, "product": add_groups(e_a, e_b)}:
        errors.append("the worked example does not state its own product")
    return errors
