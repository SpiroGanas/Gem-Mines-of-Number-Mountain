"""Independent re-derivation of the CountingGenerator problems (skills count.*)."""
from __future__ import annotations

from .common import distractors_by_name, pile_total


def swap_last_two_digits(n: int) -> int:
    """34 -> 43, 107 -> 170, 40 -> 4. Done on the decimal string, unlike the generator."""
    text = str(n)
    if len(text) < 2:
        return n
    return int(text[:-2] + text[-1] + text[-2])


def check(problem: dict) -> list[str]:
    mode = problem["params"]["mode"]
    handler = {
        "objects": _objects, "read": _read, "next": _next,
        "between": _between, "strip": _strip, "write": _write,
    }.get(mode)
    if handler is None:
        return [f"unknown counting mode {mode!r}"]
    return handler(problem)


def _objects(problem: dict) -> list[str]:
    errors: list[str] = []
    answer = problem["answer"]
    piles = problem["visual"].get("piles", [])
    if len(piles) != 1 or pile_total(piles[0]) != answer:
        errors.append(f"the gems shown do not add up to the answer {answer}")
    if not problem["params"]["min"] <= answer <= problem["params"]["max"]:
        errors.append(f"answer {answer} is outside the allowed range")
    for name, values in distractors_by_name(problem).items():
        for value in values:
            if name == "off_by_one" and abs(value - answer) != 1:
                errors.append(f"off_by_one value {value} is not within one of {answer}")
            elif name == "double_counted" and value - answer not in (2, 3):
                errors.append(f"double_counted value {value} should be {answer} + 2 or 3")
            elif name not in ("off_by_one", "double_counted"):
                errors.append(f"unexpected misconception {name}")
    model = problem["hint_steps"][1]["visual"]
    if model.get("type") != "ten_frame" or model["count"] != answer:
        errors.append("the rung 2 ten frame does not show the answer count")
    return errors


def _read(problem: dict) -> list[str]:
    errors: list[str] = []
    answer = problem["answer"]
    line = problem["visual"]
    if line.get("markers") != [answer]:
        errors.append(f"the arrow is not on the answer {answer}")
    if line["max"] - line["min"] != 30 or line["min"] % 10 or line["labeled_every"] != 10:
        errors.append("the number line window should be 30 wide, start on a ten and label every ten")
    if not problem["params"]["min"] <= answer <= problem["params"]["max"]:
        errors.append(f"answer {answer} is outside the allowed range")
    if line["max"] > 120:
        errors.append("the line runs past 120")
    for name, values in distractors_by_name(problem).items():
        for value in values:
            if name == "digit_swap" and value != swap_last_two_digits(answer):
                errors.append(f"digit_swap value {value} is not {answer} with its last two digits swapped")
            elif name == "off_by_one" and abs(value - answer) != 1:
                errors.append(f"off_by_one value {value} is not within one of {answer}")
    return errors


def _next(problem: dict) -> list[str]:
    errors: list[str] = []
    first, second = problem["prompt_params"]["a"], problem["prompt_params"]["b"]
    answer = problem["answer"]
    if second != first + 1:
        errors.append(f"the shown numbers {first}, {second} are not consecutive")
    if answer != second + 1:
        errors.append(f"answer {answer} is not the number after {second}")
    if not 1 <= first and answer <= 120:
        errors.append("numbers must stay within 1 to 120")
    for name, values in distractors_by_name(problem).items():
        for value in values:
            if name == "off_by_one" and abs(value - answer) != 1:
                errors.append(f"off_by_one value {value} is not within one of {answer}")
            elif name == "decade_skip":
                expected = answer - 10 if (second % 10 == 9 and answer - 10 >= 1) else answer + 10
                if value != expected:
                    errors.append(f"decade_skip should be {expected}, got {value}")
    return errors


def _between(problem: dict) -> list[str]:
    errors: list[str] = []
    low, high = problem["prompt_params"]["a"], problem["prompt_params"]["b"]
    if high - low != 2:
        errors.append(f"{low} and {high} should be two apart")
    if problem["answer"] != (low + high) // 2 or (low + high) % 2:
        errors.append(f"answer {problem['answer']} is not between {low} and {high}")
    if sorted(problem["distractors"][i]["value"] for i in range(len(problem["distractors"]))) != [low, high]:
        errors.append("the wrong answers should be the two numbers shown")
    return errors


def _strip(problem: dict) -> list[str]:
    errors: list[str] = []
    answer = problem["answer"]
    line = problem["visual"]
    length = problem["params"]["len"]
    if line["max"] - line["min"] + 1 != length or line["labeled_every"] != 1:
        errors.append("the strip should show every number in a run of the right length")
    if answer != sorted(answer) or len(answer) != problem["params"]["blanks"]:
        errors.append(f"the answer {answer} should list the blanks in order")
    if sorted(line["blanks"]) != answer:
        errors.append("the blanks drawn do not match the answer")
    for value in answer:
        if value <= line["min"] or value >= line["max"]:
            errors.append(f"blank {value} is the first or last number of the strip")
    if line["max"] > problem["params"]["max"]:
        errors.append("the strip runs past the allowed maximum")
    for name, values in distractors_by_name(problem).items():
        for value in values:
            if name == "off_by_one" and value != [n + 1 for n in answer]:
                errors.append(f"off_by_one should be {[n + 1 for n in answer]}, got {value}")
            elif name == "decade_skip" and value != [answer[0] + 10] + answer[1:]:
                errors.append(f"decade_skip should move only the first blank by ten, got {value}")
    return errors


def _write(problem: dict) -> list[str]:
    errors: list[str] = []
    answer = problem["answer"]
    if not problem["params"]["min"] <= answer <= problem["params"]["max"]:
        errors.append(f"answer {answer} is outside the allowed range")
    if problem["representation"] == "concrete":
        piles = problem["visual"].get("piles", [])
        if len(piles) != 1 or pile_total(piles[0]) != answer:
            errors.append("the gems shown do not add up to the answer")
    else:
        shown = problem["prompt_params"]["tens"] * 10 + problem["prompt_params"]["ones"]
        if shown != answer or answer > 99:
            errors.append(f"'{problem['prompt_params']}' does not say {answer}")
    for name, values in distractors_by_name(problem).items():
        for value in values:
            if name != "digit_swap" or value != swap_last_two_digits(answer):
                errors.append(f"unexpected distractor {name}={value}")
    return errors
