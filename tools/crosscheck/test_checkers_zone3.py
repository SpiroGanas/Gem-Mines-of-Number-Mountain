"""pytest: the Zone 3 checkers (skip counting, parity, arrays, multiplication) accept correct problems
and catch every kind of wrong one.

Each valid problem is written out by hand from the skill definitions (never produced by the GDScript
generators), then tampered with. If a checker stopped checking something, a tamper would pass.
"""
from __future__ import annotations

import copy
import os
import shutil
from pathlib import Path

import pytest
import run
from checkers import multiplication, parity, skip_count

SKILLS = {skill["id"]: skill for skill in run.load_skills()}
ALLOWED = run.allowed_misconceptions()
ZONE3 = sorted(skill_id for skill_id, skill in SKILLS.items() if skill["zone"] == 3)


def line(low: int, high: int, every: int, markers=(), blanks=(), jumps=None) -> dict:
    result = {"type": "number_line", "min": low, "max": high, "labeled_every": every, "markers": list(markers), "blanks": list(blanks)}
    if jumps is not None:
        result["jumps"] = jumps
    return result


def hops(values: list[int]) -> list[dict]:
    return [{"from": a, "to": b} for a, b in zip(values, values[1:])]


def make(skill_id: str, prompt_line: str, prompt_params: dict, answer, distractors, *, visual=None, meta=None,
         model=None, example=None, example_visual=None, representation=None) -> dict:
    skill = SKILLS[skill_id]
    return {
        "skill_id": skill_id, "seed": 1,
        "representation": representation or skill["representations"][0],
        "prompt_line_id": prompt_line, "prompt_params": prompt_params,
        "answer": answer, "answer_modes": skill["answer_modes"],
        "distractors": [{"value": value, "misconception": name} for name, value in distractors],
        "visual": visual or {},
        "hint_steps": [
            {"kind": "repeat_highlight", "line_id": prompt_line, "params": prompt_params, "visual": {}, "highlight": list(prompt_params)},
            {"kind": "visual_model", "line_id": "bolt.hint.show_model", "params": {}, "visual": model},
            {"kind": "worked_example", "line_id": "bolt.hint.worked_example", "params": {}, "visual": example_visual or {}, "example": example},
            {"kind": "easier_problem", "line_id": "bolt.hint.easier", "params": {}, "visual": {}, "easier_params": {"difficulty": -1}},
        ],
        "params": dict(skill["params"]), "meta": meta or {},
    }


def example(prompt_line: str, prompt_params: dict, answer, answer_line: str, answer_params: dict) -> dict:
    return {"prompt_line_id": prompt_line, "prompt_params": prompt_params, "answer": answer,
            "answer_line_id": answer_line, "answer_params": answer_params}


