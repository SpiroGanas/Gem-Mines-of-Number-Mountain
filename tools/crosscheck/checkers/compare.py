"""Independent re-derivation of the CompareGenerator problems (skills cmp.*)."""
from __future__ import annotations

from .common import pile_total


def check(problem: dict) -> list[str]:
    mode = problem["params"]["mode"]
    handler = {"more_less": _more_less, "symbols": _symbols, "order": _order}.get(mode)
    if handler is None:
        return [f"unknown compare mode {mode!r}"]
    return handler(problem)


def _more_less(problem: dict) -> list[str]:
    errors: list[str] = []
    totals = [pile_total(pile) for pile in problem["visual"]["piles"]]
    if len(totals) != 2 or totals[0] == totals[1]:
        return ["there must be two piles of different sizes"]
    if not all(1 <= t <= problem["params"]["max"] for t in totals):
        errors.append(f"pile sizes {totals} are outside 1 to {problem['params']['max']}")
    ask = problem["meta"].get("ask")
    if ask not in ("more", "fewer"):
        return errors + [f"unknown question {ask!r}"]
    wanted = totals.index(max(totals)) if ask == "more" else totals.index(min(totals))
    if problem["answer"] != wanted:
        errors.append(f"asked for {ask}; piles {totals}; the answer should be pile {wanted}")
    expected_line = "z1.cmp.prompt_more" if ask == "more" else "z1.cmp.prompt_fewer"
    if problem["prompt_line_id"] != expected_line:
        errors.append(f"the prompt line should be {expected_line}")
    if [(d["value"], d["misconception"]) for d in problem["distractors"]] != [(1 - wanted, "picked_smaller")]:
        errors.append("the only wrong answer should be the other pile, named picked_smaller")
    return errors


def _symbols(problem: dict) -> list[str]:
    errors: list[str] = []
    a, b = problem["prompt_params"]["a"], problem["prompt_params"]["b"]
    if not (1 <= a <= problem["params"]["max"] and 1 <= b <= problem["params"]["max"]):
        errors.append(f"numbers {a}, {b} are outside the allowed range")
    expected = "=" if a == b else ("<" if a < b else ">")
    if problem["answer"] != expected:
        errors.append(f"{a} and {b} need {expected!r}, not {problem['answer']!r}")
    # tens vs ones disagree: e.g. 47 and 52 (tens say <, ones say >)
    tens_order = (a // 10 > b // 10) - (a // 10 < b // 10)
    ones_order = (a % 10 > b % 10) - (a % 10 < b % 10)
    conflict = tens_order * ones_order == -1
    if problem["meta"].get("conflict") != conflict:
        errors.append(f"conflict flag should be {conflict}")
    named = {d["value"]: d["misconception"] for d in problem["distractors"]}
    if len(problem["distractors"]) != 2 or set(named) | {expected} != {"<", ">", "="}:
        errors.append("the wrong answers should be the two other symbols")
        return errors
    if a == b:
        if set(named.values()) != {"thought_unequal"}:
            errors.append("for equal numbers both wrong symbols are thought_unequal")
    else:
        opposite = ">" if expected == "<" else "<"
        if named[opposite] != ("compared_ones_first" if conflict else "reversed_symbol"):
            errors.append(f"the opposite symbol has the wrong misconception name {named[opposite]!r}")
        if named["="] != "thought_equal":
            errors.append("= should be named thought_equal")
    return errors


def _order(problem: dict) -> list[str]:
    errors: list[str] = []
    shown = [pile_total(pile) for pile in problem["visual"]["piles"]]
    if shown != problem["meta"]["numbers"]:
        errors.append("the piles drawn do not match the numbers recorded")
    if len(shown) != problem["params"]["n"] or len(set(shown)) != len(shown):
        errors.append(f"{shown} should be {problem['params']['n']} different numbers")
    if not all(10 <= value <= problem["params"]["max"] for value in shown):
        errors.append(f"numbers {shown} are outside 10 to {problem['params']['max']}")
    direction = problem["meta"].get("direction")
    if direction not in ("least_first", "greatest_first"):
        return errors + [f"unknown direction {direction!r}"]
    expected = sorted(shown, reverse=(direction == "greatest_first"))
    if problem["answer"] != expected:
        errors.append(f"{shown} {direction}: expected {expected}, got {problem['answer']}")
    if shown == expected:
        errors.append("the piles are already in the answer order")
    line = {"least_first": "z1.cmp.order_least_first", "greatest_first": "z1.cmp.order_greatest_first"}[direction]
    if problem["prompt_line_id"] != line:
        errors.append(f"the prompt line should be {line}")
    by_ones = sorted(shown, key=lambda v: (v % 10, v), reverse=(direction == "greatest_first"))
    for entry in problem["distractors"]:
        if entry["misconception"] == "reversed_order":
            if entry["value"] != expected[::-1]:
                errors.append("reversed_order should be the answer backwards")
        elif entry["misconception"] == "compared_ones_first":
            if entry["value"] != by_ones:
                errors.append(f"compared_ones_first should be {by_ones}, got {entry['value']}")
        else:
            errors.append(f"unexpected misconception {entry['misconception']}")
    return errors
