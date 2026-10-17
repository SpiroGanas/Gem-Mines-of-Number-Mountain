"""Independent re-derivation of the RegroupGenerator problems (skills pv.regroup.*).
The idea that makes this checkable: a trade never changes the total, so the answer must be worth
exactly what the starting pile is worth, with the right number of tens."""
from __future__ import annotations

from .common import distractors_by_name, pile_total


def _worth(pile: dict) -> int:
    return pile["tens"] * 10 + pile["ones"]


def check(problem: dict) -> list[str]:
    mode = problem["params"]["mode"]
    if mode not in ("ones_to_ten", "ten_to_ones"):
        return [f"unknown regroup mode {mode!r}"]
    errors: list[str] = []
    start = {"tens": problem["prompt_params"]["tens"], "ones": problem["prompt_params"]["ones"]}
    if problem["meta"].get("start") != start:
        errors.append("meta.start does not match the numbers in the prompt")
    piles = problem["visual"].get("piles", [])
    if len(piles) != 1 or pile_total(piles[0]) != _worth(start):
        errors.append("the gems shown do not match the starting pile")
    answer = problem["answer"]
    if _worth(answer) != _worth(start):
        errors.append(f"the trade changed the total: {_worth(start)} became {_worth(answer)}")
    if mode == "ones_to_ten":
        if not 10 <= start["ones"] <= 19 or answer["tens"] != start["tens"] + 1 or answer["ones"] != start["ones"] - 10:
            errors.append(f"trading ten ones for a ten from {start} gave {answer}")
        if problem["prompt_line_id"] != "z1.regroup.prompt_trade_ten":
            errors.append("wrong prompt line for trading ones for a ten")
    else:
        if not 1 <= start["tens"] <= 9 or answer["tens"] != start["tens"] - 1 or answer["ones"] != start["ones"] + 10:
            errors.append(f"trading a ten for ten ones from {start} gave {answer}")
        if problem["prompt_line_id"] != "z1.regroup.prompt_untrade":
            errors.append("wrong prompt line for trading a ten for ones")
    wrong = distractors_by_name(problem)
    if wrong.get("forgot_regroup") != [start]:
        errors.append("forgot_regroup should be the unchanged starting pile")
    if "traded_wrong_count" not in wrong:
        errors.append("traded_wrong_count is missing")
    for name, values in wrong.items():
        for value in values:
            if value["tens"] < 0 or value["ones"] < 0:
                errors.append(f"{name} has a negative count: {value}")
            if name == "traded_wrong_count":
                if _worth(value) == _worth(start):
                    errors.append(f"traded_wrong_count {value} keeps the total, so it is a correct trade")
                if value["tens"] != answer["tens"]:
                    errors.append(f"traded_wrong_count {value} should still change the tens by one")
            elif name != "forgot_regroup":
                errors.append(f"unexpected misconception {name}")
    return errors
