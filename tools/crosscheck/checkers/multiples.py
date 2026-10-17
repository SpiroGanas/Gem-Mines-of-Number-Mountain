"""Independent re-derivation of the MultiplesGenerator problems (skills mul.*).

Multiples are found by counting up, a yes/no answer by walking the count until it reaches or passes
n, and the first shared multiple by walking both lists."""
from __future__ import annotations

import math

from .common import distractors_by_name
from .numbers import count_up, divisors, first_shared_multiple, greatest_shared_divisor, hops, product

MAX_TILES = 8
MAX_MULTIPLIER = 10
LABELS = {"true": "ui.common.yes", "false": "ui.common.no"}


def check(problem: dict) -> list[str]:
    mode = problem["params"]["mode"]
    handler = {"first_k": _first_k, "check": _check, "common": _common}.get(mode)
    if handler is None:
        return [f"unknown multiples mode {mode!r}"]
    return handler(problem)


def _lands_on(step: int, target: int) -> bool:
    return target in count_up(step, max(target // step, 1) + 1)


# --- first_k ---------------------------------------------------------------------------------


def _first_k(problem: dict) -> list[str]:
    errors: list[str] = []
    params = problem["params"]
    if problem["prompt_line_id"] != "z4.mul.prompt_first_k" or set(problem["prompt_params"]) != {"k", "b"}:
        return ["the prompt should be z4.mul.prompt_first_k with {k} and {b}"]
    k, b = problem["prompt_params"]["k"], problem["prompt_params"]["b"]
    if not params["k_min"] <= k <= params["k_max"] or not params["b_min"] <= b <= params["b_max"]:
        errors.append(f"k = {k} or b = {b} is outside the skill's ranges")
    if problem["answer"] != count_up(b, k):
        errors.append(f"the first {k} multiples of {b} are {count_up(b, k)}, not {problem['answer']}")
    if problem["visual"]:
        errors.append("an abstract list has no picture")
    board = problem["meta"].get("tile_board", {})
    boards = [problem["answer"]] + [entry["value"] for entry in problem["distractors"]]
    on_board = {value for each in boards for value in each}
    if board.get("ordered") is not True or board.get("slots") != k:
        errors.append("the tile board should be ordered with one slot per multiple")
    if set(board.get("tiles", [])) != on_board or len(board.get("tiles", [])) > MAX_TILES:
        errors.append(f"the tiles should be exactly the numbers the answer and wrong boards use (at most {MAX_TILES})")
    wrong = distractors_by_name(problem)
    for name in wrong:
        if name not in ("off_by_b", "factor_not_multiple"):
            errors.append(f"unexpected misconception {name}")
    late = count_up(b, k + 1)[1:]
    early = [0] + count_up(b, k - 1)
    if not wrong.get("off_by_b"):
        errors.append("a list that starts one multiple early or late is always offered")
    for each in wrong.get("off_by_b", []):
        if each not in (late, early):
            errors.append(f"off_by_b {each} should start one multiple late {late} or early {early}")
    factors = divisors(b)
    for each in wrong.get("factor_not_multiple", []):
        if len(factors) < k or each != factors[:k]:
            errors.append(f"factor_not_multiple {each} should be the first {k} factors of {b}")
    for each in boards:
        if len(each) != k:
            errors.append(f"board {each} should fill exactly {k} slots")
    if problem["hint_steps"][1]["visual"] != hops(k, b):
        errors.append(f"the rung 2 model should hop {k} times by {b}")
    example = problem["hint_steps"][2]["example"]
    e_b, e_k = example["prompt_params"]["b"], example["prompt_params"]["k"]
    twice, thrice = count_up(e_b, 3)[1:]
    if example["answer"] != count_up(e_b, e_k) or example["answer_line_id"] != "z4.hint.example_multiples" \
            or example["answer_params"] != {"b": e_b, "m2": twice, "m3": thrice}:
        errors.append("the worked example does not state the first multiples of its own number")
    return errors


# --- check -----------------------------------------------------------------------------------


def _check(problem: dict) -> list[str]:
    errors: list[str] = []
    params = problem["params"]
    if problem["prompt_line_id"] != "z4.mul.prompt_check" or set(problem["prompt_params"]) != {"n", "b"}:
        return ["the prompt should be z4.mul.prompt_check with {n} and {b}"]
    n, b = problem["prompt_params"]["n"], problem["prompt_params"]["b"]
    lands = _lands_on(b, n)
    if problem["answer"] is not lands:
        errors.append(f"{n} {'is' if lands else 'is not'} a multiple of {b}, but the answer is {problem['answer']!r}")
    if not params["b_min"] <= b <= params["b_max"] or n > b * min(params["max_multiplier"], MAX_MULTIPLIER):
        errors.append(f"b = {b} or n = {n} is outside the skill's ranges")
    if problem["meta"].get("label_lines") != LABELS:
        errors.append("the buttons should read Yes and No")

    if lands:
        wanted = "off_by_b" if n == b else "no_check_made"
    elif n < b and b % n == 0:
        wanted = "factor_not_multiple"
    elif n % b != 0 and b % n != 0 and n >= 2:
        wanted = "no_check_made"
    else:
        wanted = "?"
        errors.append(f"{n} is not a multiple of {b}, but it is not a factor of {b} or an 'other' number either")
    if len(problem["distractors"]) != 1 or problem["distractors"][0] != {"value": not lands, "misconception": wanted}:
        errors.append(f"the one wrong answer should be {not lands!r} named {wanted}, got {problem['distractors']!r}")

    line = hops(math.ceil(n / b), b, [n])
    if problem["visual"] != (line if problem["representation"] == "pictorial" else {}):
        errors.append("the picture should be the hop line for pictorial problems and nothing otherwise")
    if problem["hint_steps"][1]["visual"] != line:
        errors.append(f"the rung 2 model should hop by {b} past {n}")
    example = problem["hint_steps"][2]["example"]
    e_n, e_b = example["prompt_params"]["n"], example["prompt_params"]["b"]
    e_lands = _lands_on(e_b, e_n)
    if example["answer"] is not e_lands:
        errors.append("the worked example gives the wrong answer for its own question")
    elif e_lands:
        e_m = next(index for index, value in enumerate(count_up(e_b, e_n), start=1) if value == e_n)
        if example["answer_line_id"] != "z4.hint.example_multiple_yes" or example["answer_params"] != {"b": e_b, "m": e_m, "n": e_n}:
            errors.append("the 'yes' worked example does not state b x m = n")
    elif example["answer_line_id"] != "z4.hint.example_multiple_no" or example["answer_params"] != {"b": e_b, "n": e_n}:
        errors.append("the 'no' worked example does not use the 'not a multiple' line")
    return errors


# --- common ----------------------------------------------------------------------------------


def _common(problem: dict) -> list[str]:
    errors: list[str] = []
    params = problem["params"]
    if problem["prompt_line_id"] != "z4.mul.prompt_common" or set(problem["prompt_params"]) != {"a", "b"}:
        return ["the prompt should be z4.mul.prompt_common with {a} and {b}"]
    a, b = problem["prompt_params"]["a"], problem["prompt_params"]["b"]
    if a == b or not all(params["min"] <= value <= params["max"] for value in (a, b)):
        errors.append(f"{a} and {b} should differ and stay in {params['min']}..{params['max']}")
        return errors
    first = first_shared_multiple(a, b)
    if problem["answer"] != first:
        errors.append(f"the first multiple of both {a} and {b} is {first}, not {problem['answer']}")
    if problem["visual"]:
        errors.append("an abstract question has no picture")
    wrong = distractors_by_name(problem)
    for name in wrong:
        if name not in ("used_the_product", "factor_not_multiple", "off_by_b"):
            errors.append(f"unexpected misconception {name}")
    times = product(a, b)
    if first != times and wrong.get("used_the_product") != [times]:
        errors.append(f"used_the_product should offer {a} x {b} = {times}")
    if first == times and wrong.get("used_the_product"):
        errors.append("the product is the right answer here, so it is not a mistake")
    if wrong.get("factor_not_multiple") != [greatest_shared_divisor(a, b)]:
        errors.append(f"factor_not_multiple should offer the biggest number that goes into both ({greatest_shared_divisor(a, b)})")
    near = [first - a, first - b, first + a, first + b]
    for value in wrong.get("off_by_b", []):
        if value not in near or value <= 0:
            errors.append(f"off_by_b {value} is not a step of {a} or {b} from {first}")
    if len(problem["distractors"]) > 4:
        errors.append("at most four wrong answers are offered")

    marks = count_up(b, first // b)
    expected_model = hops(first // a, a, marks)
    if problem["hint_steps"][1]["visual"] != expected_model:
        errors.append(f"the rung 2 model should hop by {a} to {first} with a marker on every multiple of {b}")
    example = problem["hint_steps"][2]["example"]
    e_a, e_b = example["prompt_params"]["a"], example["prompt_params"]["b"]
    e_first = first_shared_multiple(e_a, e_b)
    if example["answer"] != e_first or example["answer_line_id"] != "z4.hint.example_common" \
            or example["answer_params"] != {"a": e_a, "b": e_b, "m": e_first}:
        errors.append("the worked example does not state its own first shared multiple")
    return errors
