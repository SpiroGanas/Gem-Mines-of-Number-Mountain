"""pytest: the Zone 2 equation checkers (fact families, the inverse check, missing parts and the
true-or-false balance) accept correct problems and catch every kind of wrong one.

The good problems are written out by hand here (never produced by the GDScript generators), then
tampered with. If a checker stopped checking something, one of these would stop failing.
"""
from __future__ import annotations

import copy

import pytest
import run
from checkers import balance, fact_family

SKILLS = {skill["id"]: skill for skill in run.load_skills()}
ALLOWED = run.allowed_misconceptions()


def make(skill_id: str, params: dict, prompt_line: str, prompt_params: dict, answer, distractors, *, model: dict,
         example: dict, visual: dict | None = None, meta: dict | None = None) -> dict:
    skill = SKILLS[skill_id]
    example = dict(example)
    example_visual = example.pop("visual", {})
    return {
        "skill_id": skill_id, "seed": 7, "representation": skill["representations"][0],
        "prompt_line_id": prompt_line, "prompt_params": prompt_params,
        "answer": answer, "answer_modes": skill["answer_modes"],
        "distractors": [{"value": value, "misconception": name} for name, value in distractors],
        "visual": visual or {},
        "hint_steps": [
            {"kind": "repeat_highlight", "line_id": prompt_line, "params": prompt_params, "visual": {}, "highlight": list(prompt_params)},
            {"kind": "visual_model", "line_id": "bolt.hint.show_model", "params": {}, "visual": model},
            {"kind": "worked_example", "line_id": "bolt.hint.worked_example", "params": {}, "visual": example_visual, "example": example},
            {"kind": "easier_problem", "line_id": "bolt.hint.easier", "params": {}, "visual": {}, "easier_params": {"difficulty": -1}},
        ],
        "params": dict(params, representation=skill["representations"][0]), "meta": meta or {},
    }


def number_line(low: int, high: int, every: int, markers: list[int], jumps: list[dict] | None = None) -> dict:
    line = {"type": "number_line", "min": low, "max": high, "labeled_every": every, "markers": markers, "blanks": []}
    if jumps is not None:
        line["jumps"] = jumps
    return line


def scale(left: list[int], right: list[int], tilt: str) -> dict:
    return {"type": "balance", "left": left, "right": right, "tilt": tilt}


FAMILY_3_5_8 = ["3 + 5 = 8", "5 + 3 = 8", "8 - 3 = 5", "8 - 5 = 3"]
LABELS = {"true": "ui.answer.true", "false": "ui.answer.false"}
BALANCE = {"mode": "true_false", "max": 20}
FALSE_EXAMPLE = {"prompt_line_id": "z2.eq.prompt_balance_two_one", "prompt_params": {"a": 6, "b": 5, "c": 10}, "answer": False,
                 "answer_line_id": "z2.hint.example_false", "answer_params": {"left": 11, "right": 10}}
TRUE_EXAMPLE = {"prompt_line_id": "z2.eq.prompt_balance_one_two", "prompt_params": {"c": 9, "a": 2, "b": 7}, "answer": True,
                "answer_line_id": "z2.hint.example_true", "answer_params": {"n": 9}}


