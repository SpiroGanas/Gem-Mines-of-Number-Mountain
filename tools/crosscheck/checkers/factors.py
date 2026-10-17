"""Independent re-derivation of the FactorsGenerator problems (skills fac.*).

Factors are found by trying every number, a rectangle's gem count by adding, and each kind of wrong
board (or yes/no answer) is checked against the mistake it claims to be."""
from __future__ import annotations

from .common import distractors_by_name
from .numbers import array_picture, count_up, divisors, hops, is_prime, number_line, product

MAX_TILES = 8
MAX_LIST_FACTORS = 7
BUILDER_SIDE = 6
MAX_HOPS = 24
RULER_STEP = 5
BIGGEST_MULTIPLE = 100
LABELS = {"true": "ui.common.yes", "false": "ui.common.no"}


def check(problem: dict) -> list[str]:
    mode = problem["params"]["mode"]
    handler = {"list": _list, "rectangles": _rectangles, "check": _check}.get(mode)
    if handler is None:
        return [f"unknown factors mode {mode!r}"]
    return handler(problem)


def hops_to(size: int, end: int, markers: list[int]) -> dict:
    """Hops of `size` from 0 along a line ending at `end`; a ruler when there would be too many."""
    count = end // size
    if count < 1 or count > MAX_HOPS:
        return number_line(0, end, RULER_STEP, markers)
    return number_line(0, end, size, markers, [(i * size, (i + 1) * size) for i in range(count)])


# --- list ------------------------------------------------------------------------------------