def good_problems() -> dict[str, dict]:
    """One correct problem per mode (two for the parity rule: the tens digit misleads, or agrees)."""
    return {
        # 20, _, 40, _, 60: counting by ones gives 21 and 41; the decade skip moves 30 up to 40.
        "skip_10": make("skip.by_10.to_120", "z3.skip.prompt_by_10", {}, [30, 50],
                        [("wrong_step", [21, 41]), ("decade_skip", [40, 50])],
                        visual=line(20, 60, 10, [], [30, 50]),
                        meta={"strip": [20, 30, 40, 50, 60], "tile_board": {"tiles": [41, 30, 21, 50, 40], "slots": 2, "ordered": True}},
                        model=line(20, 60, 10, [], [50], hops([20, 30, 40, 50, 60])),
                        example=example("z3.skip.prompt_by_10", {}, [70, 80], "z3.hint.example_blanks", {"a": 70, "b": 80}),
                        example_visual=line(60, 100, 10, [], [70, 80])),
        # 35, _, _, 50, 55: side-by-side blanks counted by ones are 36, then 37.
        "skip_5": make("skip.by_5.to_100", "z3.skip.prompt_by_5", {}, [40, 45], [("wrong_step", [36, 37])],
                       visual=line(35, 55, 5, [], [40, 45]),
                       meta={"strip": [35, 40, 45, 50, 55], "tile_board": {"tiles": [37, 45, 40, 36], "slots": 2, "ordered": True}},
                       model=line(35, 55, 5, [], [45], hops([35, 40, 45, 50, 55])),
                       example=example("z3.skip.prompt_by_5", {}, [15, 25], "z3.hint.example_blanks", {"a": 15, "b": 25}),
                       example_visual=line(10, 30, 5, [], [15, 25])),
        # 12, _, 16, _, 20 beside 20 gems in pairs.
        "skip_2": make("skip.by_2.to_40", "z3.skip.prompt_by_2", {}, [14, 18],
                       [("wrong_step", [13, 17]), ("off_by_one", [15, 19])],
                       visual={"type": "pairs", "count": 20, "show_pairs": True},
                       meta={"strip": [12, 14, 16, 18, 20], "picture": "pairs_up_to_last",
                             "tile_board": {"tiles": [19, 14, 13, 18, 15, 17], "slots": 2, "ordered": True}},
                       model=line(12, 20, 2, [], [18], hops([12, 14, 16, 18, 20])),
                       example=example("z3.skip.prompt_by_2", {}, [6, 8], "z3.hint.example_blanks", {"a": 6, "b": 8}),
                       example_visual={"type": "pairs", "count": 10, "show_pairs": True}),
        "pairs": make("parity.even_odd.pairs", "z3.parity.prompt_pairs", {}, "odd", [("leftover_miscounted", "even")],
                      visual={"type": "pairs", "count": 7, "show_pairs": False},
                      meta={"label_lines": {"even": "ui.answer.even", "odd": "ui.answer.odd"}},
                      model={"type": "pairs", "count": 7, "show_pairs": True},
                      example=example("z3.parity.prompt_pairs", {}, "even", "z3.hint.example_pairs_even", {"n": 10}),
                      example_visual={"type": "pairs", "count": 10, "show_pairs": False}),
        # 34: the tens digit 3 says odd, but 34 is even.
        "rule_misled": make("parity.even_odd.rule", "z3.parity.prompt_rule", {"n": 34}, "even", [("used_tens_digit", "odd")],
                            meta={"label_lines": {"even": "ui.answer.even", "odd": "ui.answer.odd"}, "tens_digit_misleads": True},
                            model=line(30, 40, 2, [34]),
                            example=example("z3.parity.prompt_rule", {"n": 47}, "odd", "z3.hint.example_rule_odd", {"n": 47, "digit": 7})),
        # 46: the tens digit 4 agrees, so picking odd is just mixing up the words.
        "rule_agrees": make("parity.even_odd.rule", "z3.parity.prompt_rule", {"n": 46}, "even", [("parity_swapped", "odd")],
                            meta={"label_lines": {"even": "ui.answer.even", "odd": "ui.answer.odd"}, "tens_digit_misleads": False},
                            model=line(40, 50, 2, [46]),
                            example=example("z3.parity.prompt_rule", {"n": 100}, "even", "z3.hint.example_rule_even", {"n": 100, "digit": 0})),
        "count": make("arr.rows_cols.count", "z3.arr.prompt_count", {}, 12,
                      [("rows_plus_cols", 7), ("off_by_row", 8), ("off_by_row", 16)],
                      visual={"type": "array", "rows": 3, "cols": 4},
                      model={"type": "array", "rows": 3, "cols": 4, "outline_rows": True},
                      example=example("z3.arr.prompt_count", {}, 10, "z3.hint.example_array_total", {"rows": 2, "cols": 5, "total": 10}),
                      example_visual={"type": "array", "rows": 2, "cols": 5}),
        "build": make("arr.rows_cols.build", "z3.arr.prompt_build", {"rows": 2, "cols": 4}, {"rows": 2, "cols": 4},
                      [("rows_cols_swapped", {"rows": 4, "cols": 2})],
                      meta={"array_builder": {"max_rows": 5, "max_cols": 5}},
                      model={"type": "array", "rows": 2, "cols": 4, "outline_rows": True},
                      example=example("z3.arr.prompt_build", {"rows": 3, "cols": 5}, {"rows": 3, "cols": 5}, "z3.hint.example_array_shape", {"rows": 3, "cols": 5})),
        "repeated": make("mult.repeated_add.to_sum", "z3.mult.prompt_repeated_3", {"n": 4}, 12,
                         [("counted_groups", 3), ("off_by_group", 8), ("off_by_group", 16)],
                         visual={"type": "groups", "groups": 3, "size": 4},
                         model=line(0, 12, 4, [], [], hops([0, 4, 8, 12])),
                         example=example("z3.mult.prompt_repeated_2", {"n": 5}, 10, "z3.hint.example_groups_total", {"groups": 2, "size": 5, "total": 10}),
                         example_visual={"type": "groups", "groups": 2, "size": 5}),
        "equal_groups": make("mult.equal_groups.total", "z3.mult.prompt_equal_groups", {"groups": 4, "size": 5}, 20,
                             [("rows_plus_cols", 9), ("counted_groups", 4)],
                             visual={"type": "groups", "groups": 4, "size": 5},
                             model={"type": "array", "rows": 4, "cols": 5, "outline_rows": True},
                             example=example("z3.mult.prompt_equal_groups", {"groups": 3, "size": 6}, 18, "z3.hint.example_groups_total", {"groups": 3, "size": 6, "total": 18}),
                             example_visual={"type": "groups", "groups": 3, "size": 6}),
        # 3 rows of 5: the same total is 5 × 3; each wrong fact is swapped with one number moved by one.
        "commutative": make("mult.commutative.match", "z3.mult.prompt_commutative", {"rows": 3, "cols": 5}, "5 × 3",
                            [("rows_cols_swapped_wrong", "5 × 4"), ("rows_cols_swapped_wrong", "6 × 3"), ("rows_cols_swapped_wrong", "4 × 3")],
                            visual={"type": "array", "rows": 3, "cols": 5},
                            model={"type": "array", "rows": 5, "cols": 3, "outline_rows": True},
                            example=example("z3.mult.prompt_commutative", {"rows": 2, "cols": 4}, "4 × 2", "z3.hint.example_commutative", {"rows": 2, "cols": 4, "total": 8}),
                            example_visual={"type": "array", "rows": 2, "cols": 4}),
        # 5 × 7 from the 5 table: a group of 5 too many or too few, or 7 times another table's number.
        "facts": make("mult.facts.2_5_10", "z3.mult.prompt_fact", {"a": 5, "b": 7}, 35,
                      [("off_by_group", 40), ("wrong_table", 14), ("off_by_group", 30), ("wrong_table", 70)],
                      meta={"table": 5, "table_first": True},
                      model={"type": "groups", "groups": 5, "size": 7},
                      example=example("z3.mult.prompt_fact", {"a": 3, "b": 10}, 30, "z3.hint.example_fact", {"a": 3, "b": 10, "product": 30})),
    }


