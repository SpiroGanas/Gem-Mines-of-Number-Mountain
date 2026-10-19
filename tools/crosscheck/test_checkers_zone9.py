"""pytest: the Zone 9 checkers (sequences, figurate numbers, Fibonacci, Gauss's sum, proof without words,
Fib poems) accept correct problems and catch every kind of wrong one.

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
ZONE9 = sorted(skill_id for skill_id, skill in SKILLS.items() if skill["zone"] == 9)
PROOF_LABELS = {
    "staircases": "z9.proof.fact_staircases", "two_triangles": "z9.proof.fact_two_triangles",
    "odd_layers": "z9.proof.fact_odd_layers", "array_turn": "z9.proof.fact_array_turn",
    "fib_squares": "z9.proof.fact_fib_squares",
}


def D(mantissa: int, scale: int) -> dict:
    return {"mantissa": mantissa, "scale": scale}


def row(terms: list[int], blanks: list[int], style: str = "numbers", **extra) -> dict:
    return dict({"type": "pattern", "terms": terms, "blanks": blanks, "style": style}, **extra)


def example(prompt_line: str, prompt_params: dict, answer, answer_line: str, answer_params: dict) -> dict:
    return {"prompt_line_id": prompt_line, "prompt_params": prompt_params, "answer": answer,
            "answer_line_id": answer_line, "answer_params": answer_params}


def make(skill_id: str, prompt_line: str, prompt_params: dict, answer, distractors, *, visual=None, meta=None,
         model=None, ex=None, representation=None) -> dict:
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
        "params": dict(skill["params"]), "meta": meta or {},
    }


GOOD = {
    "next": make("seq.arith.next_term", "z9.seq.prompt_next", {"a": 3, "b": 7, "c": 11, "d": 15}, 19,
                 [("added_wrong_step", 20), ("repeated_last_term", 15)],
                 visual=row([3, 7, 11, 15, 19], [4], "crystals"), model=row([3, 7, 11, 15, 19], [4], "crystals", steps=[4, 4, 4, 4], step_op="plus"),
                 meta={"pattern_wall": {"terms": [3, 7, 11, 15, None], "tiles": [15, 19, 20]}},
                 ex=example("z9.seq.prompt_next", {"a": 2, "b": 4, "c": 6, "d": 8}, 10, "z9.hint.example_next", {"s": 2, "d": 8, "e": 10})),
    "missing": make("seq.arith.missing_term", "z9.seq.prompt_missing_2", {"a": 2, "b": 5, "d": 11, "e": 14}, 8,
                    [("added_wrong_step", 9), ("averaged_neighbors_wrong", 16)],
                    visual=row([2, 5, 8, 11, 14], [2]), model=row([2, 5, 8, 11, 14], [2], steps=[3, 3, 3, 3], step_op="plus"),
                    meta={"pattern_wall": {"terms": [2, 5, None, 11, 14], "tiles": [8, 9, 16]}},
                    ex=example("z9.seq.prompt_missing_1", {"a": 1, "c": 5, "d": 7, "e": 9}, 3, "z9.hint.example_missing", {"s": 2, "m": 3})),
    "rule": make("seq.arith.rule_describe", "z9.seq.prompt_rule", {"a": 5, "b": 8, "c": 11, "d": 14, "e": 17}, 3,
                 [("confused_start_and_step", 5), ("added_wrong_step", 4), ("added_wrong_step", 2)],
                 meta={"label_line": "z9.seq.rule_add"}, model=row([5, 8, 11, 14, 17], [], steps=[3, 3, 3, 3], step_op="plus"),
                 ex=example("z9.seq.prompt_rule", {"a": 2, "b": 4, "c": 6, "d": 8, "e": 10}, 2, "z9.hint.example_rule", {"s": 2})),
    "geometric": make("seq.geom.next_term", "z9.seq.prompt_next", {"a": 3, "b": 6, "c": 12, "d": 24}, 48,
                      [("added_ratio", 26), ("off_by_one_exponent", 96), ("continued_by_adding", 36)],
                      visual=row([3, 6, 12, 24, 48], [4], "crystals"), model=row([3, 6, 12, 24, 48], [4], steps=[2, 2, 2, 2], step_op="times"),
                      meta={"pad_digits": 4, "pattern_wall": {"terms": [3, 6, 12, 24, None], "tiles": [26, 36, 48, 96]}},
                      ex=example("z9.seq.prompt_next3", {"a": 1, "b": 10, "c": 100}, 1000, "z9.hint.example_geometric", {"r": 10, "d": 100, "e": 1000})),
    "classify": make("seq.arith_vs_geom.classify", "z9.seq.prompt_classify", {"a": 2, "b": 6, "c": 18, "d": 54}, "geometric",
                     [("swapped_types", "arithmetic"), ("missed_the_pattern", "neither")],
                     meta={"label_lines": {"arithmetic": "z9.classify.adds", "geometric": "z9.classify.multiplies", "neither": "z9.classify.neither"}},
                     visual=row([2, 6, 18, 54], []), model=row([2, 6, 18, 54], [], steps=[3, 3, 3], step_op="times"),
                     ex=example("z9.seq.prompt_classify", {"a": 1, "b": 3, "c": 5, "d": 7}, "arithmetic", "z9.hint.example_classify_adds", {"a": 1, "b": 3, "c": 5, "s": 2})),
    "triangle": make("fig.triangular.build", "z9.fig.prompt_triangle_wall", {"n": 6}, 21,
                     [("used_square", 36), ("off_by_one_n", 15), ("off_by_one_n", 28)],
                     visual=row([3, 6, 10, 15, 21], [4], "crystals", figure="triangle", first_index=2),
                     meta={"pattern_wall": {"terms": [3, 6, 10, 15, None], "tiles": [15, 21, 28, 36]}},
                     model={"type": "figurate", "kind": "triangle", "n": 6},
                     ex=example("z9.fig.prompt_triangle_wall", {"n": 4}, 10, "z9.hint.example_triangle", {"n": 4, "t": 10})),
    "square": make("fig.square.build", "z9.fig.prompt_square_wall", {"n": 5}, 25,
                   [("used_triangular", 15), ("off_by_one_n", 16), ("off_by_one_n", 36)],
                   visual=row([1, 4, 9, 16, 25], [4], "crystals", figure="square", first_index=1),
                   meta={"pattern_wall": {"terms": [1, 4, 9, 16, None], "tiles": [15, 16, 25, 36]}},
                   model={"type": "figurate", "kind": "square", "n": 5},
                   ex=example("z9.fig.prompt_square_wall", {"n": 3}, 9, "z9.hint.example_square", {"n": 3, "t": 9})),
    "two_triangles": make("fig.two_triangles.square", "z9.fig.prompt_two_triangles", {"n": 5, "m": 4}, 25,
                          [("added_same_triangular_twice_wrong_n", 30), ("used_triangular", 15), ("off_by_one_n", 16)],
                          visual={"type": "figurate", "kind": "two_triangles", "n": 5, "fitted": False},
                          model={"type": "figurate", "kind": "two_triangles", "n": 5, "fitted": True},
                          ex=example("z9.fig.prompt_two_triangles", {"n": 3, "m": 2}, 9, "z9.hint.example_two_triangles", {"n": 3, "m": 2, "t": 9})),
    "fib_next": make("fib.sequence.next_term", "z9.fib.prompt_next", {"a": 3, "b": 5, "c": 8, "d": 13}, 21,
                     [("added_wrong_pair", 18), ("doubled_last", 26)],
                     visual=row([3, 5, 8, 13, 21], [4], "crystals"), model={"type": "fib_squares", "terms": [1, 1, 2, 3, 5, 8, 13]},
                     meta={"pattern_wall": {"terms": [3, 5, 8, 13, None], "tiles": [18, 21, 26]}},
                     ex=example("z9.fib.prompt_next", {"a": 1, "b": 2, "c": 3, "d": 5}, 8, "z9.hint.example_fib_next", {"c": 3, "d": 5, "e": 8})),
    "fib_missing": make("fib.sequence.missing_term", "z9.fib.prompt_missing_2", {"a": 5, "b": 8, "d": 21, "e": 34}, 13,
                        [("added_wrong_pair", 29), ("doubled_last", 16)],
                        visual=row([5, 8, 13, 21, 34], [2]), model={"type": "fib_squares", "terms": [1, 1, 2, 3, 5, 8, 13, 21]},
                        ex=example("z9.fib.prompt_missing_1", {"a": 2, "c": 5, "d": 8, "e": 13}, 3, "z9.hint.example_fib_missing", {"m": 3})),
    "ratio": make("fib.ratio.converge", "z9.fib.prompt_ratio", {"a": 8, "b": 13}, D(163, 2),
                  [("inverted_ratio", D(62, 2)), ("place_shift", D(163, 1)), ("rounded_down", D(162, 2))],
                  visual={"type": "fib_squares", "terms": [1, 1, 2, 3, 5, 8, 13]}, model={"type": "fib_squares", "terms": [1, 1, 2, 3, 5, 8, 13]},
                  meta={"decimal_places": 2},
                  ex=example("z9.fib.prompt_ratio", {"a": 5, "b": 8}, D(16, 1), "z9.hint.example_ratio", {"a": 5, "b": 8, "d": D(16, 1)})),
    "gauss": make("gauss.sum.pairing", "z9.gauss.prompt_pairs", {"a": 1, "b": 2, "n": 10}, 55,
                  [("forgot_halve", 110), ("used_n_squared", 100), ("off_by_one_n", 45)],
                  visual={"type": "pairing", "n": 10}, model={"type": "pairing", "n": 10},
                  ex=example("z9.gauss.prompt_pairs", {"a": 1, "b": 2, "n": 4}, 10, "z9.hint.example_gauss", {"n": 4, "p": 5, "d": 20, "t": 10})),
    "formula": make("gauss.sum.formula", "z9.gauss.prompt_formula", {"a": 1, "b": 2, "n": 40}, 820,
                    [("forgot_halve", 1640), ("used_n_squared", 1600), ("off_by_one_n", 780)],
                    meta={"pad_digits": 4}, model={"type": "pairing", "n": 40},
                    ex=example("z9.gauss.prompt_formula", {"a": 1, "b": 2, "n": 30}, 465, "z9.hint.example_gauss", {"n": 30, "p": 31, "d": 930, "t": 465})),
    "proof": make("proof.words.match", "z9.proof.prompt", {}, "staircases",
                  [("wrong_diagram", "array_turn"), ("wrong_diagram", "odd_layers"), ("wrong_diagram", "two_triangles")],
                  visual={"type": "proof", "diagram": "staircases", "n": 4, "fitted": False},
                  model={"type": "proof", "diagram": "staircases", "n": 4, "fitted": True},
                  meta={"label_lines": PROOF_LABELS, "proof_board": {"diagram": "staircases", "n": 4, "choices": ["array_turn", "odd_layers", "staircases", "two_triangles"]}},
                  ex=example("z9.proof.prompt", {}, "fib_squares", "z9.proof.fact_fib_squares", {})),
    "poem": make("fib.poem.syllables", "z9.poem.prompt", {"k": 4, "n": 3}, ["crystal", "glow"],
                 [("wrong_line_count", ["sun", "moon"]), ("counted_words", ["sky", "river", "sun"]), ("off_by_one_syllable", ["glowing", "gem", "star"])],
                 visual={"type": "poem_shape", "lines": [1, 1, 2, 3, 5, 8], "highlight": 3, "counts": False},
                 model={"type": "poem_shape", "lines": [1, 1, 2, 3, 5, 8], "highlight": 3, "counts": True},
                 meta={"array_label": "words"},
                 ex=example("z9.poem.prompt", {"k": 6, "n": 8}, ["watermelon", "helicopter"], "z9.hint.example_poem", {"k": 6, "n": 8})),
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
    ("next", _set(["answer"], 18), "wrong next term"),
    ("next", _set(["distractors", 1, "value"], 11), "repeated the wrong term"),
    ("next", _set(["meta", "pattern_wall", "tiles"], [15, 20]), "answer tile missing from the wall"),
    ("next", _set(["prompt_params", "c"], 12), "uneven steps"),
    ("missing", _set(["answer"], 9), "wrong missing term"),
    ("missing", _set(["prompt_line_id"], "z9.seq.prompt_missing_3"), "prompt names the wrong gap"),
    ("missing", _set(["distractors", 1, "value"], 8), "averaged mistake equal to the answer"),
    ("rule", _set(["answer"], 5), "gave the start as the rule"),
    ("rule", _set(["meta", "label_line"], None), "rule buttons without their line"),
    ("geometric", _set(["answer"], 30), "added the difference"),
    ("geometric", _set(["distractors", 1, "value"], 72), "wrong extra power"),
    ("geometric", _set(["meta", "pad_digits"], 3), "pad too short"),
    ("classify", _set(["answer"], "arithmetic"), "wrong kind"),
    ("classify", _set(["prompt_params", "d"], 50), "neither kind"),
    ("triangle", _set(["answer"], 36), "gave the square"),
    ("triangle", _set(["meta", "pattern_wall", "terms"], [3, 6, 10, 14, None]), "wrong triangle on the wall"),
    ("square", _set(["answer"], 21), "gave the triangle"),
    ("two_triangles", _set(["answer"], 30), "doubled one staircase"),
    ("two_triangles", _set(["visual", "fitted"], True), "picture already fitted"),
    ("fib_next", _set(["answer"], 26), "doubled the last"),
    ("fib_next", _set(["prompt_params", "c"], 9), "not Fibonacci numbers"),
    ("fib_missing", _set(["answer"], 29), "added the neighbors"),
    ("ratio", _set(["answer"], D(162, 2)), "a tie rounded to even or down"),
    ("ratio", _set(["answer"], D(1630, 3)), "trailing zero"),
    ("ratio", _set(["distractors", 0, "value"], D(61, 2)), "inverted ratio rounded down"),
    ("ratio", _set(["prompt_params", "b"], 21), "not neighbors"),
    ("gauss", _set(["answer"], 110), "forgot to halve"),
    ("gauss", _set(["distractors", 2, "value"], 66), "off by one the wrong way"),
    ("formula", _set(["prompt_params", "n"], 12), "too small for the formula"),
    ("formula", _set(["meta", "pad_digits"], 3), "pad too short for the formula"),
    ("proof", _set(["answer"], "pentagon"), "unknown diagram"),
    ("proof", _set(["distractors", 0, "value"], "staircases"), "the answer offered as wrong"),
    ("proof", _set(["meta", "label_lines", "staircases"], "z9.proof.fact_odd_layers"), "wrong fact line"),
    ("proof", _set(["visual", "n"], 9), "picture too big"),
    ("poem", _set(["answer"], ["crystal", "sun", "moon"]), "four syllables for a three-syllable line"),
    ("poem", _set(["answer"], ["crystal", "glimmer"]), "word not in the bank"),
    ("poem", _set(["prompt_params", "n"], 5), "line 4 needs three"),
    ("poem", _set(["prompt_line_id"], "z9.poem.prompt_single"), "singular prompt for three syllables"),
    ("poem", _set(["distractors", 1, "value"], ["sky", "sun", "red"]), "counted words that fit"),
    ("poem", _set(["distractors", 2, "value"], ["galaxy", "watermelon"]), "seven is not one off"),
]


@pytest.mark.parametrize("name,change,why", TAMPERS, ids=[t[2] for t in TAMPERS])
def test_tampered_problems_fail(name: str, change, why: str) -> None:
    assert errors_of(tampered(name, change)) != [], why


def test_every_zone_9_skill_has_a_checker_and_a_hand_written_problem() -> None:
    assert len(ZONE9) == 15
    covered = {problem["skill_id"] for problem in GOOD.values()}
    assert set(ZONE9) == covered
    for skill_id in ZONE9:
        assert SKILLS[skill_id]["generator"] in run.CHECKERS


def test_zone9_pictures_are_checked() -> None:
    assert common.check_visual(row([1, 2, 3], [1]), "v") == []
    assert common.check_visual(row([1, 2, 3, 4, 5, 6, 7], []), "v") != []  # too many tiles
    assert common.check_visual(row([1, 2, 3], [3]), "v") != []  # blank off the row
    assert common.check_visual(row([1, 2, 3], [], steps=[1], step_op="plus"), "v") != []
    assert common.check_visual({"type": "figurate", "kind": "hexagon", "n": 3}, "v") != []
    assert common.check_visual({"type": "pairing", "n": 101}, "v") != []
    assert common.check_visual({"type": "fib_squares", "terms": [1, 1, 2, 4]}, "v") != []
    assert common.check_visual({"type": "poem_shape", "lines": [1, 1, 2], "highlight": 3, "counts": False}, "v") != []
