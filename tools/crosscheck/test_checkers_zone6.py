"""pytest: the Zone 6 checkers (GCF, LCM, gears, simplest form) accept correct problems and catch every
kind of wrong one.

Each valid problem is written out by hand from the skill definitions (never produced by the GDScript
generators), then tampered with. If a checker stopped checking something, a tamper would pass.
"""
from __future__ import annotations

import copy

import pytest
import run
from checkers import common, gcf_lcm, gears, numbers, simplify

SKILLS = {skill["id"]: skill for skill in run.load_skills()}
ALLOWED = run.allowed_misconceptions()
YES_NO = {"true": "ui.common.yes", "false": "ui.common.no"}
ZONE6 = sorted(skill_id for skill_id, skill in SKILLS.items() if skill["zone"] == 6)


def make(skill_id: str, prompt_line: str, prompt_params: dict, answer, distractors, *, visual=None, meta=None,
         model=None, example=None, representation=None) -> dict:
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
            {"kind": "worked_example", "line_id": "bolt.hint.worked_example", "params": {}, "visual": {}, "example": example},
            {"kind": "easier_problem", "line_id": "bolt.hint.easier", "params": {}, "visual": {}, "easier_params": {"difficulty": -1}},
        ],
        "params": dict(skill["params"]), "meta": meta or {},
    }


def example(prompt_line: str, prompt_params: dict, answer, answer_line: str, answer_params: dict) -> dict:
    return {"prompt_line_id": prompt_line, "prompt_params": prompt_params, "answer": answer,
            "answer_line_id": answer_line, "answer_params": answer_params}


def lists(kind: str, rows: list, marked: list) -> dict:
    return {"type": "lists", "kind": kind, "rows": rows, "marked": marked}


F8 = {"n": 8, "items": [1, 2, 4, 8]}
F12 = {"n": 12, "items": [1, 2, 3, 4, 6, 12]}
F18 = {"n": 18, "items": [1, 2, 3, 6, 9, 18]}
F6 = {"n": 6, "items": [1, 2, 3, 6]}