GOOD = good_problems()


def verdict(problem: dict) -> list[str]:
    return run.check_problem(problem, SKILLS[problem["skill_id"]], ALLOWED)


@pytest.mark.parametrize("name", sorted(GOOD))
def test_a_correct_problem_passes(name: str) -> None:
    assert verdict(copy.deepcopy(GOOD[name])) == []


def test_every_zone_3_skill_has_a_good_problem_and_a_checker() -> None:
    assert {problem["skill_id"] for problem in GOOD.values()} == set(ZONE3)
    assert len(ZONE3) == 11
    for skill_id in ZONE3:
        assert SKILLS[skill_id]["generator"] in run.CHECKERS


def _set(path: list, value):
    """An edit that sets problem[path...] = value."""
    def edit(problem: dict) -> None:
        target = problem
        for key in path[:-1]:
            target = target[key]
        target[path[-1]] = value
    return edit


def _distractor(index: int, value):
    return _set(["distractors", index, "value"], value)


def _name(index: int, name: str):
    return _set(["distractors", index, "misconception"], name)


TAMPERS = [
    # Skip counting
    ("skip_10", _set(["meta", "strip"], [20, 30, 40, 55, 60]), "does not count by 10"),
    ("skip_10", _set(["params", "max"], 50), "runs past 50"),
    ("skip_10", _set(["answer"], [50, 30]), "strip order"),
    ("skip_10", _set(["answer"], [20, 30]), "first or last"),
    ("skip_10", _set(["visual", "blanks"], [30, 40]), "number line"),
    ("skip_10", _set(["visual", "labeled_every"], 5), "number line"),
    ("skip_10", _distractor(0, [21, 31]), "wrong_step should be [21, 41]"),
    ("skip_10", _distractor(1, [40, 60]), "decade_skip"),
    ("skip_10", lambda p: p["distractors"].pop(1), "exactly the mistakes"),
    ("skip_10", _set(["meta", "tile_board", "tiles"], [41, 30, 21, 50]), "tiles"),
    ("skip_10", _set(["meta", "tile_board", "ordered"], False), "ordered slots"),
    ("skip_10", _set(["prompt_line_id"], "z3.skip.prompt_by_5"), "should use z3.skip.prompt_by_10"),
    ("skip_10", _set(["hint_steps", 1, "visual", "blanks"], [30, 50]), "first blank filled in"),
    ("skip_10", _set(["hint_steps", 2, "example", "answer_params"], {"a": 70, "b": 90}), "missing numbers"),
    ("skip_5", _set(["meta", "strip"], [36, 41, 46, 51, 56]), "multiple of 5"),
    ("skip_5", lambda p: p["distractors"].append({"value": [41, 46], "misconception": "off_by_one"}), "exactly the mistakes"),
    ("skip_5", _distractor(0, [36, 36]), "two different positive numbers"),
    ("skip_2", _distractor(1, [15, 20]), "off_by_one should be [15, 19]"),
    ("skip_2", _set(["visual", "count"], 18), "concrete picture"),
    ("skip_2", lambda p: p["meta"].pop("picture"), "meta.picture"),
    # Parity
    ("pairs", _set(["answer"], "even"), "are odd, not even"),
    ("pairs", _set(["visual", "show_pairs"], True), "loose gems"),
    ("pairs", _set(["visual", "count"], 21), "outside 1..20"),
    ("pairs", _name(0, "parity_swapped"), "leftover_miscounted"),
    ("pairs", _set(["meta", "label_lines"], {"even": "ui.answer.even"}), "answer buttons"),
    ("pairs", _set(["hint_steps", 1, "visual", "show_pairs"], False), "rung 2"),
    ("pairs", _set(["hint_steps", 2, "example", "answer_line_id"], "z3.hint.example_pairs_odd"), "worked example"),
    ("rule_misled", _name(0, "parity_swapped"), "named used_tens_digit"),
    ("rule_agrees", _name(0, "used_tens_digit"), "named parity_swapped"),
    ("rule_misled", _set(["meta", "tens_digit_misleads"], False), "tens_digit_misleads"),
    ("rule_agrees", _set(["answer"], "odd"), "is even, not odd"),
    ("rule_agrees", _set(["prompt_params", "n"], 9), "outside 10"),
    ("rule_agrees", _set(["visual"], {"type": "pairs", "count": 46}), "no picture"),
    ("rule_misled", _set(["hint_steps", 1, "visual", "labeled_every"], 5), "rung 2 model"),
    ("rule_agrees", _set(["hint_steps", 2, "example", "answer_params", "digit"], 1), "worked example"),
    # Arrays
    ("count", _set(["answer"], 13), "holds 12 gems"),
    ("count", _distractor(0, 8), "rows_plus_cols should be"),
    ("count", _distractor(1, 9), "off_by_row 9"),
    ("count", _set(["visual", "rows"], 6), "outside"),
    ("count", _set(["hint_steps", 1, "visual"], {"type": "array", "rows": 3, "cols": 4}), "rows outlined"),
    ("count", _set(["hint_steps", 2, "example", "answer"], 11), "worked example"),
    ("build", _set(["answer"], {"rows": 4, "cols": 2}), "not the 2 rows"),
    ("build", lambda p: (p["prompt_params"].update(cols=2), p.__setitem__("answer", {"rows": 2, "cols": 2})), "should differ"),
    ("build", _set(["meta", "array_builder"], {"max_rows": 4, "max_cols": 4}), "full size"),
    ("build", _set(["visual"], {"type": "array", "rows": 2, "cols": 4}), "no picture"),
    ("build", _distractor(0, {"rows": 4, "cols": 3}), "swapped array"),
    # Multiplication
    ("repeated", _set(["prompt_line_id"], "z3.mult.prompt_repeated_4"), "does not add 3 numbers"),
    ("repeated", _set(["answer"], 16), "make 12, not 16"),
    ("repeated", _distractor(0, 4), "counted_groups"),
    ("repeated", _distractor(1, 13), "off_by_group 13"),
    ("repeated", _set(["prompt_params", "n"], 3), "should add 4"),
    ("repeated", _set(["hint_steps", 1, "visual", "jumps"], hops([0, 4, 8])), "hop by the group size"),
    ("equal_groups", _set(["answer"], 25), "make 20, not 25"),
    ("equal_groups", _set(["prompt_params", "groups"], 5), "prompt should name"),
    ("equal_groups", _set(["params", "max"], 15), "allowed sizes"),
    ("equal_groups", _distractor(0, 10), "rows_plus_cols"),
    ("equal_groups", _set(["hint_steps", 1, "visual", "rows"], 5), "rows of an array"),
    ("commutative", _set(["answer"], "3 × 5"), "should be '5 × 3'"),
    ("commutative", _distractor(0, "3 × 5"), "another option already makes"),
    ("commutative", _distractor(0, "5 × 5"), "one number changed by one"),
    ("commutative", _distractor(0, "5 x 4"), "not a fact like"),
    ("commutative", _distractor(0, 20), "not a fact like"),
    ("commutative", lambda p: p["distractors"].pop(), "three wrong facts"),
    ("commutative", _set(["hint_steps", 1, "visual"], {"type": "array", "rows": 3, "cols": 5, "outline_rows": True}), "turned on its side"),
    ("commutative", lambda p: (p["visual"].update(cols=3), p["prompt_params"].update(cols=3)), "different sides"),
    ("facts", _set(["answer"], 36), "is 35, not 36"),
    ("facts", _set(["meta", "table_first"], False), "meta says the table"),
    ("facts", _set(["meta", "table"], 3), "not one of the tables"),
    ("facts", _distractor(0, 33), "off_by_group 33"),
    ("facts", _distractor(1, 21), "wrong_table 21"),
    ("facts", lambda p: p.__setitem__("distractors", [d for d in p["distractors"] if d["misconception"] == "wrong_table"]), "needs both"),
    ("facts", lambda p: (p["prompt_params"].update(b=11), p.__setitem__("answer", 55)), "outside 1..10"),
    ("facts", _set(["hint_steps", 1, "visual"], {"type": "groups", "groups": 7, "size": 5}), "5 groups of 7"),
    ("facts", _set(["hint_steps", 2, "example", "answer_params", "product"], 31), "worked example"),
]


