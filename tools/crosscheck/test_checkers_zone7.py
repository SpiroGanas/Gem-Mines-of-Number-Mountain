"""pytest: the Zone 7 checkers (fractions, decimals and percents, ratios, depths below zero) accept
correct problems and catch every kind of wrong one.

Each valid problem is written out by hand from the skill definitions (never produced by the GDScript
generators), then tampered with. If a checker stopped checking something, a tamper would pass.
"""
from __future__ import annotations

import copy

import pytest
import run
from checkers import common

SKILLS = {skill["id"]: skill for skill in run.load_skills()}
ALLOWED = run.allowed_misconceptions()
# The fraction preview skills were built with Zone 7 (FractionGenerator) and moved into Zone 6's file at
# the merge (approved by Spiro); they are still checked here with the other fraction skills.
PREVIEWS = ["fraction.part.of_whole", "fraction.unit.identify"]
ZONE7 = sorted([skill_id for skill_id, skill in SKILLS.items() if skill["zone"] == 7] + PREVIEWS)


def F(num: int, den: int) -> dict:
    return {"num": num, "den": den}


def D(mantissa: int, scale: int) -> dict:
    return {"mantissa": mantissa, "scale": scale}


def crystals(entries: list[tuple], shape: str = "crystal", wholes: int = 0, joiner: str = "") -> dict:
    picture = {"type": "crystals", "shape": shape, "crystals": [{"den": e[0], "lit": e[1], **({"second": e[2]} if len(e) > 2 else {})} for e in entries]}
    if wholes:
        picture["wholes"] = wholes
    if joiner:
        picture["joiner"] = joiner
    return picture


def grid(cells: int, entries: list[tuple[int, int]]) -> dict:
    return {"type": "crystal_grid", "cells": cells, "grids": [{"wholes": w, "lit": lit} for w, lit in entries]}


def gauge(low: int, high: int, markers: list[int], jumps: list[tuple[int, int]] | None = None) -> dict:
    picture = {"type": "depth_gauge", "min": low, "max": high, "labeled_every": 5, "markers": markers}
    if jumps:
        picture["jumps"] = [{"from": a, "to": b} for a, b in jumps]
    return picture


def example(prompt_line: str, prompt_params: dict, answer, answer_line: str, answer_params: dict) -> dict:
    return {"prompt_line_id": prompt_line, "prompt_params": prompt_params, "answer": answer,
            "answer_line_id": answer_line, "answer_params": answer_params}


def make(skill_id: str, prompt_line: str, prompt_params: dict, answer, distractors, *, visual=None, meta=None,
         model=None, ex=None, representation=None, params=None) -> dict:
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
            {"kind": "worked_example", "line_id": "bolt.hint.worked_example", "params": {}, "visual": {}, "example": ex},
            {"kind": "easier_problem", "line_id": "bolt.hint.easier", "params": {}, "visual": {}, "easier_params": {"difficulty": -1}},
        ],
        "params": dict(skill["params"], **(params or {})), "meta": meta or {},
    }