def _list(problem: dict) -> list[str]:
    errors: list[str] = []
    params = problem["params"]
    n = problem["prompt_params"].get("n")
    all_factors = divisors(n)
    k = len(all_factors)
    middle = all_factors[1:-1]
    if problem["prompt_line_id"] != "z4.fac.prompt_list" or problem["prompt_params"] != {"k": k, "n": n}:
        errors.append(f"the prompt should be z4.fac.prompt_list with k = {k} and n = {n}")
    if problem["answer"] != all_factors:
        errors.append(f"the factors of {n} are {all_factors}, not {problem['answer']}")
    if is_prime(n) or not params["min"] <= n <= params["max"] or k > MAX_LIST_FACTORS:
        errors.append(f"{n} is not a composite in {params['min']}..{params['max']} with at most {MAX_LIST_FACTORS} factors")
    if problem["visual"]:
        errors.append("an abstract factor list has no picture")

    board = problem["meta"].get("tile_board", {})
    boards = [problem["answer"]] + [entry["value"] for entry in problem["distractors"]]
    on_board = {value for each in boards for value in each}
    if board.get("ordered") is not False or board.get("slots") != k:
        errors.append("the tile board should be unordered with one slot per factor")
    if set(board.get("tiles", [])) != on_board or len(board.get("tiles", [])) > MAX_TILES:
        errors.append(f"the tiles should be exactly the numbers the answer and wrong boards use (at most {MAX_TILES})")

    wrong = distractors_by_name(problem)
    if not problem["distractors"]:
        errors.append("a factor list needs at least one wrong board")
    for name in wrong:
        if name not in ("missing_one_and_n", "skip_middle_pair", "multiple_not_factor"):
            errors.append(f"unexpected misconception {name}")
    for each in wrong.get("missing_one_and_n", []):
        strangers = [value for value in each if value not in all_factors]
        if 1 in each or n in each or not all(value in each for value in middle) or len(strangers) != 2 or len(each) != k:
            errors.append(f"missing_one_and_n {each} should be the middle factors {middle} and two non-factors")
    for each in wrong.get("skip_middle_pair", []):
        left_out = [value for value in all_factors if value not in each]
        strangers = [value for value in each if value not in all_factors]
        pair_ok = left_out and all(value in middle for value in left_out) and all(n // value in left_out for value in left_out)
        if 1 not in each or n not in each or not pair_ok or len(strangers) != len(left_out) or len(each) != k:
            errors.append(f"skip_middle_pair {each} should leave out a middle pair of {n} and put non-factors in its place")
    for each in wrong.get("multiple_not_factor", []):
        left_out = [value for value in all_factors if value not in each]
        if n * 2 not in each or len(left_out) != 1 or left_out[0] not in middle or len(each) != k:
            errors.append(f"multiple_not_factor {each} should swap one middle factor of {n} for {n * 2}")
    for each in boards:
        if each != sorted(each) or len(set(each)) != len(each):
            errors.append(f"board {each} should be sorted with no repeats")

    f = middle[0]
    if n // f <= 10 and f <= 10:
        expected_model = array_picture(f, n // f, True)
    else:
        expected_model = hops_to(f, n, [n])
    if problem["hint_steps"][1]["visual"] != expected_model:
        errors.append(f"the rung 2 model should show {f} x {n // f}: {expected_model!r}")
    example = problem["hint_steps"][2]["example"]
    e_n = example["prompt_params"]["n"]
    e_factors = divisors(e_n)
    e_a = e_factors[1]
    if example["answer"] != e_factors or example["answer_line_id"] != "z4.hint.example_factors" \
            or example["answer_params"] != {"a": e_a, "b": e_n // e_a, "n": e_n}:
        errors.append("the worked example does not state a factor pair of its own number")
    return errors


# --- rectangles ------------------------------------------------------------------------------


def _rectangles(problem: dict) -> list[str]:
    errors: list[str] = []
    params = problem["params"]
    rows, total = problem["prompt_params"].get("rows"), problem["prompt_params"].get("n")
    answer = problem["answer"]
    if problem["prompt_line_id"] != "z4.fac.prompt_rectangle" or set(problem["prompt_params"]) != {"rows", "n"}:
        return ["a rectangle problem should use z4.fac.prompt_rectangle with {rows} and {n}"]
    if set(answer) != {"rows", "cols"} or answer["rows"] != rows:
        return [f"the answer {answer!r} should keep the prompt's {rows} rows"]
    cols = answer["cols"]
    if product(rows, cols) != total:
        errors.append(f"{rows} rows of {cols} make {product(rows, cols)}, not {total}")
    side = min(params["max_side"], BUILDER_SIDE)
    if not 2 <= rows <= side or not 1 <= cols <= side:
        errors.append(f"{rows} x {cols} is outside the sides 2..{side} by 1..{side}")
    if problem["meta"].get("array_builder") != {"max_rows": BUILDER_SIDE, "max_cols": BUILDER_SIDE}:
        errors.append("the builder should be 6 by 6")
    if problem["visual"]:
        errors.append("the builder is the picture, so the problem draws none")
    wrong = distractors_by_name(problem)
    if not problem["distractors"]:
        errors.append("a rectangle problem needs at least one wrong rectangle")
    for name in wrong:
        if name not in ("rows_cols_swapped", "off_by_one"):
            errors.append(f"unexpected misconception {name}")
    swapped = wrong.get("rows_cols_swapped", [])
    if rows != cols and swapped != [{"rows": cols, "cols": rows}]:
        errors.append(f"rows_cols_swapped should offer {cols} rows of {rows}")
    if rows == cols and swapped:
        errors.append("a square turned on its side is the same square")
    near = sorted(wrong.get("off_by_one", []), key=lambda each: each["cols"])
    wanted = [{"rows": rows, "cols": value} for value in (cols - 1, cols + 1) if 1 <= value <= BUILDER_SIDE]
    if near != wanted:
        errors.append(f"off_by_one should offer {wanted}, got {near}")
    if problem["hint_steps"][1]["visual"] != array_picture(rows, cols, True):
        errors.append(f"the rung 2 model should be {rows} rows of {cols}")
    example = problem["hint_steps"][2]["example"]
    e_rows, e_cols = example["answer"]["rows"], example["answer"]["cols"]
    if example["answer_line_id"] != "z4.hint.example_rectangle" \
            or example["answer_params"] != {"rows": e_rows, "cols": e_cols, "n": product(e_rows, e_cols)}:
        errors.append("the worked example does not state its own gem count")
    return errors


# --- check -----------------------------------------------------------------------------------


def _check_line(d: int, n: int) -> dict:
    """The hop picture for 'is d a factor of n': hops of d from 0 with a marker on n."""
    if d > n:
        return number_line(0, d, d, [n], [(0, d)])
    return hops_to(d, n, [n])


def _check(problem: dict) -> list[str]:
    errors: list[str] = []
    params = problem["params"]
    if problem["prompt_line_id"] != "z4.fac.prompt_check" or set(problem["prompt_params"]) != {"d", "n"}:
        return ["a factor check should use z4.fac.prompt_check with {d} and {n}"]
    d, n = problem["prompt_params"]["d"], problem["prompt_params"]["n"]
    divides = d in divisors(n)
    if problem["answer"] is not divides:
        errors.append(f"{d} {'is' if divides else 'is not'} a factor of {n}, but the answer is {problem['answer']!r}")
    if not params["min"] <= n <= params["max"]:
        errors.append(f"n = {n} is outside {params['min']}..{params['max']}")
    if problem["meta"].get("label_lines") != LABELS:
        errors.append("the buttons should read Yes and No")
    pictorial = problem["representation"] == "pictorial"
    if pictorial and d == 1:
        errors.append("the pictorial version never asks about 1 (50 hops of 1 is just a ruler)")

    # Which mistake the other button stands for.
    if divides:
        wanted = "missing_one_and_n" if d in (1, n) else "no_check_made"
    elif d > n:
        wanted = "multiple_not_factor"
        if d % n != 0 or d > BIGGEST_MULTIPLE or d > 3 * n:
            errors.append(f"{d} should be 2n or 3n (at most {BIGGEST_MULTIPLE}) when it is bigger than {n}")
    else:
        wanted = "no_check_made"
        if d < 2:
            errors.append("a non-factor smaller than n starts at 2")
    if len(problem["distractors"]) != 1 or problem["distractors"][0] != {"value": not divides, "misconception": wanted}:
        errors.append(f"the one wrong answer should be {not divides!r} named {wanted}, got {problem['distractors']!r}")

    line = _check_line(d, n)
    if problem["visual"] != (line if pictorial else {}):
        errors.append("the picture should be the hop line for pictorial problems and nothing otherwise")
    if problem["hint_steps"][1]["visual"] != line:
        errors.append(f"the rung 2 model should be the hop line {line!r}")
    example = problem["hint_steps"][2]["example"]
    e_d, e_n = example["prompt_params"]["d"], example["prompt_params"]["n"]
    e_divides = e_d in divisors(e_n)
    if example["answer"] is not e_divides:
        errors.append("the worked example gives the wrong answer for its own question")
    elif e_divides:
        k = next(value for value in count_up(e_d, e_n) if value == e_n) // e_d if e_n % e_d == 0 else None
        if example["answer_line_id"] != "z4.hint.example_factor_yes" or example["answer_params"] != {"d": e_d, "k": k, "n": e_n}:
            errors.append("the 'yes' worked example does not state d x k = n")
    elif example["answer_line_id"] != "z4.hint.example_factor_no" or example["answer_params"] != {"d": e_d, "n": e_n}:
        errors.append("the 'no' worked example does not use the 'not a factor' line")
    return errors