GOOD = {
    "common_factors": make("gcf.list.common_factors", "z6.gcf.prompt_common", {"a": 8, "b": 12}, [1, 2, 4],
                           [("included_non_factor", [1, 2, 3, 4]), ("missed_largest", [1, 2]), ("factors_of_one_number", [1, 2, 4, 8])],
                           visual={"type": "gears", "teeth": [8, 12]}, model=lists("factors", [F8, F12], [1, 2, 4]),
                           example=example("z6.gcf.prompt_common", {"a": 6, "b": 9}, [1, 3], "z6.hint.example_common", {"g": 3})),
    "gcf": make("gcf.find.by_listing", "z6.gcf.prompt_gcf", {"a": 12, "b": 18}, 6,
                [("picked_smallest_common", 2), ("picked_prime_factor_only", 3), ("picked_lcm", 36), ("picked_smaller_number", 12)],
                visual=lists("factors", [F12, F18], []), model=lists("factors", [F12, F18], [1, 2, 3, 6]),
                example=example("z6.gcf.prompt_gcf", {"a": 8, "b": 20}, 4, "z6.hint.example_gcf", {"a": 8, "b": 20, "g": 4})),
    "gcf_recipes": make("gcf.find.by_factor_tree", "z6.gcf.prompt_recipes", {"a": 12, "b": 18}, 6,
                        [("took_union", 36), ("picked_prime_factor_only", 3), ("multiplied_all_primes", 216)],
                        visual=lists("recipe", [{"n": 12, "items": [2, 2, 3], "lit": [0, 2]}, {"n": 18, "items": [2, 3, 3], "lit": [0, 1]}], []),
                        model=lists("recipe", [{"n": 12, "items": [2, 2, 3], "lit": [0, 2]}, {"n": 18, "items": [2, 3, 3], "lit": [0, 1]}], []),
                        example=example("z6.gcf.prompt_recipes", {"a": 20, "b": 30}, 10, "z6.hint.example_recipes_gcf", {"a": 20, "b": 30, "g": 10})),
    "coprime": make("gcf.coprime.identify", "z6.gcf.prompt_coprime", {"a": 9, "b": 15}, False, [("shared_even_only", True)],
                    meta={"label_lines": YES_NO},
                    model=lists("factors", [{"n": 9, "items": [1, 3, 9]}, {"n": 15, "items": [1, 3, 5, 15]}], [1, 3]),
                    example=example("z6.gcf.prompt_coprime", {"a": 8, "b": 9}, True, "z6.hint.example_coprime_yes", {"a": 8, "b": 9})),
    "common_multiples": make("lcm.list.common_multiples", "z6.lcm.prompt_common", {"k": 3, "a": 4, "b": 6}, [12, 24, 36],
                             [("off_by_one_multiple", [24, 36, 48]), ("multiples_of_one_number", [4, 8, 12]), ("listed_product_only", [24, 48, 72])],
                             meta={"tile_board": {"tiles": [72, 4, 36, 8, 12, 48, 24], "slots": 3, "ordered": False}},
                             visual={"type": "gears", "teeth": [4, 6]},
                             model=lists("multiples", [{"n": 4, "items": [4, 8, 12]}, {"n": 6, "items": [6, 12]}], [12]),
                             example=example("z6.lcm.prompt_common", {"k": 3, "a": 2, "b": 3}, [6, 12, 18], "z6.hint.example_common_multiples", {"a": 2, "b": 3, "l": 6})),
    "lcm": make("lcm.find.by_listing", "z6.lcm.prompt_lcm", {"a": 4, "b": 6}, 12,
                [("picked_product", 24), ("picked_gcf", 2), ("picked_sum", 10)],
                visual=lists("multiples", [{"n": 4, "items": [4, 8, 12]}, {"n": 6, "items": [6, 12]}], []),
                model=lists("multiples", [{"n": 4, "items": [4, 8, 12]}, {"n": 6, "items": [6, 12]}], [12]),
                example=example("z6.lcm.prompt_lcm", {"a": 3, "b": 5}, 15, "z6.hint.example_lcm", {"a": 3, "b": 5, "l": 15})),
    "lcm_recipes": make("lcm.find.by_factorization", "z6.lcm.prompt_recipes", {"a": 8, "b": 12}, 24,
                        [("took_intersection", 4), ("dropped_highest_power", 6), ("picked_product", 96)],
                        model=lists("recipe", [{"n": 8, "items": [2, 2, 2], "lit": [0, 1, 2]}, {"n": 12, "items": [2, 2, 3], "lit": [2]}], []),
                        example=example("z6.lcm.prompt_recipes", {"a": 12, "b": 18}, 36, "z6.hint.example_recipes_lcm", {"a": 12, "b": 18, "l": 36})),
    "relation": make("lcm.relation.gcf_times_lcm", "z6.lcm.prompt_relation", {"a": 6, "b": 8, "g": 2}, 24,
                     [("added_instead_of_multiplied", 12), ("picked_product", 48), ("picked_gcf", 2)],
                     model=lists("factors", [F6, F8], [1, 2]),
                     example=example("z6.lcm.prompt_relation", {"a": 4, "b": 10, "g": 2}, 20, "z6.hint.example_relation", {"a": 4, "b": 10, "p": 40, "g": 2, "l": 20})),
    "ratio_bench": make("gear.ratio.teeth", "z6.gear.prompt_ratio", {"a": 24, "k": 3}, 8,
                        [("inverted_ratio", 72), ("subtracted_teeth", 21), ("same_size_gear", 24)],
                        meta={"gear_bench": {"driver": 24, "turns": 3, "tray": [8, 21, 24, 72]}}, model=numbers.hops(3, 8, [24]),
                        example=example("z6.gear.prompt_ratio", {"a": 16, "k": 2}, 8, "z6.hint.example_ratio", {"a": 16, "b": 8, "k": 2})),
    "ratio_buttons": make("gear.ratio.teeth", "z6.gear.prompt_ratio", {"a": 36, "k": 4}, 9,
                          [("inverted_ratio", 144), ("subtracted_teeth", 32), ("same_size_gear", 36)], representation="pictorial",
                          visual={"type": "gears", "teeth": [36]}, model=numbers.hops(4, 9, [36]),
                          example=example("z6.gear.prompt_ratio", {"a": 24, "k": 2}, 12, "z6.hint.example_ratio", {"a": 24, "b": 12, "k": 2})),
    "sync": make("gear.sync.turns_to_align", "z6.gear.prompt_sync", {"a": 8, "b": 12}, 3,
                 [("used_gcf", 4), ("counted_other_gear", 2), ("teeth_not_turns", 24)],
                 visual={"type": "gears", "teeth": [8, 12], "marks": True},
                 model=lists("multiples", [{"n": 8, "items": [8, 16, 24]}, {"n": 12, "items": [12, 24]}], [24]),
                 example=example("z6.gear.prompt_sync", {"a": 6, "b": 4}, 2, "z6.hint.example_sync", {"a": 6, "l": 12, "t": 2})),
    "fraction": make("simplify.fraction.gcf", "z6.simplify.prompt_fraction", {"a": 12, "b": 18}, {"num": 2, "den": 3},
                     [("partially_simplified", {"num": 4, "den": 6}), ("divided_numerator_only", {"num": 2, "den": 18}), ("swapped_num_den", {"num": 3, "den": 2})],
                     visual={"type": "gears", "teeth": [18], "shaded": 12}, meta={"simplest_form": True}, model=lists("factors", [F12, F18], [1, 2, 3, 6]),
                     example=example("z6.simplify.prompt_fraction", {"a": 6, "b": 8}, {"num": 3, "den": 4}, "z6.hint.example_fraction", {"g": 2, "a": 6, "b": 8, "c": 3, "d": 4})),
    "ratio": make("simplify.ratio.gcf", "z6.simplify.prompt_ratio", {"a": 12, "b": 8}, {"a": 3, "b": 2},
                  [("partially_simplified", {"a": 6, "b": 4}), ("inverted_ratio", {"a": 2, "b": 3}), ("divided_one_term_only", {"a": 3, "b": 8})],
                  visual={"type": "gears", "teeth": [12, 8]}, meta={"simplest_form": True}, model=lists("factors", [F8, F12], [1, 2, 4]),
                  example=example("z6.simplify.prompt_ratio", {"a": 6, "b": 9}, {"a": 2, "b": 3}, "z6.hint.example_ratio_simplify", {"g": 3, "a": 6, "b": 9, "c": 2, "d": 3})),
}