@pytest.mark.parametrize(("name", "edit", "fragment"), TAMPERS, ids=[f"{n}-{i}" for i, (n, _, _) in enumerate(TAMPERS)])
def test_a_wrong_problem_is_caught(name: str, edit, fragment: str) -> None:
    problem = copy.deepcopy(GOOD[name])
    edit(problem)
    errors = verdict(problem)
    assert errors, "the tampered problem was accepted"
    assert any(fragment in error for error in errors), errors


@pytest.mark.parametrize("name", ["skip_10", "pairs", "count", "facts"])
def test_an_unknown_mode_or_step_is_reported_not_raised(name: str) -> None:
    problem = copy.deepcopy(GOOD[name])
    problem["params"]["step" if name == "skip_10" else "mode"] = 7 if name == "skip_10" else "juggling"
    errors = verdict(problem)
    assert any("unknown" in error or "no skip-counting prompt" in error for error in errors), errors


def test_a_malformed_export_is_a_failure_not_a_crash() -> None:
    problem = copy.deepcopy(GOOD["facts"])
    del problem["hint_steps"][2]["example"]["prompt_params"]["a"]
    assert any("could not read" in error for error in verdict(problem))


# --- The checkers' own helpers -----------------------------------------------------------------


def test_counting_by_ones_follows_the_childs_own_numbers() -> None:
    assert skip_count.child_counting_by_ones([10, 20, 30, 40, 50], [1, 2]) == [11, 12]
    assert skip_count.child_counting_by_ones([10, 20, 30, 40, 50], [1, 3]) == [11, 31]
    assert skip_count.child_counting_by_ones([2, 4, 6, 8, 10], [2, 3]) == [5, 6]


