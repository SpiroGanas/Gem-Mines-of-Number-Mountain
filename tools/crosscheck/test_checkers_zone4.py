"""pytest: the Zone 4 checkers (multiplication and division facts, factors, multiples, primes) accept
correct problems and catch every kind of wrong one.

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
from checkers import numbers

SKILLS = {skill["id"]: skill for skill in run.load_skills()}
ALLOWED = run.allowed_misconceptions()
ZONE4 = sorted(skill_id for skill_id, skill in SKILLS.items() if skill["zone"] == 4)
YES_NO = {"true": "ui.common.yes", "false": "ui.common.no"}
HARDEST = {"mode": "single", "min": 2, "max": 100} # prime.classify.single at its widest range


def make(skill_id: str, prompt_line: str, prompt_params: dict, answer, distractors, *, visual=None, meta=None,
         model=None, example=None, example_visual=None, representation=None, params=None) -> dict:
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
        "params": params or dict(skill["params"]), "meta": meta or {},
    }


def example(prompt_line: str, prompt_params: dict, answer, answer_line: str, answer_params: dict) -> dict:
    return {"prompt_line_id": prompt_line, "prompt_params": prompt_params, "answer": answer,
            "answer_line_id": answer_line, "answer_params": answer_params}


def fact_example(a: int, b: int) -> dict:
    return example("z4.mult.prompt_fact", {"a": a, "b": b}, a * b, "z3.hint.example_fact", {"a": a, "b": b, "product": a * b})


def div_example(n: int, b: int, q: int) -> dict:
    return example("z4.div.prompt_fact", {"n": n, "b": b}, q, "z4.hint.example_div", {"n": n, "b": b, "q": q})


def good_problems() -> dict[str, dict]:
    arr, line, hops = numbers.array_picture, numbers.number_line, numbers.hops
    return {
        # 3 x 4 as an array of gems: a group too many (15) or too few (8), 3 + 4, and 12 turned round.
        "mult_concrete": make("mult.facts.0_5", "z4.mult.prompt_fact", {"a": 3, "b": 4}, 12,
                              [("off_by_group", 15), ("added_factors", 7), ("digit_swap", 21), ("off_by_group", 8)],
                              visual=arr(3, 4), meta={"table": 3, "table_first": True}, model=arr(3, 4, True),
                              example=fact_example(2, 5), representation="concrete"),
        # 5 x 0: only the abstract problems use zero. 5 + 0 and 5 groups of... all give the one wrong answer 5.
        "mult_zero": make("mult.facts.0_5", "z4.mult.prompt_fact", {"a": 5, "b": 0}, 0, [("off_by_group", 5)],
                          meta={"table": 0, "table_first": False}, model=line(0, 10, 1, [0]),
                          example=fact_example(4, 3), representation="abstract"),
        "mult_pictorial": make("mult.facts.6_10", "z4.mult.prompt_fact", {"a": 7, "b": 8}, 56,
                               [("off_by_group", 63), ("added_factors", 15), ("digit_swap", 65), ("off_by_group", 48)],
                               visual=hops(7, 8), meta={"table": 7, "table_first": True}, model=arr(7, 8, True),
                               example=fact_example(9, 6), representation="pictorial"),
        # 6 x 5: the digits of 30 end in 0, so there is no digit swap.
        "mult_mixed": make("mult.facts.mixed", "z4.mult.prompt_fact", {"a": 5, "b": 6}, 30,
                           [("off_by_group", 25), ("added_factors", 11), ("off_by_group", 36)],
                           meta={"table": 6, "table_first": False}, model=arr(5, 6, True), example=fact_example(8, 3)),
        "share": make("div.sharing.equal_shares", "z4.div.prompt_share", {"n": 12, "b": 3}, 4,
                      [("multiplied_instead", 36), ("off_by_one", 5), ("off_by_one", 3)],
                      visual={"type": "gem_piles", "piles": [{"hundreds": 0, "tens": 0, "ones": 12}]},
                      model={"type": "groups", "groups": 3, "size": 4}, example=div_example(10, 2, 5)),
        # 36 is more than 30 gems, so it is drawn as 3 tens and 6 ones.
        "div_big": make("div.facts.by_2_5", "z4.div.prompt_share", {"n": 36, "b": 4}, 9,
                        [("multiplied_instead", 144), ("off_by_one", 8), ("off_by_one", 10)],
                        visual={"type": "gem_piles", "piles": [{"hundreds": 0, "tens": 3, "ones": 6}]},
                        model={"type": "groups", "groups": 4, "size": 9}, example=div_example(20, 5, 4), representation="concrete"),
        "div_pictorial": make("div.facts.by_6_10", "z4.div.prompt_fact", {"n": 42, "b": 6}, 7,
                              [("multiplied_instead", 252), ("off_by_one", 6), ("off_by_one", 8)],
                              visual=line(0, 42, 6, [42]), model={"type": "groups", "groups": 6, "size": 7},
                              example=div_example(80, 8, 10), representation="pictorial"),
        # The factors of 12: leave out 1 and 12 (add 5 and 7), leave out the pair 2 and 6 (add 5 and 7).
        "fac_list": make("fac.list.find_all", "z4.fac.prompt_list", {"k": 6, "n": 12}, [1, 2, 3, 4, 6, 12],
                         [("missing_one_and_n", [2, 3, 4, 5, 6, 7]), ("skip_middle_pair", [1, 3, 4, 5, 7, 12])],
                         meta={"tile_board": {"tiles": [7, 1, 12, 4, 2, 6, 5, 3], "slots": 6, "ordered": False}},
                         model=arr(2, 6, True),
                         example=example("z4.fac.prompt_list", {"k": 4, "n": 10}, [1, 2, 5, 10], "z4.hint.example_factors", {"a": 2, "b": 5, "n": 10})),
        # 9 is a square: its middle pair is the single number 3. 2 x 9 = 18 swaps for the 3.
        "fac_list_square": make("fac.list.find_all", "z4.fac.prompt_list", {"k": 3, "n": 9}, [1, 3, 9],
                                [("missing_one_and_n", [3, 4, 5]), ("skip_middle_pair", [1, 2, 9]), ("multiple_not_factor", [1, 9, 18])],
                                meta={"tile_board": {"tiles": [5, 18, 1, 3, 9, 4, 2], "slots": 3, "ordered": False}},
                                model=arr(3, 3, True),
                                example=example("z4.fac.prompt_list", {"k": 3, "n": 4}, [1, 2, 4], "z4.hint.example_factors", {"a": 2, "b": 2, "n": 4})),
        "fac_rectangle": make("fac.pairs.rectangles", "z4.fac.prompt_rectangle", {"rows": 3, "n": 12}, {"rows": 3, "cols": 4},
                              [("rows_cols_swapped", {"rows": 4, "cols": 3}), ("off_by_one", {"rows": 3, "cols": 3}), ("off_by_one", {"rows": 3, "cols": 5})],
                              meta={"array_builder": {"max_rows": 6, "max_cols": 6}}, model=arr(3, 4, True),
                              example=example("z4.fac.prompt_rectangle", {"rows": 2, "n": 10}, {"rows": 2, "cols": 5},
                                              "z4.hint.example_rectangle", {"rows": 2, "cols": 5, "n": 10})),
        # A square has no swapped rectangle, and 1 column cannot be one fewer.
        "fac_rectangle_square": make("fac.pairs.rectangles", "z4.fac.prompt_rectangle", {"rows": 4, "n": 4}, {"rows": 4, "cols": 1},
                                     [("rows_cols_swapped", {"rows": 1, "cols": 4}), ("off_by_one", {"rows": 4, "cols": 2})],
                                     meta={"array_builder": {"max_rows": 6, "max_cols": 6}}, model=arr(4, 1, True),
                                     example=example("z4.fac.prompt_rectangle", {"rows": 3, "n": 9}, {"rows": 3, "cols": 3},
                                                     "z4.hint.example_rectangle", {"rows": 3, "cols": 3, "n": 9})),
        "fac_yes": make("fac.check.is_factor", "z4.fac.prompt_check", {"d": 4, "n": 12}, True,
                        [("no_check_made", False)], meta={"label_lines": YES_NO}, representation="abstract",
                        model=line(0, 12, 4, [12], [(0, 4), (4, 8), (8, 12)]),
                        example=example("z4.fac.prompt_check", {"d": 3, "n": 9}, True, "z4.hint.example_factor_yes", {"d": 3, "k": 3, "n": 9})),
        "fac_one": make("fac.check.is_factor", "z4.fac.prompt_check", {"d": 1, "n": 12}, True,
                        [("missing_one_and_n", False)], meta={"label_lines": YES_NO}, representation="abstract",
                        model=numbers.hops(12, 1, [12]),
                        example=example("z4.fac.prompt_check", {"d": 5, "n": 12}, False, "z4.hint.example_factor_no", {"d": 5, "n": 12})),
        # 18 is a multiple of 6 (3 x 6), not a factor of it; the picture is one big hop past 6.
        "fac_multiple": make("fac.check.is_factor", "z4.fac.prompt_check", {"d": 18, "n": 6}, False,
                             [("multiple_not_factor", True)], meta={"label_lines": YES_NO}, representation="pictorial",
                             visual=line(0, 18, 18, [6], [(0, 18)]), model=line(0, 18, 18, [6], [(0, 18)]),
                             example=example("z4.fac.prompt_check", {"d": 3, "n": 9}, True, "z4.hint.example_factor_yes", {"d": 3, "k": 3, "n": 9})),
        "fac_no": make("fac.check.is_factor", "z4.fac.prompt_check", {"d": 5, "n": 12}, False,
                       [("no_check_made", True)], meta={"label_lines": YES_NO}, representation="pictorial",
                       visual=line(0, 12, 5, [12], [(0, 5), (5, 10)]), model=line(0, 12, 5, [12], [(0, 5), (5, 10)]),
                       example=example("z4.fac.prompt_check", {"d": 4, "n": 12}, True, "z4.hint.example_factor_yes", {"d": 4, "k": 3, "n": 12})),
        # 4: [4, 8, 12]; the factors of 4 are [1, 2, 4]; start a multiple late or one early.
        "mul_first_k": make("mul.list.first_k", "z4.mul.prompt_first_k", {"k": 3, "b": 4}, [4, 8, 12],
                            [("factor_not_multiple", [1, 2, 4]), ("off_by_b", [8, 12, 16]), ("off_by_b", [0, 4, 8])],
                            meta={"tile_board": {"tiles": [16, 1, 8, 0, 12, 4, 2], "slots": 3, "ordered": True}},
                            model=hops(3, 4),
                            example=example("z4.mul.prompt_first_k", {"k": 3, "b": 5}, [5, 10, 15], "z4.hint.example_multiples", {"b": 5, "m2": 10, "m3": 15})),
        # 7 is a prime, so it has no third factor to list.
        "mul_first_k_prime": make("mul.list.first_k", "z4.mul.prompt_first_k", {"k": 3, "b": 7}, [7, 14, 21],
                                  [("off_by_b", [14, 21, 28]), ("off_by_b", [0, 7, 14])],
                                  meta={"tile_board": {"tiles": [28, 14, 0, 7, 21], "slots": 3, "ordered": True}},
                                  model=hops(3, 7),
                                  example=example("z4.mul.prompt_first_k", {"k": 3, "b": 2}, [2, 4, 6], "z4.hint.example_multiples", {"b": 2, "m2": 4, "m3": 6})),
        "mul_yes": make("mul.check.is_multiple", "z4.mul.prompt_check", {"n": 12, "b": 4}, True,
                        [("no_check_made", False)], meta={"label_lines": YES_NO}, representation="abstract", model=hops(3, 4, [12]),
                        example=example("z4.mul.prompt_check", {"n": 14, "b": 4}, False, "z4.hint.example_multiple_no", {"b": 4, "n": 14})),
        "mul_itself": make("mul.check.is_multiple", "z4.mul.prompt_check", {"n": 4, "b": 4}, True,
                           [("off_by_b", False)], meta={"label_lines": YES_NO}, representation="pictorial",
                           visual=hops(1, 4, [4]), model=hops(1, 4, [4]),
                           example=example("z4.mul.prompt_check", {"n": 10, "b": 5}, True, "z4.hint.example_multiple_yes", {"b": 5, "m": 2, "n": 10})),
        # 3 goes into 6, but 3 is a factor of 6, not a multiple.
        "mul_factor": make("mul.check.is_multiple", "z4.mul.prompt_check", {"n": 3, "b": 6}, False,
                           [("factor_not_multiple", True)], meta={"label_lines": YES_NO}, representation="abstract", model=hops(1, 6, [3]),
                           example=example("z4.mul.prompt_check", {"n": 10, "b": 5}, True, "z4.hint.example_multiple_yes", {"b": 5, "m": 2, "n": 10})),
        # 4 and 6 meet at 12. 24 is 4 x 6; 2 is the biggest number that goes into both; 8 is one hop of 4 early.
        "mul_common": make("mul.common.first", "z4.mul.prompt_common", {"a": 4, "b": 6}, 12,
                           [("used_the_product", 24), ("factor_not_multiple", 2), ("off_by_b", 8)],
                           model=hops(3, 4, [6, 12]),
                           example=example("z4.mul.prompt_common", {"a": 2, "b": 3}, 6, "z4.hint.example_common", {"a": 2, "b": 3, "m": 6})),
        # 2 and 3 are coprime: the product is the answer, so it is not offered as a mistake.
        "mul_common_coprime": make("mul.common.first", "z4.mul.prompt_common", {"a": 2, "b": 3}, 6,
                                   [("factor_not_multiple", 1), ("off_by_b", 4), ("off_by_b", 3)],
                                   model=hops(3, 2, [3, 6]),
                                   example=example("z4.mul.prompt_common", {"a": 4, "b": 6}, 12, "z4.hint.example_common", {"a": 4, "b": 6, "m": 12})),
        # 9 is a square (3 x 3).
        "prime_square": make("prime.classify.single", "z4.prime.prompt_single", {"n": 9}, False,
                             [("square_is_prime", True)], meta={"label_lines": YES_NO}, model=arr(3, 3, True),
                             example=example("z4.prime.prompt_single", {"n": 7}, True, "z4.hint.example_prime_yes", {"n": 7})),
        "prime_two": make("prime.classify.single", "z4.prime.prompt_single", {"n": 2}, True,
                          [("two_is_not_prime", False)], meta={"label_lines": YES_NO}, model=arr(1, 2),
                          example=example("z4.prime.prompt_single", {"n": 15}, False, "z4.hint.example_prime_no", {"a": 3, "b": 5, "n": 15})),
        # 91 = 7 x 13: the 13 is too long for an array, so the hint hops 7 times by 13.
        "prime_odd": make("prime.classify.single", "z4.prime.prompt_single", {"n": 91}, False,
                          [("odd_means_prime", True)], meta={"label_lines": YES_NO}, model=hops(7, 13), params=HARDEST,
                          example=example("z4.prime.prompt_single", {"n": 31}, True, "z4.hint.example_prime_yes", {"n": 31})),
        "prime_big": make("prime.classify.single", "z4.prime.prompt_single", {"n": 53}, True,
                          [("no_check_made", False)], meta={"label_lines": YES_NO}, model=hops(1, 53), params=HARDEST,
                          example=example("z4.prime.prompt_single", {"n": 8}, False, "z4.hint.example_prime_no", {"a": 2, "b": 4, "n": 8})),
        # Rocks 2, 4, 7, 9, 12, 15: the primes are 2 and 7.
        "prime_set": make("prime.classify.set", "z4.prime.prompt_set",
                          {"k": 2, "r1": 2, "r2": 4, "r3": 7, "r4": 9, "r5": 12, "r6": 15}, [2, 7],
                          [("square_is_prime", [2, 4]), ("odd_means_prime", [2, 15]), ("two_is_not_prime", [7, 12])],
                          meta={"tile_board": {"tiles": [15, 2, 9, 12, 7, 4], "slots": 2, "ordered": False}},
                          model=arr(3, 5, True),
                          example=example("z4.prime.prompt_set", {"k": 2, "r1": 3, "r2": 5, "r3": 6, "r4": 8, "r5": 9, "r6": 10}, [3, 5],
                                          "z4.hint.example_prime_yes", {"n": 3})),
        "pairs_count": make("prime.explain.factor_pairs", "z4.prime.prompt_pairs_count", {"n": 12}, 3,
                            [("counted_factors_not_pairs", 6), ("missing_one_and_n", 2), ("off_by_one", 4)],
                            model=arr(2, 6, True),
                            example=example("z4.prime.prompt_pairs_count", {"n": 8}, 2, "z4.hint.example_pairs", {"n": 8, "c": 2})),
        # 1 has one factor: it is not a prime.
        "pairs_one": make("prime.explain.factor_pairs", "z4.prime.prompt_pairs_prime", {"n": 1}, False,
                          [("one_is_prime", True)], meta={"label_lines": YES_NO}, model=arr(1, 1),
                          example=example("z4.prime.prompt_pairs_prime", {"n": 13}, True, "z4.hint.example_isprime_yes", {"n": 13})),
        "pairs_example_one": make("prime.explain.factor_pairs", "z4.prime.prompt_pairs_prime", {"n": 6}, False,
                                  [("no_check_made", True)], meta={"label_lines": YES_NO}, model=arr(2, 3, True),
                                  example=example("z4.prime.prompt_pairs_prime", {"n": 1}, False, "z4.prime.one_not_prime", {})),
    }


GOOD = good_problems()


def verdict(problem: dict) -> list[str]:
    return run.check_problem(problem, SKILLS[problem["skill_id"]], ALLOWED)


@pytest.mark.parametrize("name", sorted(GOOD))
def test_a_correct_problem_passes(name: str) -> None:
    assert verdict(copy.deepcopy(GOOD[name])) == []


def test_every_zone_4_skill_has_a_good_problem_and_a_checker() -> None:
    assert {problem["skill_id"] for problem in GOOD.values()} == set(ZONE4)
    assert len(ZONE4) == 15
    for skill_id in ZONE4:
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
    # Multiplication facts
    ("mult_concrete", _set(["answer"], 13), "is 12, not 13"),
    ("mult_concrete", _distractor(0, 14), "off_by_group 14"),
    ("mult_concrete", _distractor(1, 8), "added_factors 8"),
    ("mult_concrete", _distractor(2, 12), "equals the answer"),
    ("mult_concrete", _distractor(2, 22), "digit_swap 22"),
    ("mult_concrete", lambda p: p["distractors"].pop(2), "swapped digits of 12 are missing"),
    ("mult_concrete", lambda p: p["distractors"].pop(1), "7 (adding 3 + 4) is missing"),
    ("mult_concrete", _name(1, "wrong_table"), "not listed for the skill"),
    ("mult_concrete", _set(["visual"], numbers.array_picture(4, 3)), "concrete picture should be"),
    ("mult_concrete", _set(["meta", "table_first"], False), "meta says the table"),
    ("mult_concrete", _set(["meta", "table"], 6), "outside 0..5"),
    ("mult_concrete", _set(["hint_steps", 1, "visual"], numbers.array_picture(3, 4)), "rung 2 model"),
    ("mult_concrete", _set(["hint_steps", 2, "example", "answer_params", "product"], 11), "worked example"),
    ("mult_concrete", _set(["prompt_line_id"], "z3.mult.prompt_fact"), "should use z4.mult.prompt_fact"),
    ("mult_zero", _set(["representation"], "concrete"), "zero can only be asked"),
    ("mult_zero", _set(["hint_steps", 1, "visual"], numbers.array_picture(5, 1, True)), "rung 2 model"),
    ("mult_zero", lambda p: p["distractors"].pop(), "at least one wrong answer"),
    ("mult_zero", lambda p: (p["prompt_params"].update(a=0), p.__setitem__("answer", 0), p["meta"].update(table_first=True)), "0 x 0"),
    ("mult_pictorial", _set(["visual", "jumps"], [{"from": 0, "to": 8}]), "pictorial picture should be"),
    ("mult_pictorial", _set(["params", "table_min"], 8), "table 7"),
    ("mult_pictorial", _set(["meta", "table"], 11), "outside"),
    ("mult_mixed", _distractor(0, 31), "off_by_group 31"),
    # Division
    ("share", _set(["answer"], 5), "gives 4 each"),
    ("share", _set(["prompt_params", "n"], 13), "equal carts"),
    ("share", _distractor(0, 15), "multiplied_instead"),
    ("share", lambda p: p["distractors"].pop(1), "off_by_one should offer"),
    ("share", _set(["prompt_line_id"], "z4.div.prompt_fact"), "should use z4.div.prompt_share"),
    ("share", _set(["visual", "piles", 0, "ones"], 11), "picture should be"),
    ("share", _set(["hint_steps", 1, "visual", "groups"], 4), "rung 2 model"),
    ("share", _set(["hint_steps", 2, "example", "answer"], 6), "worked example"),
    ("share", _set(["params", "divisor_max"], 2), "carts is outside"),
    ("div_big", _set(["visual", "piles", 0], {"hundreds": 0, "tens": 0, "ones": 36}), "picture should be"),
    ("div_big", lambda p: p["distractors"].pop(0), "multiplied_instead should offer"),
    ("div_pictorial", _set(["visual", "labeled_every"], 7), "picture should be"),
    ("div_pictorial", _set(["representation"], "concrete"), "should use z4.div.prompt_share"),
    # Factors: list
    ("fac_list", _set(["answer"], [1, 2, 3, 4, 12]), "factors of 12"),
    ("fac_list", _set(["prompt_params", "k"], 5), "prompt should be"),
    ("fac_list", _distractor(0, [1, 3, 4, 5, 6, 7]), "missing_one_and_n"),
    ("fac_list", _distractor(0, [2, 3, 4, 6, 12, 7]), "missing_one_and_n"),
    ("fac_list", _distractor(1, [1, 3, 5, 6, 7, 12]), "skip_middle_pair"),
    ("fac_list", _distractor(1, [1, 2, 3, 4, 5, 12]), "skip_middle_pair"),
    ("fac_list", _name(1, "multiple_not_factor"), "multiple_not_factor"),
    ("fac_list", _distractor(1, [12, 5, 3, 1, 7, 4]), "sorted"),
    ("fac_list", _set(["meta", "tile_board", "tiles"], [7, 1, 12, 4, 2, 6, 5]), "exactly the numbers"),
    ("fac_list", _set(["meta", "tile_board", "ordered"], True), "unordered"),
    ("fac_list", _set(["meta", "tile_board", "slots"], 5), "unordered"),
    ("fac_list", _set(["hint_steps", 1, "visual"], numbers.array_picture(3, 4, True)), "rung 2 model"),
    ("fac_list", lambda p: p["distractors"].clear(), "at least one wrong board"),
    ("fac_list", _set(["params", "max"], 10), "not a composite"),
    ("fac_list", _set(["hint_steps", 2, "example", "answer_params", "a"], 5), "worked example"),
    ("fac_list_square", _distractor(2, [1, 9, 27]), "multiple_not_factor"),
    ("fac_list_square", _distractor(1, [1, 2, 3]), "skip_middle_pair"),
    # Factors: rectangles
    ("fac_rectangle", _set(["answer"], {"rows": 3, "cols": 5}), "rows of 5 make 15"),
    ("fac_rectangle", _set(["answer"], {"rows": 2, "cols": 6}), "keep the prompt's 3 rows"),
    ("fac_rectangle", _distractor(0, {"rows": 4, "cols": 4}), "rows_cols_swapped"),
    ("fac_rectangle", lambda p: p["distractors"].pop(2), "off_by_one should offer"),
    ("fac_rectangle", _set(["meta", "array_builder"], {"max_rows": 5, "max_cols": 5}), "6 by 6"),
    ("fac_rectangle", _set(["visual"], numbers.array_picture(3, 4)), "draws none"),
    ("fac_rectangle", _set(["hint_steps", 1, "visual"], numbers.array_picture(4, 3, True)), "rung 2 model"),
    ("fac_rectangle", _set(["hint_steps", 2, "example", "answer_params", "n"], 11), "worked example"),
    ("fac_rectangle_square", lambda p: p["distractors"].append({"value": {"rows": 1, "cols": 4}, "misconception": "rows_cols_swapped"}), "rows_cols_swapped"),
    # Factors: check
    ("fac_yes", _set(["answer"], False), "is a factor of 12"),
    ("fac_yes", _set(["distractors", 0], {"value": False, "misconception": "multiple_not_factor"}), "should be False named no_check_made"),
    ("fac_yes", _distractor(0, True), "equals the answer"),
    ("fac_yes", _set(["meta", "label_lines"], {"true": "ui.common.yes"}), "Yes and No"),
    ("fac_yes", _set(["visual"], numbers.number_line(0, 12, 4, [12])), "nothing otherwise"),
    ("fac_yes", _set(["hint_steps", 1, "visual", "markers"], [4]), "rung 2 model"),
    ("fac_yes", _set(["hint_steps", 2, "example", "answer_params", "k"], 4), "d x k = n"),
    ("fac_yes", _set(["params", "max"], 10), "outside 6..10"),
    ("fac_one", _name(0, "no_check_made"), "missing_one_and_n"),
    ("fac_multiple", _set(["prompt_params", "d"], 25), "2n or 3n"),
    ("fac_multiple", _name(0, "no_check_made"), "multiple_not_factor"),
    ("fac_no", _name(0, "multiple_not_factor"), "no_check_made"),
    ("fac_no", _set(["visual"], {}), "hop line"),
    ("fac_no", _set(["prompt_params", "d"], 1), "never asks about 1"),
    # Multiples: first k
    ("mul_first_k", _set(["answer"], [4, 8, 16]), "first 3 multiples of 4"),
    ("mul_first_k", _distractor(0, [1, 2, 3]), "factor_not_multiple"),
    ("mul_first_k", _distractor(1, [8, 12, 15]), "off_by_b"),
    ("mul_first_k", _distractor(2, [4, 8, 12]), "equals the answer"),
    ("mul_first_k", _distractor(2, [1, 4, 8]), "off_by_b"),
    ("mul_first_k", lambda p: p["distractors"].pop(1), "exactly the numbers"),
    ("mul_first_k_prime", lambda p: p["distractors"].clear(), "always offered"),
    ("mul_first_k", _set(["meta", "tile_board", "ordered"], False), "ordered"),
    ("mul_first_k", _set(["meta", "tile_board", "tiles"], [16, 1, 8, 0, 12, 4]), "exactly the numbers"),
    ("mul_first_k", _set(["hint_steps", 1, "visual", "labeled_every"], 2), "rung 2 model"),
    ("mul_first_k", _set(["hint_steps", 2, "example", "answer_params", "m3"], 16), "worked example"),
    ("mul_first_k", _set(["params", "k_max"], 2), "outside the skill's ranges"),
    # Multiples: check
    ("mul_yes", _set(["answer"], False), "is a multiple of 4"),
    ("mul_yes", _name(0, "off_by_b"), "named no_check_made"),
    ("mul_itself", _name(0, "no_check_made"), "named off_by_b"),
    ("mul_itself", _set(["visual"], {}), "hop line"),
    ("mul_factor", _name(0, "no_check_made"), "named factor_not_multiple"),
    ("mul_factor", _set(["hint_steps", 1, "visual", "markers"], [6]), "rung 2 model"),
    ("mul_factor", _set(["prompt_params", "n"], 4), "named no_check_made"),
    ("mul_yes", _set(["hint_steps", 2, "example", "answer"], True), "wrong answer for its own question"),
    ("mul_yes", _set(["meta", "label_lines"], {"true": "ui.answer.true", "false": "ui.answer.false"}), "Yes and No"),
    # Multiples: first shared multiple
    ("mul_common", _set(["answer"], 24), "first multiple of both"),
    ("mul_common", _distractor(0, 12), "equals the answer"),
    ("mul_common", _distractor(0, 25), "used_the_product"),
    ("mul_common", _distractor(1, 3), "factor_not_multiple"),
    ("mul_common", _distractor(2, 9), "off_by_b"),
    ("mul_common", lambda p: p["distractors"].pop(1), "factor_not_multiple should offer"),
    ("mul_common_coprime", lambda p: p["distractors"].append({"value": 6, "misconception": "used_the_product"}), "equals the answer"),
    ("mul_common", _set(["prompt_params", "b"], 4), "should differ"),
    ("mul_common", _set(["hint_steps", 1, "visual", "markers"], [6]), "rung 2 model"),
    ("mul_common", _set(["hint_steps", 2, "example", "answer"], 5), "worked example"),
    # Primes: single
    ("prime_square", _set(["answer"], True), "is not a prime"),
    ("prime_square", _name(0, "odd_means_prime"), "one wrong answer"),
    ("prime_square", _set(["prompt_params", "n"], 1), "outside 2"),
    ("prime_two", _name(0, "no_check_made"), "one wrong answer"),
    ("prime_two", _set(["answer"], False), "is a prime"),
    ("prime_odd", _name(0, "square_is_prime"), "one wrong answer"),
    ("prime_odd", _set(["hint_steps", 1, "visual"], numbers.array_picture(7, 13, True)), "rung 2 model"),
    ("prime_big", _set(["hint_steps", 1, "visual"], numbers.array_picture(1, 10)), "rung 2 model"),
    ("prime_big", _set(["params", "max"], 30), "outside"),
    ("prime_square", _set(["visual"], numbers.array_picture(3, 3)), "no picture"),
    ("prime_square", _set(["hint_steps", 2, "example", "answer_params", "n"], 9), "does not explain"),
    # Primes: set
    ("prime_set", _set(["answer"], [2, 7, 9]), "primes among"),
    ("prime_set", _set(["prompt_params", "k"], 3), "named in the prompt"),
    ("prime_set", _set(["prompt_params", "r3"], 8), "r1..r6"),
    ("prime_set", _distractor(0, [2, 7]), "equals the answer"),
    ("prime_set", _distractor(0, [2, 5]), "needs a tile 5"),
    ("prime_set", _distractor(1, [4, 15]), "swap exactly one"),
    ("prime_set", _distractor(2, [2, 12]), "leave out the prime 2"),
    ("prime_set", lambda p: p["distractors"].clear(), "at least one wrong board"),
    ("prime_set", _set(["meta", "tile_board", "tiles"], [15, 2, 9, 12, 7]), "6 different rocks"),
    ("prime_set", _set(["meta", "tile_board", "ordered"], True), "unordered slots"),
    ("prime_set", _set(["hint_steps", 1, "visual"], numbers.array_picture(2, 7, True)), "rung 2 model"),
    ("prime_set", _set(["hint_steps", 2, "example", "answer_params", "n"], 5), "first prime"),
    # Primes: pairs
    ("pairs_count", _set(["answer"], 6), "has 3 factor pairs"),
    ("pairs_count", _distractor(0, 5), "counted_factors_not_pairs"),
    ("pairs_count", _distractor(1, 1), "missing_one_and_n"),
    ("pairs_count", _distractor(2, 5), "off_by_one"),
    ("pairs_count", lambda p: p["distractors"].pop(0), "should offer 6"),
    ("pairs_count", _set(["prompt_params", "n"], 1), "outside 2"),
    ("pairs_count", _set(["hint_steps", 2, "example", "answer_params", "c"], 3), "pair count"),
    ("pairs_one", _set(["answer"], True), "is not a prime"),
    ("pairs_one", _name(0, "no_check_made"), "one wrong answer"),
    ("pairs_one", _set(["hint_steps", 1, "visual"], numbers.array_picture(1, 2)), "rung 2 model"),
    ("pairs_one", _set(["params", "max"], 0), "outside 1"),
    ("pairs_example_one", _set(["hint_steps", 2, "example", "answer_line_id"], "z4.hint.example_isprime_no"), "does not explain"),
]


@pytest.mark.parametrize(("name", "edit", "fragment"), TAMPERS, ids=[f"{n}-{i}" for i, (n, _, _) in enumerate(TAMPERS)])
def test_a_wrong_problem_is_caught(name: str, edit, fragment: str) -> None:
    problem = copy.deepcopy(GOOD[name])
    edit(problem)
    errors = verdict(problem)
    assert errors, "the tampered problem was accepted"
    assert any(fragment in error for error in errors), errors


@pytest.mark.parametrize("name", ["fac_list", "mul_first_k", "prime_square"])
def test_an_unknown_mode_is_reported_not_raised(name: str) -> None:
    problem = copy.deepcopy(GOOD[name])
    problem["params"]["mode"] = "juggling"
    errors = verdict(problem)
    assert any("unknown" in error for error in errors), errors


def test_a_malformed_export_is_a_failure_not_a_crash() -> None:
    problem = copy.deepcopy(GOOD["mult_concrete"])
    del problem["hint_steps"][2]["example"]["prompt_params"]["a"]
    assert any("could not read" in error for error in verdict(problem))


# --- The checkers' own helpers -----------------------------------------------------------------


def test_the_number_helpers_follow_the_definitions() -> None:
    assert numbers.divisors(36) == [1, 2, 3, 4, 6, 9, 12, 18, 36]
    assert [n for n in range(1, 31) if numbers.is_prime(n)] == [2, 3, 5, 7, 11, 13, 17, 19, 23, 29]
    assert numbers.first_shared_multiple(4, 6) == 12 and numbers.first_shared_multiple(3, 6) == 6
    assert numbers.greatest_shared_divisor(12, 18) == 6
    assert numbers.pair_count(12) == 3 and numbers.pair_count(36) == 5 and numbers.pair_count(1) == 1 and numbers.pair_count(7) == 1
    assert numbers.share_equally(12, 3) == 4 and numbers.share_equally(13, 3) is None
    assert numbers.product(0, 5) == 0 and numbers.product(5, 0) == 0 and numbers.product(7, 8) == 56
    assert numbers.count_up(4, 3) == [4, 8, 12]
    assert numbers.smallest_divisor_above_one(91) == 7
    assert numbers.is_square(36) and not numbers.is_square(35)


# --- End to end (needs the Godot binary: set GODOT, as CI does) -------------------------------

GODOT = os.environ.get("GODOT") or os.environ.get("GODOT_BIN")
needs_godot = pytest.mark.skipif(not GODOT or not shutil.which(GODOT) and not Path(GODOT or "").exists(), reason="set GODOT to the Godot 4.7.2 executable")


@needs_godot
@pytest.mark.parametrize("skill_id", ZONE4)
def test_end_to_end_zone_4_skill(skill_id: str, tmp_path: Path) -> None:
    assert run.main(["--skill", skill_id, "--n", "200", "--godot", GODOT, "--out", str(tmp_path)]) == 0
