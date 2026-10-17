"""pytest: the independent addition and subtraction checkers accept correct problems and catch wrong ones.

Every problem here is written out by hand from the skill definitions (never produced by the GDScript
generators), then tampered with. If a checker stopped checking something, a tamper would pass.
"""
from __future__ import annotations

import copy
import os
import shutil
from pathlib import Path

import pytest
import run
from checkers import addition, subtraction

SKILLS = {skill["id"]: skill for skill in run.load_skills()}
ALLOWED = run.allowed_misconceptions()


def loose(*counts: int) -> dict:
    return {"type": "gem_piles", "piles": [{"hundreds": 0, "tens": 0, "ones": n} for n in counts]}


def piles(*numbers: int) -> dict:
    return {"type": "gem_piles", "piles": [{"hundreds": 0, "tens": n // 10, "ones": n % 10} for n in numbers]}


def pile(tens: int, ones: int) -> dict:
    return {"type": "gem_piles", "piles": [{"hundreds": 0, "tens": tens, "ones": ones}]}


def line(low: int, high: int, every: int, markers: list[int], jumps: list[tuple[int, int]]) -> dict:
    return {"type": "number_line", "min": low, "max": high, "labeled_every": every, "markers": markers, "blanks": [],
            "jumps": [{"from": start, "to": end} for start, end in jumps]}


def example(prompt_line: str, prompt_params: dict, answer: int, answer_line: str, answer_params: dict) -> dict:
    return {"prompt_line_id": prompt_line, "prompt_params": prompt_params, "answer": answer,
            "answer_line_id": answer_line, "answer_params": answer_params}


def make(skill_id: str, prompt_line: str, prompt_params: dict, answer: int, distractors: list[tuple[str, int]],
         visual: dict, model: dict, worked: dict, representation: str | None = None) -> dict:
    skill = SKILLS[skill_id]
    representation = representation or skill["representations"][0]
    return {
        "skill_id": skill_id, "seed": 1, "representation": representation,
        "prompt_line_id": prompt_line, "prompt_params": prompt_params,
        "answer": answer, "answer_modes": skill["answer_modes"],
        "distractors": [{"value": value, "misconception": name} for name, value in distractors],
        "visual": visual,
        "hint_steps": [
            {"kind": "repeat_highlight", "line_id": prompt_line, "params": prompt_params, "visual": {}, "highlight": list(prompt_params)},
            {"kind": "visual_model", "line_id": "bolt.hint.show_model", "params": {}, "visual": model},
            {"kind": "worked_example", "line_id": "bolt.hint.worked_example", "params": {}, "visual": {}, "example": worked},
            {"kind": "easier_problem", "line_id": "bolt.hint.easier", "params": {}, "visual": {}, "easier_params": {"difficulty": -1}},
        ],
        "params": dict(skill["params"], representation=representation),
        "meta": {},
    }


SUM = "z2.add.prompt_sum"
DIFF = "z2.sub.prompt_diff"


def add_example(a: int, b: int, prompt_line: str = SUM) -> dict:
    return example(prompt_line, {"a": a, "b": b}, a + b, "z2.hint.example_add", {"a": a, "b": b, "sum": a + b})


def sub_example(a: int, b: int, prompt_line: str = DIFF) -> dict:
    return example(prompt_line, {"a": a, "b": b}, a - b, "z2.hint.example_sub", {"a": a, "b": b, "diff": a - b})


def good_problems() -> dict[str, dict]:
    """One correct problem per kind (and per representation), worked out by hand."""
    return {
        "facts": make("add.to_10.sums", SUM, {"a": 3, "b": 4}, 7, [("counted_from_one", 6), ("off_by_one", 8)],
                      loose(3, 4), {"type": "ten_frame", "count": 3, "second": 4, "frames": 1}, add_example(6, 1)),
        "make_ten": make("add.to_20.sums", "z2.add.prompt_make_ten", {"a": 8, "b": 5}, 13,
                         [("forgot_regroup", 3), ("off_by_one", 14), ("off_by_one", 12)],
                         {"type": "ten_frame", "count": 8, "second": 5, "frames": 2}, line(0, 20, 5, [8], [(8, 10), (10, 13)]),
                         example("z2.add.prompt_make_ten", {"a": 7, "b": 6}, 13, "z2.hint.example_make_ten",
                                 {"a": 7, "fill": 3, "ten": 10, "rest": 3, "sum": 13})),
        "near_double": make("add.to_20.doubles", SUM, {"a": 6, "b": 7}, 13, [("off_by_one", 12), ("off_by_one", 14), ("off_by_two", 11)],
                            loose(6, 7), {"type": "pairs", "count": 13, "show_pairs": True}, add_example(8, 8)),
        "double": make("add.to_20.doubles", SUM, {"a": 7, "b": 7}, 14, [("off_by_one", 13), ("off_by_one", 15), ("off_by_two", 16)],
                       loose(7, 7), {"type": "pairs", "count": 14, "show_pairs": True}, add_example(4, 5)),
        "add_tens": make("add.to_100.tens", "z2.add.prompt_tens", {"a": 30, "b": 40}, 70,
                         [("added_as_ones", 7), ("decade_skip", 60), ("decade_skip", 80)],
                         piles(30, 40), line(0, 100, 10, [30], [(30, 40), (40, 50), (50, 60), (60, 70)]),
                         add_example(20, 50, "z2.add.prompt_tens")),
        "no_regroup_concrete": make("add.to_100.no_regroup", SUM, {"a": 34, "b": 25}, 59,
                                    [("added_tens_to_ones", 86), ("digit_swap", 95)], piles(34, 25), pile(5, 9),
                                    add_example(41, 6), "concrete"),
        "no_regroup_abstract": make("add.to_100.no_regroup", SUM, {"a": 34, "b": 5}, 39,
                                    [("added_tens_to_ones", 84), ("digit_swap", 93)], {}, piles(34, 5),
                                    add_example(52, 13), "abstract"),
        "regroup_concrete": make("add.to_100.regroup", SUM, {"a": 38, "b": 5}, 43, [("forgot_regroup", 33), ("carried_twice", 53)],
                                 piles(38, 5), pile(3, 13), add_example(47, 36), "concrete"),
        "regroup_abstract": make("add.to_100.regroup", SUM, {"a": 47, "b": 36}, 83, [("forgot_regroup", 73), ("carried_twice", 93)],
                                 {}, piles(47, 36), add_example(38, 5), "abstract"),
        "three": make("add.three_addends.to_20", "z2.add.prompt_three", {"a": 7, "b": 3, "c": 5}, 15,
                      [("dropped_addend", 10), ("off_by_one", 16), ("dropped_addend", 8), ("dropped_addend", 12), ("off_by_one", 14)],
                      loose(7, 3, 5), line(0, 20, 5, [7], [(7, 10), (10, 15)]),
                      example("z2.add.prompt_three", {"a": 2, "b": 6, "c": 4}, 12, "z2.hint.example_add_three", {"a": 2, "b": 6, "c": 4, "sum": 12})),
        "sub_10": make("sub.to_10.diff", DIFF, {"a": 9, "b": 4}, 5, [("added_instead", 13), ("off_by_one", 6), ("off_by_one", 4)],
                       loose(9), line(0, 10, 1, [9], [(9, 5)]), sub_example(7, 2)),
        "sub_20": make("sub.to_20.diff", DIFF, {"a": 13, "b": 5}, 8, [("added_instead", 18), ("off_by_one", 9), ("off_by_one", 7)],
                       {"type": "ten_frame", "count": 13, "frames": 2}, line(0, 20, 5, [13], [(13, 10), (10, 8)]), sub_example(16, 3)),
        "sub_tens": make("sub.to_100.tens", "z2.sub.prompt_tens", {"a": 70, "b": 30}, 40,
                         [("subtracted_as_ones", 4), ("subtracted_as_ones", 67)], piles(70),
                         line(0, 100, 10, [70], [(70, 60), (60, 50), (50, 40)]), sub_example(50, 20, "z2.sub.prompt_tens")),
        "sub_no_regroup_concrete": make("sub.to_100.no_regroup", DIFF, {"a": 57, "b": 23}, 34, [("digit_swap", 43), ("added_instead", 80)],
                                        piles(57), line(30, 60, 10, [57], [(57, 37), (37, 34)]), sub_example(48, 6), "concrete"),
        "sub_no_regroup_abstract": make("sub.to_100.no_regroup", DIFF, {"a": 46, "b": 42}, 4, [("added_instead", 88)],
                                        {}, piles(46), sub_example(35, 12), "abstract"),
        "sub_regroup_concrete": make("sub.to_100.regroup", DIFF, {"a": 53, "b": 27}, 26,
                                     [("smaller_from_larger", 34), ("forgot_untrade", 36)], piles(53), pile(4, 13), sub_example(42, 8), "concrete"),
        # 52 - 27: both mistakes give 35, so only one is offered.
        "sub_regroup_abstract": make("sub.to_100.regroup", DIFF, {"a": 52, "b": 27}, 25, [("smaller_from_larger", 35)],
                                     {}, piles(52), sub_example(61, 9), "abstract"),
    }


GOOD = good_problems()


def verdict(problem: dict) -> list[str]:
    return run.check_problem(problem, SKILLS[problem["skill_id"]], ALLOWED)


@pytest.mark.parametrize("name", sorted(GOOD))
def test_a_correct_problem_passes(name: str) -> None:
    assert verdict(copy.deepcopy(GOOD[name])) == []


def _set_numbers(**numbers: int):
    """A tamper that replaces prompt numbers (and keeps rung 1 repeating them)."""
    def edit(problem: dict) -> None:
        problem["prompt_params"].update(numbers)
        problem["hint_steps"][0]["params"] = problem["prompt_params"]
    return edit


def _distractor(index: int, value=None, name: str | None = None):
    def edit(problem: dict) -> None:
        if value is not None:
            problem["distractors"][index]["value"] = value
        if name is not None:
            problem["distractors"][index]["misconception"] = name
    return edit


def _example(**changes):
    def edit(problem: dict) -> None:
        worked = problem["hint_steps"][2]["example"]
        for key, value in changes.items():
            if key in worked["answer_params"] and key not in ("answer",):
                worked["answer_params"][key] = value
            else:
                worked[key] = value
    return edit


TAMPERS = [
    # Wrong answers.
    ("facts", lambda p: p.__setitem__("answer", 8), "is not 3 + 4 = 7"),
    ("make_ten", lambda p: p.__setitem__("answer", 14), "is not 8 + 5 = 13"),
    ("three", lambda p: p.__setitem__("answer", 14), "is not 7 + 3 + 5 = 15"),
    ("regroup_abstract", lambda p: p.__setitem__("answer", 73), "is not 47 + 36 = 83"),
    ("sub_20", lambda p: p.__setitem__("answer", 7), "is not 13 - 5 = 8"),
    ("sub_regroup_concrete", lambda p: p.__setitem__("answer", 36), "is not 53 - 27 = 26"),
    # Wrong distractor values.
    ("facts", _distractor(0, 5), "counted_from_one value 5"),
    ("make_ten", _distractor(0, 4), "forgot_regroup value 4"),
    ("near_double", _distractor(2, 10), "off_by_two value 10"),
    ("add_tens", _distractor(0, 70 // 10 + 1), "added_as_ones value 8"),
    ("add_tens", _distractor(1, 50), "decade_skip value 50"),
    ("no_regroup_concrete", _distractor(0, 68), "added_tens_to_ones value 68"),
    ("no_regroup_concrete", _distractor(1, 96), "digit_swap value 96"),
    ("regroup_concrete", _distractor(1, 63), "carried_twice value 63"),
    ("three", _distractor(0, 11), "dropped_addend value 11"),
    ("sub_10", _distractor(0, 14), "added_instead value 14"),
    ("sub_tens", _distractor(0, 5), "subtracted_as_ones value 5"),
    ("sub_regroup_concrete", _distractor(0, 33), "smaller_from_larger value 33"),
    ("sub_regroup_concrete", _distractor(1, 37), "forgot_untrade value 37"),
    ("sub_no_regroup_concrete", _distractor(0, 44), "digit_swap value 44"),
    # Wrong misconception names.
    ("facts", _distractor(0, name="off_by_one"), "counted_from_one is missing"),
    ("no_regroup_concrete", _distractor(1, name="carried_twice"), "not listed for the skill"),
    ("make_ten", _distractor(0, name="off_by_one"), "off_by_one value 3"),
    ("sub_regroup_concrete", _distractor(1, name="smaller_from_larger"), "smaller_from_larger value 36"),
    ("sub_no_regroup_abstract", lambda p: p["distractors"].append({"value": 40, "misconception": "digit_swap"}), "unexpected misconception digit_swap"),
    ("sub_no_regroup_concrete", lambda p: p["distractors"].append({"value": 34 + 0, "misconception": "smaller_from_larger"}), "unexpected misconception smaller_from_larger"),
    # Missing wrong answers.
    ("three", lambda p: p["distractors"].pop(1), "the wrong answer 16"),
    ("regroup_concrete", lambda p: p["distractors"].pop(0), "forgot_regroup is missing"),
    ("near_double", lambda p: p["distractors"].pop(2), "off_by_two is missing"),
    ("sub_regroup_concrete", lambda p: p["distractors"].pop(1), "the wrong answer 36"),
    ("no_regroup_abstract", lambda p: p["distractors"].pop(0), "the wrong answer 84"),
    # The regroup condition broken.
    ("no_regroup_concrete", _set_numbers(a=36, b=25), "should not regroup"),
    ("regroup_concrete", _set_numbers(a=34, b=5), "needs regrouping"),
    ("sub_no_regroup_concrete", _set_numbers(a=53, b=27), "should not need regrouping"),
    ("sub_regroup_concrete", _set_numbers(a=57, b=23), "needs regrouping"),
    ("no_regroup_abstract", _set_numbers(a=50, b=50), "regroups into a hundred"),
    # Out of range.
    ("facts", _set_numbers(a=7, b=5), "is over 10"),
    ("make_ten", _set_numbers(a=5, b=8), "start from 6 to 9"),
    ("make_ten", _set_numbers(a=6, b=3), "does not cross ten"),
    ("near_double", _set_numbers(a=6, b=8), "neither a double"),
    ("three", _set_numbers(a=9, b=9, c=5), "over 20"),
    ("add_tens", _set_numbers(a=35), "should both be tens"),
    ("add_tens", _set_numbers(a=70, b=40), "is over 100"),
    ("sub_20", _set_numbers(a=9, b=5), "should be from 11 to 20"),
    ("sub_10", _set_numbers(a=3, b=5), "never more than 3"),
    ("sub_tens", _set_numbers(b=70), "b should be less than a"),
    ("sub_no_regroup_concrete", _set_numbers(a=157), "two-digit number minus a smaller number"),
    ("regroup_concrete", _set_numbers(a=8), "two-digit number plus"),
    # Prompt lines, pictures and hint models.
    ("add_tens", lambda p: p.__setitem__("prompt_line_id", SUM), "wrong prompt line"),
    ("sub_tens", lambda p: p.__setitem__("prompt_line_id", DIFF), "wrong prompt line"),
    ("make_ten", lambda p: p["visual"].__setitem__("count", 5), "two ten-frames"),
    ("facts", lambda p: p["hint_steps"][1]["visual"].__setitem__("second", 5), "ten-frame of 3 then 4"),
    ("make_ten", lambda p: p["hint_steps"][1]["visual"].__setitem__("jumps", [{"from": 8, "to": 13}]), "jump from 8 to 10"),
    ("double", lambda p: p["hint_steps"][1]["visual"].__setitem__("count", 15), "in pairs"),
    ("add_tens", lambda p: p["visual"]["piles"][0].__setitem__("ones", 1), "ten-bars"),
    ("no_regroup_concrete", lambda p: p.__setitem__("visual", piles(34, 52)), "34 and 25 as tens and ones"),
    ("regroup_concrete", lambda p: p["hint_steps"][1].__setitem__("visual", pile(4, 3)), "tens together"),
    ("regroup_abstract", lambda p: p.__setitem__("visual", piles(47, 36)), "no picture"),
    ("sub_20", lambda p: p["hint_steps"][1]["visual"].__setitem__("jumps", [{"from": 13, "to": 8}]), "through 10"),
    ("sub_regroup_concrete", lambda p: p["hint_steps"][1].__setitem__("visual", pile(5, 3)), "after trading a ten"),
    ("sub_no_regroup_concrete", lambda p: p["hint_steps"][1]["visual"].__setitem__("jumps", [{"from": 57, "to": 34}]), "jump back from 57"),
    ("sub_tens", lambda p: p["hint_steps"][1]["visual"]["jumps"].pop(), "count back by tens"),
    ("three", lambda p: p.__setitem__("meta", {"tools": ["one"]}), "unexpected meta"),
    # Worked examples.
    ("facts", _example(answer=8), "worked example's answer 8"),
    ("make_ten", _example(rest=4), "make-a-ten steps"),
    ("make_ten", _example(prompt_params={"a": 3, "b": 4}), "worked example: make-a-ten facts start"),
    ("sub_10", _example(diff=6), "should say 7 - 2 = 5"),
    ("three", _example(answer_line_id="z2.hint.example_add"), "states its answer with"),
    ("regroup_concrete", _example(prompt_params={"a": 34, "b": 25}, answer=59), "worked example: 34 + 25 needs regrouping"),
    # Unknown modes are reported, not raised.
    ("facts", lambda p: p["params"].__setitem__("mode", "juggling"), "unknown addition mode"),
    ("sub_10", lambda p: p["params"].__setitem__("mode", "juggling"), "unknown subtraction mode"),
]


@pytest.mark.parametrize(("name", "edit", "fragment"), TAMPERS, ids=[f"{n}-{i}" for i, (n, _, _) in enumerate(TAMPERS)])
def test_a_wrong_problem_is_caught(name: str, edit, fragment: str) -> None:
    problem = copy.deepcopy(GOOD[name])
    edit(problem)
    errors = verdict(problem)
    assert errors, "the tampered problem was accepted"
    assert any(fragment in error for error in errors), errors


def test_the_misconception_helpers_work_on_digit_strings() -> None:
    assert addition.crossed_places(34, 25) == 86   # 3 + 5 tens, 4 + 2 ones
    assert addition.crossed_places(34, 5) == 84    # the 5 lined up under the 3
    assert addition.crossed_places(34, 20) == 36   # the 2 tens added to the ones
    assert addition.crossed_places(72, 5) is None  # the tens column passes 9
    assert addition.crossed_places(38, 41) is None  # the ones column passes 9
    assert addition.crossed_places(34, 22) is None  # 22 reads the same both ways: no different number
    assert addition.swapped(59) == 95
    assert addition.swapped(40) is None and addition.swapped(44) is None and addition.swapped(4) is None
    assert addition.digits(7) == (0, 7) and addition.digits(83) == (8, 3)


def test_every_zone_2_skill_of_these_generators_has_a_kind_and_a_checker() -> None:
    kinds = {
        "AdditionGenerator": addition.kind_of,
        "SubtractionGenerator": subtraction.kind_of,
    }
    found = 0
    for skill in SKILLS.values():
        if skill["generator"] in kinds:
            found += 1
            assert kinds[skill["generator"]](skill["params"]) is not None, skill["id"]
            assert skill["generator"] in run.CHECKERS
    assert found == 12


def test_the_good_problems_cover_every_skill_and_representation() -> None:
    covered = {(p["skill_id"], p["representation"]) for p in GOOD.values()}
    for skill in SKILLS.values():
        if skill["generator"] in ("AdditionGenerator", "SubtractionGenerator"):
            for representation in skill["representations"]:
                assert (skill["id"], representation) in covered


# --- End to end (needs the Godot binary: set GODOT, as CI does) -------------------------------

GODOT = os.environ.get("GODOT") or os.environ.get("GODOT_BIN")
needs_godot = pytest.mark.skipif(not GODOT or not shutil.which(GODOT) and not Path(GODOT or "").exists(), reason="set GODOT to the Godot 4.7.2 executable")


@needs_godot
@pytest.mark.parametrize("skill_id", ["add.to_100.regroup", "sub.to_100.no_regroup"])
def test_end_to_end_zone_2(skill_id: str, tmp_path: Path) -> None:
    assert run.main(["--skill", skill_id, "--n", "200", "--godot", GODOT, "--out", str(tmp_path)]) == 0