def verdict(problem: dict) -> list[str]:
    return run.check_problem(problem, SKILLS[problem["skill_id"]], ALLOWED)


@pytest.mark.parametrize("name", sorted(GOOD))
def test_a_correct_problem_passes(name: str) -> None:
    assert verdict(copy.deepcopy(GOOD[name])) == []


def test_every_zone_6_skill_has_a_checker() -> None:
    assert len(ZONE6) == 14  # 12 Gear Works skills and the two fraction previews (FractionGenerator, checked in test_checkers_zone7.py)
    for skill_id in ZONE6:
        assert SKILLS[skill_id]["generator"] in run.CHECKERS


def _set(path: list, value):
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


def _drop(index: int):
    def edit(problem: dict) -> None:
        del problem["distractors"][index]
    return edit


TAMPERS = [
    ("common_factors", "a common factor left out of the answer", _set(["answer"], [1, 2])),
    ("common_factors", "extra board adds a factor of both", _distractor(0, [1, 2, 4, 8])),
    ("common_factors", "missed board keeps the GCF", _distractor(1, [1, 4])),
    ("common_factors", "factors of b instead of a", _distractor(2, [1, 2, 3, 4, 6, 12])),
    ("common_factors", "coprime pair", _set(["prompt_params", "b"], 9)),
    ("common_factors", "pictorial picture on a concrete problem", _set(["visual"], lists("factors", [F8, F12], []))),
    ("common_factors", "model marks too much", _set(["hint_steps", 1, "visual", "marked"], [1, 2, 4, 8])),
    ("gcf", "the LCM as the answer", _set(["answer"], 36)),
    ("gcf", "smallest common is 3", _distractor(0, 3)),
    ("gcf", "a missing mistake", _drop(3)),
    ("gcf", "names swapped", _name(1, "picked_lcm")),
    ("gcf", "a above b", _set(["prompt_params"], {"a": 18, "b": 12})),
    ("gcf", "b beyond the skill's range", _set(["prompt_params", "b"], 66)),
    ("gcf", "example states another GCF", _set(["hint_steps", 2, "example", "answer_params", "g"], 5)),
    ("gcf_recipes", "lit a prime they do not share", _set(["visual", "rows", 0, "lit"], [0, 1, 2])),
    ("gcf_recipes", "union reported as the product", _distractor(0, 216)),
    ("gcf_recipes", "abstract picture on a pictorial problem", _set(["visual"], {})),
    ("coprime", "called coprime", _set(["answer"], True)),
    ("coprime", "wrong mistake for two odd numbers", _name(0, "missed_common_factor")),
    ("coprime", "example says not coprime", _set(["hint_steps", 2, "example", "answer_line_id"], "z6.hint.example_coprime_no")),
    ("common_multiples", "answer starts at the product", _set(["answer"], [24, 48, 72])),
    ("common_multiples", "late board skips two", _distractor(0, [36, 48, 60])),
    ("common_multiples", "tiles missing one", _set(["meta", "tile_board", "tiles"], [4, 36, 8, 12, 48, 24])),
    ("common_multiples", "ordered slots", _set(["meta", "tile_board", "ordered"], True)),
    ("common_multiples", "k not the skill's count", _set(["prompt_params", "k"], 4)),
    ("lcm", "the GCF as the answer", _set(["answer"], 2)),
    ("lcm", "sum reported as the product", _distractor(2, 24)),
    ("lcm", "model marks the product", _set(["hint_steps", 1, "visual", "marked"], [24])),
    ("lcm_recipes", "union without the highest power", _set(["answer"], 12)),
    ("lcm_recipes", "dropped board is the GCF", _distractor(1, 4)),
    ("lcm_recipes", "lit the wrong row", _set(["hint_steps", 1, "visual", "rows", 1, "lit"], [0, 1, 2])),
    ("lcm_recipes", "coprime pair", _set(["prompt_params"], {"a": 8, "b": 9})),
    ("relation", "the prompt's GCF is wrong", _set(["prompt_params", "g"], 4)),
    ("relation", "added board off by one", _distractor(0, 13)),
    ("relation", "example product wrong", _set(["hint_steps", 2, "example", "answer_params", "p"], 41)),
    ("ratio_bench", "a gear that turns twice", _set(["answer"], 12)),
    ("ratio_bench", "tray missing the answer", _set(["meta", "gear_bench", "tray"], [21, 24, 72])),
    ("ratio_bench", "tray out of order", _set(["meta", "gear_bench", "tray"], [24, 8, 21, 72])),
    ("ratio_bench", "a picture on the bench problem", _set(["visual"], {"type": "gears", "teeth": [24]})),
    ("ratio_bench", "teeth not in the skill's list", _set(["prompt_params", "a"], 20)),
    ("ratio_buttons", "a bench on a pictorial problem", _set(["meta"], {"gear_bench": {"driver": 36, "turns": 4, "tray": [9, 32, 36, 144]}})),
    ("ratio_buttons", "subtracted board added instead", _distractor(1, 40)),
    ("ratio_buttons", "hops of the wrong size", _set(["hint_steps", 1, "visual"], numbers.hops(4, 8, [36]))),
    ("sync", "turns of the other gear as the answer", _set(["answer"], 2)),
    ("sync", "teeth board off", _distractor(2, 48)),
    ("sync", "no marks", _set(["visual"], {"type": "gears", "teeth": [8, 12]})),
    ("sync", "equal gears", _set(["prompt_params"], {"a": 8, "b": 8})),
    ("fraction", "not lowest terms", _set(["answer"], {"num": 4, "den": 6})),
    ("fraction", "halfway board with another value", _distractor(0, {"num": 4, "den": 9})),
    ("fraction", "top-only board divides the bottom too", _distractor(1, {"num": 2, "den": 3})),
    ("fraction", "swapped board not swapped", _distractor(2, {"num": 2, "den": 3})),
    ("fraction", "a fraction already in simplest form", _set(["prompt_params"], {"a": 5, "b": 7})),
    ("fraction", "shaded the bottom number", _set(["visual", "shaded"], 18)),
    ("ratio", "order turned around", _set(["answer"], {"a": 2, "b": 3})),
    ("fraction", "no simplest-form flag (6/9 would count as 2/3)", _set(["meta"], {})),
    ("ratio", "no simplest-form flag (6 : 4 would count as 3 : 2)", _set(["meta"], {})),
    ("ratio", "one-term board divides the second", _distractor(2, {"a": 12, "b": 2})),
    ("ratio", "model with the larger number first", _set(["hint_steps", 1, "visual"], lists("factors", [F12, F8], [1, 2, 4]))),
]