def test_parity_by_pairing_and_by_last_digit_agree() -> None:
    for n in range(0, 121):
        assert parity.by_pairing(n) == parity.by_last_digit(n)
    assert parity.by_pairing(7) == "odd" and parity.by_last_digit(40) == "even"
    assert parity.tens_digit_word(100) == "even" # its tens digit is 0
    assert parity.tens_digit_word(34) == "odd" and parity.tens_digit_word(7) == "even"


def test_a_fact_label_must_use_the_times_sign_and_single_spaces() -> None:
    assert multiplication.parse_fact("5 × 3") == (5, 3)
    assert multiplication.parse_fact("10 × 10") == (10, 10)
    for bad in ("5 x 3", "5×3", "5  × 3", " 5 × 3", "5 × 3 = 15", 15, None):
        assert multiplication.parse_fact(bad) is None
    assert multiplication.add_groups(4, 6) == 24 and multiplication.add_groups(0, 9) == 0


def test_every_repeated_addition_prompt_has_its_number_of_addends() -> None:
    texts = multiplication.line_texts()
    for groups in range(2, 6):
        text = texts[f"z3.mult.prompt_repeated_{groups}"]
        assert text.count("{n}") == groups and text.count("+") == groups - 1


# --- End to end (needs the Godot binary: set GODOT, as CI does) -------------------------------

GODOT = os.environ.get("GODOT") or os.environ.get("GODOT_BIN")
needs_godot = pytest.mark.skipif(not GODOT or not shutil.which(GODOT) and not Path(GODOT or "").exists(), reason="set GODOT to the Godot 4.7.2 executable")


@needs_godot
@pytest.mark.parametrize("skill_id", ZONE3)
def test_end_to_end_zone_3_skill(skill_id: str, tmp_path: Path) -> None:
    assert run.main(["--skill", skill_id, "--n", "200", "--godot", GODOT, "--out", str(tmp_path)]) == 0
