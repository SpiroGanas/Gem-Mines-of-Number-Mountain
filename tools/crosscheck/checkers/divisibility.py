"""Independent re-derivation of the DivisibilityGenerator problems (skills div.rule.*).

"n is divisible by d" is decided by dealing n gems into d carts one at a time and seeing whether
every cart ends up the same (numbers.share_equally). The rule mistake a wrong yes or no stands for is
worked out from the digits of n, written out from the rule descriptions, not from the generator."""
from __future__ import annotations

from .numbers import digits_of, share_equally

LABELS = {"true": "ui.common.yes", "false": "ui.common.no"}
FOCUS = {2: "last", 5: "last", 10: "last", 4: "last_two", 3: "sum", 9: "sum", 6: "sum_and_last"}


def divisible(n: int, d: int) -> bool:
    return share_equally(n, d) is not None


def expected_mistake(n: int, d: int) -> str:
    last = digits_of(n)[-1]
    if divisible(n, d):
        # A child judging 3 or 9 by the last digit says no when that digit does not share.
        if d in (3, 9) and last != 0 and not divisible(last, d):
            return "last_digit_only_for_3"
        return "no_check_made"
    if d == 10 and last == 5:
        return "mixed_up_5_and_10"
    if d in (3, 9) and last != 0 and divisible(last, d):
        return "last_digit_only_for_3"
    if d == 9 and divisible(n, 3):
        return "three_means_nine"
    if d == 4 and divisible(n, 2):
        return "even_means_div_by_4"
    if d == 6 and divisible(n, 2) != divisible(n, 3):
        return "only_one_rule_for_6"
    return "no_check_made"


def check(problem: dict) -> list[str]:
    errors: list[str] = []
    params = problem["params"]
    prompt = problem["prompt_params"]
    if problem["prompt_line_id"] != "z5.div.prompt" or set(prompt) != {"n", "d"}:
        return ["the prompt should be z5.div.prompt with {n} and {d}"]
    n, d = prompt["n"], prompt["d"]
    if d not in params["divisors"]:
        errors.append(f"d = {d} is not one of {params['divisors']}")
    if not max(params["min"], d + 1) <= n <= params["max"]:
        errors.append(f"n = {n} is outside {max(params['min'], d + 1)}..{params['max']}")
    if problem["answer"] is not divisible(n, d):
        errors.append(f"{n} {'is' if divisible(n, d) else 'is not'} divisible by {d}, but the answer is {problem['answer']!r}")
    if problem["meta"].get("label_lines") != LABELS:
        errors.append("the buttons should read Yes and No")
    wanted = [{"value": not divisible(n, d), "misconception": expected_mistake(n, d)}]
    if problem["distractors"] != wanted:
        errors.append(f"the one wrong answer should be {wanted}, got {problem['distractors']}")
    model = {"type": "digits", "digits": digits_of(n), "focus": FOCUS[d]}
    if problem["hint_steps"][1]["visual"] != model:
        errors.append(f"the rung 2 model should be {model}")
    if problem["representation"] == "pictorial" and problem["visual"] != model:
        errors.append("a pictorial problem shows the digits from the start")
    if problem["representation"] == "abstract" and problem["visual"]:
        errors.append("an abstract problem has no picture")
    example = problem["hint_steps"][2]["example"]
    e_n, e_d = example["prompt_params"]["n"], example["prompt_params"]["d"]
    quotient = len(range(e_d, e_n + 1, e_d))  # how many whole groups of e_d fit in e_n
    if divisible(e_n, e_d):
        good = example["answer_line_id"] == "z5.hint.example_div_yes" and example["answer_params"] == {"n": e_n, "d": e_d, "q": quotient}
    else:
        good = example["answer_line_id"] == "z5.hint.example_div_no" and example["answer_params"] == {"n": e_n, "d": e_d, "q": quotient, "r": e_n - quotient * e_d}
    if not good or example["answer"] is not divisible(e_n, e_d):
        errors.append("the worked example does not explain its own division")
    return errors