def good_problems() -> dict[str, dict]:
    """One correct problem per mode (and per balance shape), worked out by hand."""
    return {
        "family": make(
            "eq.fact_family.build", {"mode": "build", "max": 20}, "z2.eq.prompt_fact_family", {"a": 3, "b": 5, "c": 8}, FAMILY_3_5_8,
            [("swapped_minuend", ["3 + 5 = 8", "3 - 8 = 5", "5 + 3 = 8", "8 - 5 = 3"]),
             ("wrong_operation", ["3 - 5 = 8", "5 + 3 = 8", "8 - 3 = 5", "8 - 5 = 3"])],
            meta={"tile_board": {"tiles": ["8 - 5 = 3", "3 - 8 = 5", "3 + 5 = 8", "3 - 5 = 8", "5 + 3 = 8", "8 - 3 = 5"], "slots": 4, "ordered": False}},
            model={"type": "ten_frame", "count": 3, "second": 5, "frames": 2},
            example={"prompt_line_id": "z2.eq.prompt_fact_family", "prompt_params": {"a": 2, "b": 4, "c": 6},
                     "answer": ["2 + 4 = 6", "4 + 2 = 6", "6 - 2 = 4", "6 - 4 = 2"], "answer_line_id": "z2.hint.example_family",
                     "answer_params": {"list": "2 + 4 = 6; 4 + 2 = 6; 6 - 2 = 4; 6 - 4 = 2"}},
        ),
        "inverse_add": make(
            "eq.inverse.check", {"mode": "inverse_check", "max": 20}, "z2.eq.prompt_inverse_add", {"a": 5, "b": 3, "c": 8}, "8 - 3 = 5",
            [("wrong_numbers", "9 - 3 = 6"), ("wrong_numbers", "7 - 3 = 4")],
            model=number_line(0, 10, 1, [5, 8], [{"from": 8, "to": 5}]),
            example={"prompt_line_id": "z2.eq.prompt_inverse_add", "prompt_params": {"a": 2, "b": 7, "c": 9}, "answer": "9 - 7 = 2",
                     "answer_line_id": "z2.hint.example_check", "answer_params": {"fact": "9 - 7 = 2"}},
        ),
        "inverse_sub": make(
            "eq.inverse.check", {"mode": "inverse_check", "max": 20}, "z2.eq.prompt_inverse_sub", {"a": 5, "b": 3, "c": 8}, "5 + 3 = 8",
            [("wrong_numbers", "6 + 3 = 9"), ("wrong_numbers", "4 + 3 = 7")],
            model=number_line(0, 10, 1, [5, 8], [{"from": 5, "to": 8}]),
            example={"prompt_line_id": "z2.eq.prompt_inverse_sub", "prompt_params": {"a": 4, "b": 9, "c": 13}, "answer": "4 + 9 = 13",
                     "answer_line_id": "z2.hint.example_check", "answer_params": {"fact": "4 + 9 = 13"}},
        ),
        "addend": make(
            "eq.missing_addend.to_20", {"mode": "addend", "max": 20}, "z2.eq.prompt_missing_addend", {"a": 6, "c": 13}, 7,
            [("added_both", 19), ("off_by_one", 6), ("off_by_one", 8)],
            visual={"type": "ten_frame", "count": 6, "frames": 2}, model={"type": "ten_frame", "count": 6, "second": 7, "frames": 2},
            example={"prompt_line_id": "z2.eq.prompt_missing_addend", "prompt_params": {"a": 9, "c": 12}, "answer": 3,
                     "answer_line_id": "z2.hint.example_missing_addend", "answer_params": {"a": 9, "n": 3, "c": 12},
                     "visual": {"type": "ten_frame", "count": 9, "frames": 2}},
        ),
        "subtrahend": make(
            "eq.missing_subtrahend.to_20", {"mode": "subtrahend", "max": 20}, "z2.eq.prompt_missing_subtrahend", {"c": 14, "a": 9}, 5,
            [("added_both", 23)],
            visual=number_line(0, 20, 2, [14, 9]), model=number_line(0, 20, 2, [14, 9], [{"from": 14, "to": 9}]),
            example={"prompt_line_id": "z2.eq.prompt_missing_subtrahend", "prompt_params": {"c": 7, "a": 3}, "answer": 4,
                     "answer_line_id": "z2.hint.example_missing_subtrahend", "answer_params": {"c": 7, "n": 4, "a": 3},
                     "visual": number_line(0, 10, 1, [7, 3])},
        ),
        # 3 + 4 = 5 + 2 is true; stopping at "= 5" says false.
        "two_two_true": make(
            "eq.balance.true_false", BALANCE, "z2.eq.prompt_balance_two_two", {"a": 3, "b": 4, "c": 5, "d": 2}, True,
            [("left_side_only", False)], visual=scale([3, 4], [5, 2], "unknown"), model=scale([3, 4], [5, 2], "level"),
            meta={"label_lines": LABELS}, example=FALSE_EXAMPLE,
        ),
        # 3 + 4 = 7 + 2 is false; stopping at "= 7" says true. This is the trap.
        "two_two_trap": make(
            "eq.balance.true_false", BALANCE, "z2.eq.prompt_balance_two_two", {"a": 3, "b": 4, "c": 7, "d": 2}, False,
            [("left_side_only", True)], visual=scale([3, 4], [7, 2], "unknown"), model=scale([3, 4], [7, 2], "right"),
            meta={"label_lines": LABELS}, example=TRUE_EXAMPLE,
        ),
        # 9 + 4 = 12 is false and the trap reading agrees, so saying true is thought_equal.
        "two_one_false": make(
            "eq.balance.true_false", BALANCE, "z2.eq.prompt_balance_two_one", {"a": 9, "b": 4, "c": 12}, False,
            [("thought_equal", True)], visual=scale([9, 4], [12], "unknown"), model=scale([9, 4], [12], "left"),
            meta={"label_lines": LABELS}, example=TRUE_EXAMPLE,
        ),
        "two_one_true": make(
            "eq.balance.true_false", BALANCE, "z2.eq.prompt_balance_two_one", {"a": 9, "b": 4, "c": 13}, True,
            [("thought_unequal", False)], visual=scale([9, 4], [13], "unknown"), model=scale([9, 4], [13], "level"),
            meta={"label_lines": LABELS}, example=FALSE_EXAMPLE,
        ),
        # 13 = 9 + 4 is true; "the answer comes after =" says false.
        "one_two_true": make(
            "eq.balance.true_false", BALANCE, "z2.eq.prompt_balance_one_two", {"c": 13, "a": 9, "b": 4}, True,
            [("left_side_only", False)], visual=scale([13], [9, 4], "unknown"), model=scale([13], [9, 4], "level"),
            meta={"label_lines": LABELS}, example=FALSE_EXAMPLE,
        ),
        "one_two_false": make(
            "eq.balance.true_false", BALANCE, "z2.eq.prompt_balance_one_two", {"c": 12, "a": 9, "b": 4}, False,
            [("thought_equal", True)], visual=scale([12], [9, 4], "unknown"), model=scale([12], [9, 4], "right"),
            meta={"label_lines": LABELS}, example=TRUE_EXAMPLE,
        ),
    }