@pytest.mark.parametrize("name, what, tamper", TAMPERS, ids=[f"{name}: {what}" for name, what, _ in TAMPERS])
def test_a_tampered_problem_fails(name: str, what: str, tamper) -> None:
    problem = copy.deepcopy(GOOD[name])
    tamper(problem)
    assert verdict(problem), f"{name}: '{what}' was not caught"


def test_simplest_form_judges_by_form() -> None:
    # The partially simplified answer equals the answer in value; under meta.simplest_form it is still
    # a wrong answer, so the good problems pass and the same problem without the flag fails.
    assert common.same_answer({"num": 4, "den": 6}, {"num": 2, "den": 3})
    assert not common.same_answer({"num": 4, "den": 6}, {"num": 2, "den": 3}, simplest_form=True)
    assert not common.same_answer({"a": 6, "b": 4}, {"a": 3, "b": 2}, simplest_form=True)
    for name in ("fraction", "ratio"):
        assert verdict(copy.deepcopy(GOOD[name])) == []
        bare = copy.deepcopy(GOOD[name])
        bare["meta"] = {}
        assert any("equals the answer" in message for message in verdict(bare))


def test_the_independent_helpers() -> None:
    assert gcf_lcm.common_factors(12, 18) == [1, 2, 3, 6]
    assert gcf_lcm.largest_prime(12) == 3
    assert gcf_lcm.recipe_lists(12, 18, "shared")["rows"][0]["lit"] == [0, 2]
    assert gcf_lcm.recipe_lists(8, 12, "most")["rows"][1]["lit"] == [2]
    assert gears.turns_while(24, 8) == (3, 0)
    assert gears.turns_while(24, 16) == (1, 8)
    assert gears.teeth_until_marks_meet(8, 12) == 24
    assert simplify.largest_partial(12) == 6
    assert simplify.largest_partial(7) is None
