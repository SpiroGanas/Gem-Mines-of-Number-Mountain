"""Independent re-derivation of the ParityGenerator problems (skills parity.even_odd.*).

Even or odd is worked out two ways that do not use the generator's arithmetic: for gems, by pairing
them off one pair at a time and looking at what is left; for a number, by its last decimal digit."""
from __future__ import annotations

from .common import is_int

LABELS = {"even": "ui.answer.even", "odd": "ui.answer.odd"}
EVEN_DIGITS = "02468"


def by_pairing(count: int) -> str:
    """Take gems away two at a time; one left over means odd."""
    left = count
    while left >= 2:
        left -= 2
    return "odd" if left == 1 else "even"


def by_last_digit(n: int) -> str:
    return "even" if str(n)[-1] in EVEN_DIGITS else "odd"


def tens_digit_word(n: int) -> str:
    """What a child who looks at the tens digit instead would say (100's tens digit is 0)."""
    text = str(n)
    return "even" if (text[-2] if len(text) > 1 else "0") in EVEN_DIGITS else "odd"


def check(problem: dict) -> list[str]:
    mode = problem["params"]["mode"]
    handler = {"pairs": _pairs, "last_digit": _last_digit}.get(mode)
    if handler is None:
        return [f"unknown parity mode {mode!r}"]
    errors = handler(problem)
    if problem["meta"].get("label_lines") != LABELS:
        errors.append(f"the answer buttons should read their words from {LABELS}")
    if problem["answer"] not in LABELS:
        errors.append(f"the answer {problem['answer']!r} should be 'even' or 'odd'")
    return errors


def _other(word: str) -> str:
    return "odd" if word == "even" else "even"


def _pairs(problem: dict) -> list[str]:
    errors: list[str] = []
    visual = problem["visual"]
    count = visual.get("count")
    if visual.get("type") != "pairs" or not is_int(count) or visual.get("show_pairs") is not False:
        return [f"the picture should be loose gems (pairs, show_pairs false), got {visual!r}"]
    if not 1 <= count <= problem["params"]["max"]:
        errors.append(f"{count} gems is outside 1..{problem['params']['max']}")
    if problem["prompt_line_id"] != "z3.parity.prompt_pairs" or problem["prompt_params"]:
        errors.append("the pairs question should use z3.parity.prompt_pairs with no parameters")
    if problem["answer"] != by_pairing(count):
        errors.append(f"{count} gems are {by_pairing(count)}, not {problem['answer']}")
    if problem["distractors"] != [{"value": _other(by_pairing(count)), "misconception": "leftover_miscounted"}]:
        errors.append("the only wrong answer should be the other word, named leftover_miscounted")
    if problem["hint_steps"][1]["visual"] != {"type": "pairs", "count": count, "show_pairs": True}:
        errors.append("the rung 2 model should ring the same gems in pairs")
    example = problem["hint_steps"][2]["example"]
    shown = problem["hint_steps"][2]["visual"].get("count")
    if example["answer"] != by_pairing(shown) or example["answer_line_id"] != f"z3.hint.example_pairs_{by_pairing(shown)}" \
            or example["answer_params"] != {"n": shown}:
        errors.append(f"the worked example with {shown} gems states the wrong word")
    return errors


def _last_digit(problem: dict) -> list[str]:
    errors: list[str] = []
    n = problem["prompt_params"].get("n")
    if problem["prompt_line_id"] != "z3.parity.prompt_rule" or set(problem["prompt_params"]) != {"n"}:
        return ["the rule question should use z3.parity.prompt_rule with {n}"]
    if not 10 <= n <= problem["params"]["max"]:
        errors.append(f"{n} is outside 10..{problem['params']['max']}")
    if problem["visual"]:
        errors.append("an abstract question has no picture")
    right = by_last_digit(n)
    if problem["answer"] != right:
        errors.append(f"{n} is {right}, not {problem['answer']}")
    misled = tens_digit_word(n) != right
    name = "used_tens_digit" if misled else "parity_swapped"
    if problem["distractors"] != [{"value": _other(right), "misconception": name}]:
        errors.append(f"the only wrong answer should be {_other(right)!r} named {name} (the tens digit {'misleads' if misled else 'agrees'})")
    if problem["meta"].get("tens_digit_misleads") is not misled:
        errors.append(f"meta.tens_digit_misleads should be {misled}")
    model = problem["hint_steps"][1]["visual"]
    if model.get("type") != "number_line" or model.get("markers") != [n] or model.get("labeled_every") != 2 \
            or model.get("min", 1) % 2 or not model["min"] <= n <= model["max"]:
        errors.append(f"the rung 2 model should mark {n} on a line labeled at the even numbers, got {model!r}")
    example = problem["hint_steps"][2]["example"]
    shown = example["prompt_params"]["n"]
    word = by_last_digit(shown)
    if example["answer"] != word or example["answer_line_id"] != f"z3.hint.example_rule_{word}" \
            or example["answer_params"] != {"n": shown, "digit": int(str(shown)[-1])}:
        errors.append(f"the worked example for {shown} states the wrong word or digit")
    return errors