GOOD = good_problems()


def verdict(problem: dict) -> list[str]:
    return run.check_problem(problem, SKILLS[problem["skill_id"]], ALLOWED)


@pytest.mark.parametrize("name", sorted(GOOD))
def test_a_correct_problem_passes(name: str) -> None:
    assert verdict(copy.deepcopy(GOOD[name])) == []


def _set(path: list, value):
    """An edit that sets problem[path...] = value."""
    def edit(problem: dict) -> None:
        target = problem
        for key in path[:-1]:
            target = target[key]
        target[path[-1]] = value
    return edit


def _example(key: str, value):
    return _set(["hint_steps", 2, "example", key], value)


TAMPERS = [
    # Fact family: the answer, the board, the wrong tiles and the hints.
    ("family", _set(["answer"], ["3 + 5 = 8", "3 - 8 = 5", "5 + 3 = 8", "8 - 5 = 3"]), "four facts"),
    ("family", _set(["answer"], ["8 - 5 = 3", "8 - 3 = 5", "5 + 3 = 8", "3 + 5 = 8"]), "sorted"),
    ("family", _set(["meta", "tile_board", "tiles", 0], "8-5=3"), "exact format"),
    ("family", _set(["meta", "tile_board", "tiles", 5], "8 − 3 = 5"), "exact format"),  # a Unicode minus sign
    ("family", _set(["meta", "tile_board", "tiles", 3], "3 - 2 = 1"), "wrong tiles"),
    ("family", _set(["meta", "tile_board", "tiles", 3], "3 + 5 = 9"), "wrong tiles"),
    ("family", _set(["meta", "tile_board", "slots"], 3), "slots"),
    ("family", _set(["distractors", 0, "misconception"], "wrong_operation"), "named"),
    ("family", _set(["distractors", 0, "value"], ["3 - 8 = 5", "8 - 3 = 5", "8 - 5 = 3", "3 + 5 = 8"]), "sorted"),
    ("family", _set(["distractors", 0, "value"], ["3 + 5 = 8", "3 - 8 = 5", "8 - 3 = 5", "8 - 5 = 3"]), "belongs"),
    ("family", _set(["prompt_params", "c"], 9), "make 8"),
    ("family", _set(["prompt_params"], {"a": 4, "b": 4, "c": 8}), "two different numbers"),
    ("family", _set(["params", "max"], 7), "over the skill's max"),
    ("family", _set(["visual"], {"type": "ten_frame", "count": 3, "frames": 1}), "no picture"),
    ("family", _set(["hint_steps", 1, "visual", "second"], 4), "two ten-frames"),
    ("family", _example("answer_params", {"list": "2 + 4 = 6; 4 + 2 = 6; 6 - 2 = 4"}), "list its four facts"),
    ("family", _example("answer", ["2 + 4 = 6", "4 + 2 = 6", "6 - 2 = 4", "6 - 4 = 3"]), "worked example"),
    # Inverse check: exactly one option checks, every option is a true fact.
    ("inverse_add", _set(["answer"], "8 - 5 = 3"), "is undone by"),
    ("inverse_add", _set(["distractors", 0, "value"], "8 - 5 = 3"), "exactly one option"),
    ("inverse_add", _set(["distractors", 1, "value"], "8 + 3 = 12"), "not a true fact"),
    ("inverse_add", _set(["distractors", 0, "value"], "5 + 3 = 8"), "the shown fact itself"),
    ("inverse_add", _set(["distractors", 0, "value"], "9 + 3 = 12"), "same sign as the answer"),
    ("inverse_add", _set(["distractors", 0, "value"], "8 - 5 = 3"), "would check it too"),
    ("inverse_add", _set(["distractors", 1, "value"], "9 - 3 = 6"), "two different wrong options"),
    ("inverse_add", _set(["distractors", 0, "value"], "25 - 3 = 22"), "out of range"),
    ("inverse_add", _set(["distractors", 0, "misconception"], "wrong_operation"), "named wrong_numbers"),
    ("inverse_add", _set(["distractors", 1, "value"], 11), "exact format"),
    ("inverse_add", _set(["prompt_line_id"], "z2.eq.prompt_fact_family"), "unknown inverse-check prompt"),
    ("inverse_add", _set(["hint_steps", 1, "visual", "jumps"], [{"from": 5, "to": 8}]), "should jump"),
    ("inverse_sub", _set(["answer"], "3 + 5 = 8"), "is undone by"),
    ("inverse_sub", _set(["distractors", 0, "value"], "3 + 5 = 8"), "exactly one option"),
    ("inverse_sub", _example("answer_params", {"fact": "9 + 4 = 13"}), "state its answer fact"),
    ("inverse_sub", _example("answer", "13 - 9 = 4"), "does not undo"),
    # Missing addend.
    ("addend", _set(["answer"], 8), "does not complete the sum"),
    ("addend", _set(["distractors", 0, "value"], 18), "wrong answers should be"),
    ("addend", _set(["distractors", 1, "value"], 5), "wrong answers should be"),
    ("addend", _set(["prompt_params", "a"], 13), "a < c"),
    ("addend", _set(["visual", "count"], 13), "the picture should show"),
    ("addend", _set(["hint_steps", 1, "visual", "second"], 6), "the hint should add"),
    ("addend", _example("answer_params", {"a": 9, "n": 4, "c": 12}), "worked example"),
    # Missing subtrahend.
    ("subtrahend", _set(["answer"], 23), "does not leave"),
    ("subtrahend", _set(["distractors", 0, "value"], 22), "added_both 23"),
    ("subtrahend", _set(["distractors", 0, "misconception"], "off_by_one"), "not listed for the skill"),
    ("subtrahend", _set(["visual", "markers"], [14]), "number line marking"),
    ("subtrahend", _set(["visual", "jumps"], [{"from": 14, "to": 9}]), "no jump yet"),
    ("subtrahend", _set(["hint_steps", 1, "visual", "jumps"], [{"from": 9, "to": 14}]), "jump back"),
    ("subtrahend", _set(["params", "max"], 10), "a < c <= 10"),
    # Balance: the verdict, the name of the wrong verdict, the labels and the pictures.
    ("two_two_true", _set(["answer"], False), "the answer is True"),
    ("two_two_true", _set(["distractors", 0, "misconception"], "thought_unequal"), "wrong verdict should be"),
    ("two_two_trap", _set(["distractors", 0, "misconception"], "thought_equal"), "wrong verdict should be"),
    ("two_two_trap", _set(["prompt_params", "c"], 6), "should hold"),
    ("two_one_false", _set(["distractors", 0, "misconception"], "left_side_only"), "wrong verdict should be"),
    ("two_one_true", _set(["distractors", 0, "value"], 0), "wrong verdict should be"),
    ("one_two_true", _set(["distractors", 0, "misconception"], "thought_unequal"), "wrong verdict should be"),
    ("one_two_false", _set(["answer"], 1), "not 1"),
    ("two_two_true", _set(["meta", "label_lines"], {"true": "ui.answer.true"}), "label line"),
    ("two_two_true", _set(["visual", "tilt"], "level"), "tilt hidden"),
    ("two_two_true", _set(["visual", "right"], [2, 5]), "should hold"),
    ("two_two_trap", _set(["hint_steps", 1, "visual", "tilt"], "left"), "tipped right"),
    ("two_one_true", _set(["prompt_params"], {"a": 19, "b": 4, "c": 23}), "1 to 20"),
    ("two_one_true", _set(["prompt_line_id"], "z2.eq.prompt_balance_one_two"), "should hold"),
    ("two_one_true", _set(["prompt_params", "d"], 1), "prompt params should be"),
    ("two_one_true", _set(["prompt_line_id"], "z2.eq.prompt_missing_addend"), "unknown balance prompt"),
    ("two_two_true", _example("answer_params", {"left": 11, "right": 11}), "worked example should say"),
    ("two_two_trap", _example("answer", False), "so its answer should be True"),
]