GOOD = {
    "unit": make("fraction.unit.identify", "z7.unit.prompt", {"den": 4}, F(1, 4),
                 [("inverted", F(4, 1)), ("counted_shaded_as_denominator", F(1, 3))],
                 visual=crystals([(4, 1)]), model=crystals([(4, 1)]),
                 ex=example("z7.unit.prompt", {"den": 6}, F(1, 6), "z7.hint.example_unit", {"den": 6})),
    "part": make("fraction.part.of_whole", "z7.part.prompt_words", {"num": 6, "den": 8}, F(3, 4),
                 [("unshaded_count", F(2, 8)), ("off_by_one_numerator", F(7, 8)), ("inverted", F(8, 6))],
                 meta={"shown": F(6, 8)}, model=crystals([(8, 6)]), representation="abstract",
                 ex=example("z7.part.prompt_words", {"num": 2, "den": 5}, F(2, 5), "z7.hint.example_part", {"num": 2, "den": 5})),
    "line": make("fraction.number_line.place", "z7.line.prompt", {"den": 4}, F(3, 4),
                 [("counted_ticks_not_gaps", F(3, 5)), ("inverted", F(4, 3))],
                 visual={"type": "fraction_line", "den": 4, "wholes": 1, "ticks": 5, "marker": F(3, 4)},
                 model={"type": "fraction_line", "den": 4, "wholes": 1, "ticks": 5, "marker": F(3, 4)}, meta={"shown": F(3, 4)},
                 ex=example("z7.line.prompt", {"den": 3}, F(1, 3), "z7.hint.example_part", {"num": 1, "den": 3})),
    "equiv": make("fraction.equivalent.build", "z7.equiv.prompt_num", {"a": 2, "b": 3, "c": 12}, 8,
                  [("added_to_both", 11), ("copied_numerator", 2)], representation="abstract",
                  meta={"equiv": {"a": 2, "b": 3, "k": 4}}, model=crystals([(3, 2), (12, 8)], joiner="versus"),
                  ex=example("z7.equiv.prompt_den", {"a": 1, "b": 2, "m": 3}, 6, "z7.hint.example_equiv", {"a": 1, "b": 2, "k": 3, "m": 3, "c": 6})),
    "compare": make("fraction.compare.like_den", "z7.compare.prompt", {"a": 3, "b": 8, "c": 5, "d": 8}, "<",
                    [("compared_denominators", "="), ("reversed_symbol", ">")], representation="abstract",
                    model=crystals([(8, 3), (8, 5)], "bar", joiner="versus"),
                    ex=example("z7.compare.prompt", {"a": 2, "b": 5, "c": 1, "d": 5}, ">", "z7.hint.example_compare_like", {"a": 2, "b": 5, "c": 1, "d": 5, "symbol": ">"})),
    "add": make("fraction.add.like_den", "z7.add.prompt", {"a": 1, "b": 6, "c": 3, "d": 6}, F(2, 3),
                [("added_denominators", F(4, 12)), ("off_by_one_numerator", F(5, 6))], representation="abstract",
                model=crystals([(6, 1, 3)]),
                ex=example("z7.add.prompt", {"a": 1, "b": 5, "c": 2, "d": 5}, F(3, 5), "z7.hint.example_add", {"a": 1, "b": 5, "c": 2, "d": 5, "sum": F(3, 5)})),
    "mixed": make("fraction.mixed.convert", "z7.mixed.prompt_to_mixed", {"top": 7, "den": 3}, {"whole": 2, "num": 1, "den": 3},
                  [("dropped_whole", {"whole": 0, "num": 1, "den": 3}), ("swapped_quotient_remainder", {"whole": 1, "num": 2, "den": 3})],
                  representation="abstract", meta={"mixed": {"whole": 2, "num": 1, "den": 3}}, model=crystals([(3, 1)], wholes=2),
                  ex=example("z7.mixed.prompt_to_improper", {"w": 1, "num": 1, "den": 2}, F(3, 2), "z7.hint.example_mixed", {"w": 1, "num": 1, "den": 2, "top": 3, "parts": 2})),
    "tenths": make("decimal.tenths.read", "z7.tenths.prompt_words", {"w": 2, "k": 3}, D(23, 1),
                   [("place_shift", D(23, 2)), ("read_as_whole", D(23, 0))], representation="abstract",
                   meta={"decimal_places": 1}, model=crystals([(10, 3)], wholes=2),
                   ex=example("z7.tenths.prompt_words", {"w": 0, "k": 7}, D(7, 1), "z7.hint.example_tenths", {"w": 0, "k": 7, "d": D(7, 1)})),
    "hundredths": make("decimal.hundredths.read", "z7.hundredths.prompt_grid", {"w": 0, "k": 5}, D(5, 2),
                       [("place_shift", D(5, 1)), ("read_as_whole", D(5, 0))], representation="pictorial",
                       meta={"decimal_places": 2}, visual=grid(100, [(0, 5)]), model=grid(100, [(0, 5)]),
                       ex=example("z7.hundredths.prompt_words", {"w": 1, "k": 25}, D(125, 2), "z7.hint.example_hundredths", {"w": 1, "k": 25, "d": D(125, 2)})),
    "decfrac": make("decimal.fraction.convert", "z7.decfrac.prompt", {"num": 3, "den": 4}, D(75, 2),
                    [("wrote_numerator_as_decimal", D(3, 1)), ("place_shift", D(75, 1))],
                    meta={"decimal_places": 2}, model=grid(100, [(0, 75)]),
                    ex=example("z7.decfrac.prompt", {"num": 1, "den": 2}, D(5, 1), "z7.hint.example_decfrac", {"num": 1, "den": 2, "k": 50, "d": D(5, 1)})),
    "deccmp": make("decimal.compare.order", "z7.deccmp.prompt", {"a": D(5, 1), "b": D(45, 2)}, ">",
                   [("longer_is_bigger", "<")], representation="abstract", model=grid(100, [(0, 50), (0, 45)]),
                   ex=example("z7.deccmp.prompt", {"a": D(23, 1), "b": D(145, 2)}, ">", "z7.hint.example_deccmp", {"a": D(23, 1), "b": D(145, 2), "symbol": ">"})),
    "percent": make("percent.of_hundred.read", "z7.percent.prompt", {}, 37,
                    [("counted_unlit", 63), ("place_shift", 3)], visual=grid(100, [(0, 37)]), model=grid(100, [(0, 37)]),
                    meta={"percent": True},
                    ex=example("z7.percent.prompt", {}, 12, "z7.hint.example_percent", {"p": 12})),
    "pctfrac": make("percent.fraction.convert", "z7.pctfrac.prompt", {"num": 3, "den": 4}, 75,
                    [("wrote_numerator_as_percent", 3), ("place_shift", 7)], model=grid(100, [(0, 75)]), meta={"percent": True},
                    ex=example("z7.pctfrac.prompt", {"num": 1, "den": 5}, 20, "z7.hint.example_pctfrac", {"num": 1, "den": 5, "p": 20})),
    "ratio": make("ratio.describe.part_part", "z7.ratio.prompt", {"a": 2, "b": 3}, {"a": 2, "b": 3},
                  [("part_to_whole", {"a": 2, "b": 5}), ("inverted_ratio", {"a": 3, "b": 2})],
                  visual={"type": "ore_mix", "a": 2, "b": 3}, model={"type": "ore_mix", "a": 2, "b": 3},
                  ex=example("z7.ratio.prompt", {"a": 1, "b": 4}, {"a": 1, "b": 4}, "z7.hint.example_ratio", {"a": 1, "b": 4, "r": {"a": 1, "b": 4}})),
    "alloy": make("ratio.scale.alloy", "z7.alloy.prompt", {"a": 2, "b": 3, "c": 8}, 12,
                  [("added_instead_of_scaled", 9), ("scaled_one_part", 3)],
                  meta={"alloy": {"a": 2, "b": 3, "given": 8, "max": 18}}, model={"type": "ore_mix", "a": 8, "b": 12, "groups": 4},
                  ex=example("z7.alloy.prompt", {"a": 1, "b": 2, "c": 3}, 6, "z7.hint.example_alloy", {"a": 1, "b": 2, "c": 3, "k": 3, "t": 6})),
    "depth_read": make("negative.depth.read", "z7.depth.prompt_read", {}, -15,
                       [("dropped_sign", 15), ("off_by_one", -14)], meta={"signed": True},
                       visual=gauge(-20, 10, [-15]), model=gauge(-20, 10, [-15]),
                       ex=example("z7.depth.prompt_read", {}, -7, "z7.hint.example_depth_below", {"m": 7, "d": -7})),
    "depth_compare": make("negative.depth.compare", "z7.depth.prompt_compare", {"a": -12, "b": -7}, -7,
                          [("bigger_magnitude_bigger", -12)], visual=gauge(-20, 10, [-12, -7]), model=gauge(-20, 10, [-12, -7]),
                          ex=example("z7.depth.prompt_compare", {"a": 3, "b": -9}, 3, "z7.hint.example_depth_compare", {"a": 3, "b": -9})),
    "depth_move": make("negative.depth.move", "z7.depth.prompt_down", {"s": 5, "t": 12}, -7,
                       [("wrong_direction", 17), ("dropped_sign", 7)],
                       meta={"signed": True, "depth_gauge": {"min": -30, "max": 30, "start": 5}},
                       model=gauge(-10, 10, [5, -7], [(5, -7)]),
                       ex=example("z7.depth.prompt_up", {"s": -9, "t": 4}, -5, "z7.hint.example_move_up", {"s": -9, "t": 4, "e": -5})),
}


