"""Independent re-derivation of the MultFactsGenerator problems (skills mult.facts.0_5, 6_10, mixed).

A product is found by adding a copy of b, a times; a swapped-digit answer is the product's text
reversed. The checker knows the allowed range of each factor from the skill's own params and the
rule that zero is drawn only in abstract problems, and re-derives every wrong answer's rule."""
from __future__ import annotations

from .common import distractors_by_name, is_int
from .numbers import array_picture, hops, number_line, product

PROMPT = "z4.mult.prompt_fact"
EXAMPLE_LINE = "z3.hint.example_fact"
MAX_SIDE = 10
NAMES = ("off_by_group", "added_factors", "digit_swap")


def check(problem: dict) -> list[str]:
    errors: list[str] = []
    params, meta = problem["params"], problem["meta"]
    if problem["prompt_line_id"] != PROMPT or set(problem["prompt_params"]) != {"a", "b"}:
        return [f"a fact should use {PROMPT} with {{a}} and {{b}}"]
    a, b = problem["prompt_params"]["a"], problem["prompt_params"]["b"]
    answer = product(a, b)
    if problem["answer"] != answer:
        errors.append(f"{a} x {b} is {answer}, not {problem['answer']}")

    representation = problem["representation"]
    lowest = 0 if representation == "abstract" else 1
    table, table_first = meta.get("table"), meta.get("table_first")
    if not isinstance(table_first, bool) or (a if table_first else b) != table:
        errors.append(f"meta says the table {table} comes {'first' if table_first else 'second'} in {a} x {b}")
    other = b if table_first else a
    if not max(params["table_min"], lowest) <= table <= min(params["table_max"], MAX_SIDE):
        errors.append(f"table {table} is outside {params['table_min']}..{params['table_max']}")
    if not max(params["other_min"], lowest) <= other <= min(params["other_max"], MAX_SIDE):
        errors.append(f"the other factor {other} is outside {params['other_min']}..{params['other_max']}")
    if a == 0 and b == 0:
        errors.append("0 x 0 leaves no wrong answer, so it is never asked")
    if representation != "abstract" and (a == 0 or b == 0):
        errors.append("zero can only be asked in an abstract problem (it cannot be drawn)")

    expected_picture = {
        "concrete": lambda: array_picture(a, b),
        "pictorial": lambda: hops(a, b),
        "abstract": lambda: {},
    }[representation]()
    if problem["visual"] != expected_picture:
        errors.append(f"the {representation} picture should be {expected_picture!r}, got {problem['visual']!r}")

    errors += _check_distractors(problem, a, b, answer)

    model = problem["hint_steps"][1]["visual"]
    expected_model = array_picture(a, b, True) if a > 0 and b > 0 else number_line(0, 10, 1, [0])
    if model != expected_model:
        errors.append(f"the rung 2 model should be {expected_model!r}")
    example = problem["hint_steps"][2]["example"]
    e_a, e_b = example["prompt_params"]["a"], example["prompt_params"]["b"]
    e_product = product(e_a, e_b)
    if example["answer"] != e_product or example["answer_line_id"] != EXAMPLE_LINE \
            or example["answer_params"] != {"a": e_a, "b": e_b, "product": e_product}:
        errors.append("the worked example does not state its own product")
    return errors


def _check_distractors(problem: dict, a: int, b: int, answer: int) -> list[str]:
    errors: list[str] = []
    wrong = distractors_by_name(problem)
    if not problem["distractors"]:
        errors.append("a fact needs at least one wrong answer")
    for name in wrong:
        if name not in NAMES:
            errors.append(f"unexpected misconception {name}")
    shown = [entry["value"] for entry in problem["distractors"]]
    for value in shown:
        if not is_int(value) or value < 0:
            errors.append(f"wrong answer {value!r} must be a whole number of at least 0")
    off_values = [answer + a, answer - a, answer + b, answer - b]
    for value in wrong.get("off_by_group", []):
        if value not in off_values:
            errors.append(f"off_by_group {value} is not {answer} plus or minus {a} or {b}")
    if len(wrong.get("off_by_group", [])) > 2:
        errors.append("at most two off_by_group answers are offered")
    for value in wrong.get("added_factors", []):
        if value != a + b:
            errors.append(f"added_factors {value} is not {a} + {b}")
    # The digit swap is the product's two digits the other way round (a product ending in 0 has none).
    swap_valid = answer >= 10 and answer % 10 != 0 and int(str(answer)[::-1]) != answer
    for value in wrong.get("digit_swap", []):
        if not swap_valid or value != int(str(answer)[::-1]):
            errors.append(f"digit_swap {value} is not the digits of {answer} the other way round")
    # Mistakes that are valid are always offered, under their own name or an earlier one with the same value.
    if a + b != answer and a + b not in shown:
        errors.append(f"the answer {a + b} (adding {a} + {b}) is missing")
    if swap_valid and int(str(answer)[::-1]) not in shown:
        errors.append(f"the swapped digits of {answer} are missing")
    if any(value >= 0 and value != answer for value in off_values) and not wrong.get("off_by_group") \
            and not any(value in shown for value in off_values):
        errors.append("a group too many or too few is missing")
    if len(set(map(str, shown))) != len(shown):
        errors.append("duplicate wrong answers")
    return errors