@pytest.mark.parametrize(("name", "edit", "fragment"), TAMPERS, ids=[f"{n}-{i}" for i, (n, _, _) in enumerate(TAMPERS)])
def test_a_wrong_problem_is_caught(name: str, edit, fragment: str) -> None:
    problem = copy.deepcopy(GOOD[name])
    edit(problem)
    errors = verdict(problem)
    assert errors, "the tampered problem was accepted"
    assert any(fragment in error for error in errors), errors


@pytest.mark.parametrize(("name", "mode", "message"), [
    ("family", "juggling", "unknown fact family mode"),
    ("addend", "juggling", "unknown missing-part mode"),
    ("two_one_true", "juggling", "unknown balance mode"),
])
def test_an_unknown_mode_is_reported_not_raised(name: str, mode: str, message: str) -> None:
    problem = copy.deepcopy(GOOD[name])
    problem["params"]["mode"] = mode
    assert any(message in error for error in verdict(problem))


def test_a_malformed_export_is_a_failure_not_a_crash() -> None:
    problem = copy.deepcopy(GOOD["two_two_true"])
    del problem["prompt_params"]["d"]
    assert any("could not read" in error for error in verdict(problem))


def test_the_fact_parser_takes_only_the_exact_format() -> None:
    assert fact_family.parse("12 - 5 = 7") == (12, "-", 5, 7)
    for bad in ("12-5=7", "12 - 5 =7", " 12 - 5 = 7", "12 – 5 = 7", "12 x 5 = 60", "-2 + 5 = 3", 7, None):
        assert fact_family.parse(bad) is None, bad