def errors_of(problem: dict) -> list[str]:
    return run.check_problem(problem, SKILLS[problem["skill_id"]], ALLOWED)


@pytest.mark.parametrize("name", sorted(GOOD))
def test_hand_written_problems_pass(name: str) -> None:
    assert errors_of(GOOD[name]) == []


def tampered(name: str, change) -> dict:
    problem = copy.deepcopy(GOOD[name])
    change(problem)
    return problem


def _set(path: list, value):
    def change(problem: dict) -> None:
        node = problem
        for key in path[:-1]:
            node = node[key]
        node[path[-1]] = value
    return change


TAMPERS = [
    ("unit", _set(["answer"], F(1, 3)), "wrong unit fraction"),
    ("unit", _set(["distractors", 0, "value"], F(1, 4)), "distractor equal to the answer"),
    ("part", _set(["answer"], F(6, 8)), "not in lowest terms"),
    ("part", _set(["distractors", 1, "value"], F(5, 6)), "miscount over the wrong bottom"),
    ("part", _set(["distractors", 0, "value"], F(6, 8)), "an equal fraction offered as wrong"),
    ("line", _set(["visual", "ticks"], 4), "tick count is not den + 1"),
    ("line", _set(["distractors", 0, "value"], F(3, 4)), "ticks mistake equal to the answer"),
    ("equiv", _set(["answer"], 9), "wrong missing top"),
    ("equiv", _set(["distractors", 0, "value"], 10), "wrong added_to_both"),
    ("compare", _set(["answer"], ">"), "symbol the wrong way"),
    ("compare", _set(["prompt_params", "c"], 3), "equal fractions"),
    ("add", _set(["answer"], F(4, 12)), "added the bottoms"),
    ("add", _set(["distractors", 0, "value"], F(4, 6)), "added_denominators equals the answer"),
    ("mixed", _set(["answer"], {"whole": 2, "num": 2, "den": 3}), "wrong mixed number"),
    ("tenths", _set(["answer"], D(230, 2)), "trailing zero"),
    ("tenths", _set(["answer"], D(32, 1)), "wrong tenths"),
    ("hundredths", _set(["meta", "decimal_places"], 1), "wrong number of places"),
    ("decfrac", _set(["answer"], D(7, 1)), "wrong conversion"),
    ("deccmp", _set(["answer"], "<"), "wrong decimal symbol"),
    ("deccmp", _set(["distractors"], [{"value": "<", "misconception": "ignored_whole"}]), "misnamed mistake"),
    ("percent", _set(["answer"], 63), "counted the dark cells"),
    ("pctfrac", _set(["answer"], 34), "wrong percent"),
    ("ratio", _set(["answer"], {"a": 4, "b": 6}), "ratio not in lowest terms"),
    ("ratio", _set(["answer"], {"a": 3, "b": 2}), "ratio the wrong way round"),
    ("alloy", _set(["answer"], 11), "wrong tin"),
    ("alloy", _set(["meta", "alloy", "max"], 10), "hopper too small"),
    ("depth_read", _set(["answer"], 15), "dropped the sign"),
    ("depth_read", _set(["meta", "signed"], False), "no minus key"),
    ("depth_compare", _set(["answer"], -12), "deeper is not greater"),
    ("depth_move", _set(["answer"], 17), "went the wrong way"),
    ("depth_move", _set(["meta", "depth_gauge", "start"], 4), "ride starts elsewhere"),
    ("depth_move", _set(["prompt_params", "s"], 0.5), "a float in the prompt"),
]


