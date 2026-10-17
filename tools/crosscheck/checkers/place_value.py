"""Independent re-derivation of the PlaceValueGenerator problems (skills pv.tens_ones.*,
pv.tens.ten_more_less, pv.hundred.intro)."""
from __future__ import annotations

from .common import distractors_by_name, pile_total


def check(problem: dict) -> list[str]:
    mode = problem["params"]["mode"]
    handler = {
        "build": _build, "read": _read, "expanded": _expanded, "digit_value": _digit_value,
        "ten_more_less": _ten_more_less, "build_hundred": _build_hundred,
    }.get(mode)
    if handler is None:
        return [f"unknown place value mode {mode!r}"]
    return handler(problem)


def _in_range(problem: dict, n: int) -> list[str]:
    low, high = problem["params"]["min"], problem["params"]["max"]
    return [] if low <= n <= high else [f"number {n} is outside {low}..{high}"]


def _build(problem: dict) -> list[str]:
    n = problem["prompt_params"]["n"]
    tens, ones = divmod(n, 10)
    errors = _in_range(problem, n)
    if problem["answer"] != {"tens": tens, "ones": ones}:
        errors.append(f"{n} is {tens} tens and {ones} ones, got {problem['answer']}")
    wrong = distractors_by_name(problem)
    for name, values in wrong.items():
        for value in values:
            if name == "digit_swap" and value != {"tens": ones, "ones": tens}:
                errors.append(f"digit_swap should be {ones} tens {tens} ones, got {value}")
            elif name == "counted_tens_as_ones" and value != {"tens": 0, "ones": tens + ones}:
                errors.append(f"counted_tens_as_ones should be {tens + ones} ones, got {value}")
            elif name not in ("digit_swap", "counted_tens_as_ones"):
                errors.append(f"unexpected misconception {name}")
    # Anything not a duplicate of the answer must have been offered when its value is distinct.
    if ones != tens and "digit_swap" not in wrong:
        errors.append("digit_swap is missing although the digits differ")
    return errors


def _read(problem: dict) -> list[str]:
    errors: list[str] = []
    n = problem["answer"]
    errors += _in_range(problem, n)
    tens, ones = divmod(n, 10)
    if problem["representation"] == "concrete":
        piles = problem["visual"].get("piles", [])
        if len(piles) != 1 or pile_total(piles[0]) != n:
            errors.append("the gems shown do not add up to the answer")
    elif problem["prompt_params"] != {"tens": tens, "ones": ones}:
        errors.append(f"the words '{problem['prompt_params']}' do not say {n}")
    for name, values in distractors_by_name(problem).items():
        for value in values:
            if name == "digit_swap" and value != ones * 10 + tens:
                errors.append(f"digit_swap should be {ones * 10 + tens}, got {value}")
            elif name == "counted_bars_as_ones" and value != tens + ones:
                errors.append(f"counted_bars_as_ones should be {tens + ones}, got {value}")
            elif name not in ("digit_swap", "counted_bars_as_ones"):
                errors.append(f"unexpected misconception {name}")
    return errors


def _expanded(problem: dict) -> list[str]:
    n = problem["prompt_params"]["n"]
    tens, ones = divmod(n, 10)
    errors = _in_range(problem, n)
    if problem["answer"] != [tens * 10, ones]:
        errors.append(f"{n} = {tens * 10} + {ones}, got {problem['answer']}")
    for name, values in distractors_by_name(problem).items():
        for value in values:
            if name == "digit_value_as_digit" and value != [tens, ones]:
                errors.append(f"digit_value_as_digit should be {[tens, ones]}, got {value}")
            elif name == "digit_swap" and value != [ones * 10, tens]:
                errors.append(f"digit_swap should be {[ones * 10, tens]}, got {value}")
            elif name not in ("digit_value_as_digit", "digit_swap"):
                errors.append(f"unexpected misconception {name}")
    return errors


def _digit_value(problem: dict) -> list[str]:
    n = problem["prompt_params"]["n"]
    tens, ones = divmod(n, 10)
    errors = _in_range(problem, n)
    if tens == ones:
        errors.append(f"{n} has two equal digits, so 'the {tens}' is ambiguous")
    place = problem["meta"].get("place")
    if place == "tens":
        if problem["prompt_params"]["digit"] != tens or problem["answer"] != tens * 10:
            errors.append(f"the {tens} in {n} is worth {tens * 10}, got {problem['answer']}")
    elif place == "ones":
        if ones == 0:
            errors.append("a ones digit of 0 should never be asked about")
        if problem["prompt_params"]["digit"] != ones or problem["answer"] != ones:
            errors.append(f"the {ones} in {n} is worth {ones}, got {problem['answer']}")
    else:
        return errors + [f"unknown place {place!r}"]
    other = ones if place == "tens" else tens * 10
    for name, values in distractors_by_name(problem).items():
        for value in values:
            if name == "digit_value_as_digit" and (place != "tens" or value != tens):
                errors.append(f"unexpected digit_value_as_digit {value}")
            elif name == "wrong_place" and value != other:
                errors.append(f"wrong_place should be the other digit's value {other}, got {value}")
            elif name not in ("digit_value_as_digit", "wrong_place"):
                errors.append(f"unexpected misconception {name}")
    return errors


def _ten_more_less(problem: dict) -> list[str]:
    n = problem["prompt_params"]["n"]
    errors = _in_range(problem, n)
    direction = problem["meta"].get("direction")
    if direction not in ("more", "less"):
        return errors + [f"unknown direction {direction!r}"]
    expected = n + 10 if direction == "more" else n - 10
    if problem["answer"] != expected:
        errors.append(f"ten {direction} than {n} is {expected}, got {problem['answer']}")
    if problem["prompt_line_id"] != f"z1.pv.prompt_ten_{direction}":
        errors.append("the prompt line does not match the direction")
    piles = problem["visual"].get("piles", [])
    if len(piles) != 1 or pile_total(piles[0]) != n:
        errors.append("the gems shown do not add up to the number in the question")
    if not 0 <= expected <= 120:
        errors.append(f"answer {expected} is outside 0 to 120")
    for name, values in distractors_by_name(problem).items():
        for value in values:
            if name == "changed_ones" and value != (n + 1 if direction == "more" else n - 1):
                errors.append(f"changed_ones should change the ones digit by one, got {value}")
            elif name == "off_by_one" and abs(value - expected) != 1:
                errors.append(f"off_by_one value {value} is not within one of {expected}")
            elif name not in ("changed_ones", "off_by_one"):
                errors.append(f"unexpected misconception {name}")
    return errors


def _build_hundred(problem: dict) -> list[str]:
    n = problem["prompt_params"]["n"]
    errors = _in_range(problem, n)
    hundreds, rest = divmod(n, 100)
    tens, ones = divmod(rest, 10)
    if problem["answer"] != {"hundreds": hundreds, "tens": tens, "ones": ones}:
        errors.append(f"{n} is {hundreds} hundred {tens} tens {ones} ones, got {problem['answer']}")
    for name, values in distractors_by_name(problem).items():
        for value in values:
            if name == "counted_tens_as_ones" and value != {"hundreds": hundreds, "tens": 0, "ones": tens + ones}:
                errors.append(f"counted_tens_as_ones wrong: {value}")
            elif name == "digit_swap" and value != {"hundreds": hundreds, "tens": ones, "ones": tens}:
                errors.append(f"digit_swap wrong: {value}")
            elif name not in ("counted_tens_as_ones", "digit_swap"):
                errors.append(f"unexpected misconception {name}")
    return errors