def test_a_family_is_found_by_trying_every_order() -> None:
    assert fact_family.family_of((3, 5, 8)) == set(FAMILY_3_5_8)
    assert fact_family.family_of((5, 8, 3)) == set(FAMILY_3_5_8)
    assert fact_family.family_of((3, 5, 9)) == set()


def test_wrong_tiles_are_told_apart() -> None:
    family = set(FAMILY_3_5_8)
    assert fact_family.classify("3 - 8 = 5", family) == "swapped_minuend"
    assert fact_family.classify("5 - 8 = 3", family) == "swapped_minuend"
    assert fact_family.classify("3 - 5 = 8", family) == "wrong_operation"
    assert fact_family.classify("8 + 5 = 3", family) == "wrong_operation"
    assert fact_family.classify("8 - 3 = 5", family) is None  # a true fact is no mistake
    assert fact_family.classify("3 + 5 = 9", family) is None  # not one change away from the family


def test_only_the_inverse_fact_of_the_same_numbers_checks() -> None:
    shown = fact_family.parse("5 + 3 = 8")
    for fact, expected in (("8 - 3 = 5", True), ("8 - 5 = 3", True), ("3 + 5 = 8", False), ("8 + 3 = 11", False), ("9 - 3 = 6", False)):
        assert fact_family.checks(fact_family.parse(fact), shown) is expected, fact


def test_the_wrong_verdict_names_follow_the_trap_reading() -> None:
    assert balance.wrong_verdict_name([3, 4], [5, 2]) == "left_side_only"  # true; the trap says false
    assert balance.wrong_verdict_name([3, 4], [7, 2]) == "left_side_only"  # false; the trap says true
    assert balance.wrong_verdict_name([3, 4], [6, 2]) == "thought_equal"   # false; the trap agrees
    assert balance.wrong_verdict_name([3, 4], [7]) == "thought_unequal"    # true; the trap agrees
    assert balance.wrong_verdict_name([7], [7, 3]) == "left_side_only"     # 7 = 7 + 3: the trap says true


def test_the_runner_has_a_checker_for_each_equation_generator() -> None:
    for generator in ("FactFamilyGenerator", "MissingPartGenerator", "BalanceGenerator"):
        assert generator in run.CHECKERS
    for skill_id in ("eq.fact_family.build", "eq.inverse.check", "eq.missing_addend.to_20", "eq.missing_subtrahend.to_20", "eq.balance.true_false"):
        assert SKILLS[skill_id]["generator"] in run.CHECKERS