@pytest.mark.parametrize("name,change,why", TAMPERS, ids=[t[2] for t in TAMPERS])
def test_tampered_problems_fail(name: str, change, why: str) -> None:
    assert errors_of(tampered(name, change)) != [], why


def test_every_zone_7_skill_has_a_checker_and_a_hand_written_problem_family() -> None:
    assert len(ZONE7) == 20
    assert [SKILLS[skill_id]["zone"] for skill_id in PREVIEWS] == [6, 6]
    covered = {problem["skill_id"].split(".")[0] for problem in GOOD.values()}
    assert {skill_id.split(".")[0] for skill_id in ZONE7} <= covered
    for skill_id in ZONE7:
        assert SKILLS[skill_id]["generator"] in run.CHECKERS


def test_answers_compare_by_exact_value() -> None:
    assert common.same_answer(F(2, 4), F(1, 2))
    assert common.same_answer(D(50, 2), D(5, 1))
    assert common.same_answer(D(5, 1), F(1, 2))
    assert common.same_answer({"whole": 1, "num": 1, "den": 2}, F(3, 2))
    assert common.same_answer({"a": 4, "b": 6}, {"a": 2, "b": 3})
    assert not common.same_answer(F(2, 4), F(1, 2), simplest_form=True)
    assert not common.same_answer(F(3, 1), 3)
    assert common.exact_value(D(1, 1)) + common.exact_value(D(2, 1)) == common.exact_value(D(3, 1))  # 0.1 + 0.2 is 0.3 exactly


def test_zone7_pictures_are_checked() -> None:
    assert common.check_visual(crystals([(4, 3)]), "v") == []
    assert common.check_visual(crystals([(4, 5)]), "v") != []  # more lit than shards
    assert common.check_visual(crystals([(4, 1)], shape="hexagon"), "v") != []
    assert common.check_visual(grid(100, [(0, 101)]), "v") != []
    assert common.check_visual(gauge(-10, 10, [-11]), "v") != []
    assert common.check_visual(gauge(0, 10, [5]), "v") != []  # a gauge needs a part below zero
    assert common.check_visual({"type": "ore_mix", "a": 4, "b": 6, "groups": 2}, "v") == []
    assert common.check_visual({"type": "ore_mix", "a": 4, "b": 6, "groups": 4}, "v") != []
    assert common.check_visual({"type": "fraction_line", "den": 3, "wholes": 1, "ticks": 4, "marker": F(4, 3)}, "v") != []


def test_a_crystal_to_light_must_reach_the_answer() -> None:
    good = make("fraction.part.of_whole", "z7.part.prompt_light", {"num": 2, "den": 6}, F(1, 3), [], meta={"crystal": {"den": 6}})
    assert common.check_input_meta(good) == []
    good["meta"]["crystal"]["den"] = 5
    assert common.check_input_meta(good) != []
    good["meta"]["crystal"]["den"] = 14
    assert common.check_input_meta(good) != []
