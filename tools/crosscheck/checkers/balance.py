"""Independent re-derivation of the BalanceGenerator problems (skill eq.balance.true_false).

The prompt line says how the equation is written; its numbers say what is on each side. The
verdict is whether the two sides make the same total. The one wrong verdict is named by the
reading that gives it: left_side_only when "=" read as "the answer comes next" (does the left
side make the first number after "="?) disagrees with the truth, otherwise thought_equal (true
when the sides differ) or thought_unequal (false when they match).
"""
from __future__ import annotations

# prompt line -> (left side, right side), each the prompt params in the order written
LAYOUTS = {
    "z2.eq.prompt_balance_two_two": (("a", "b"), ("c", "d")),
    "z2.eq.prompt_balance_two_one": (("a", "b"), ("c",)),
    "z2.eq.prompt_balance_one_two": (("c",), ("a", "b")),
}
LABELS = {"true": "ui.answer.true", "false": "ui.answer.false"}


def sides(line: str, params: dict) -> tuple[list[int], list[int]] | None:
    layout = LAYOUTS.get(line)
    if layout is None:
        return None
    return [params[name] for name in layout[0]], [params[name] for name in layout[1]]


def wrong_verdict_name(left: list[int], right: list[int]) -> str:
    truth = sum(left) == sum(right)
    first_after_equals = right[0]
    if (sum(left) == first_after_equals) != truth:
        return "left_side_only"
    return "thought_unequal" if truth else "thought_equal"


def check(problem: dict) -> list[str]:
    if problem["params"]["mode"] != "true_false":
        return [f"unknown balance mode {problem['params']['mode']!r}"]
    errors: list[str] = []
    line = problem["prompt_line_id"]
    found = sides(line, problem["prompt_params"])
    if found is None:
        return [f"unknown balance prompt {line!r}"]
    left, right = found
    names = {name for side in LAYOUTS[line] for name in side}
    if set(problem["prompt_params"]) != names:
        errors.append(f"prompt params should be {sorted(names)}, got {sorted(problem['prompt_params'])}")
    top = problem["params"]["max"]
    if not all(1 <= value <= top for value in left + right) or sum(left) > top or sum(right) > top:
        errors.append(f"numbers {left} and {right} must each be 1 to {top}, and so must each side's total")
    if problem["visual"] != {"type": "balance", "left": left, "right": right, "tilt": "unknown"}:
        errors.append(f"the balance should hold {left} and {right} with the tilt hidden, got {problem['visual']}")
    truth = sum(left) == sum(right)
    if problem["answer"] is not truth:
        errors.append(f"{left} and {right} make {sum(left)} and {sum(right)}: the answer is {truth}, not {problem['answer']!r}")
    expected = [(not truth, wrong_verdict_name(left, right))]
    given = [(entry["value"], entry["misconception"]) for entry in problem["distractors"]]
    if len(given) != 1 or given[0][0] is not expected[0][0] or given[0][1] != expected[0][1]:
        errors.append(f"the one wrong verdict should be {expected}, got {given}")
    if problem["meta"].get("label_lines") != LABELS:
        errors.append(f"the buttons need the True and False label lines, got {problem['meta'].get('label_lines')}")
    tilt = "level" if truth else ("left" if sum(left) > sum(right) else "right")
    model = problem["hint_steps"][1]["visual"]
    if model != {"type": "balance", "left": left, "right": right, "tilt": tilt}:
        errors.append(f"the hint should show the balance tipped {tilt}, got {model}")
    errors += _check_example(problem["hint_steps"][2]["example"])
    return errors


def _check_example(example: dict) -> list[str]:
    found = sides(example["prompt_line_id"], example["prompt_params"])
    if found is None:
        return [f"the worked example uses an unknown prompt {example['prompt_line_id']!r}"]
    left, right = sum(found[0]), sum(found[1])
    if example["answer"] is not (left == right):
        return [f"the worked example sides make {left} and {right}, so its answer should be {left == right}"]
    wanted = ("z2.hint.example_true", {"n": left}) if left == right else ("z2.hint.example_false", {"left": left, "right": right})
    if (example["answer_line_id"], example["answer_params"]) != wanted:
        return [f"the worked example should say {wanted}, got {(example['answer_line_id'], example['answer_params'])}"]
    return []
