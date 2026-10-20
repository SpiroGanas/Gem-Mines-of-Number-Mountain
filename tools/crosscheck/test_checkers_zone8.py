"""pytest: the Zone 8 checkers (powers and roots, bases, scientific notation, the lever) accept correct
problems and catch every kind of wrong one.

Each valid problem is written out by hand from the skill definitions (never produced by the GDScript
generators), then tampered with. If a checker stopped checking something, a tamper would pass.
"""
from __future__ import annotations

import copy

import pytest
import run
from checkers import bases, common, sci_notation

SKILLS = {skill["id"]: skill for skill in run.load_skills()}
ALLOWED = run.allowed_misconceptions()
ZONE8 = sorted(skill_id for skill_id, skill in SKILLS.items() if skill["zone"] == 8)


def tower(b: int, e: int, values: bool) -> dict:
    return {"type": "power_tower", "base": b, "exp": e, "values": values}


def card(b: int, e: int) -> dict:
    return {"type": "notation", "form": "power", "base": b, "exp": e}


def calc(op: str, terms: list[int]) -> dict:
    return {"op": op, "terms": terms}


def num(base: int, digits: list[int]) -> dict:
    return {"base": base, "digits": digits}


def sci(m: int, scale: int, e: int) -> dict:
    return {"mantissa": m, "scale": scale, "exp": e}


def lamps(base: int, rows: list, places: int, style: str, plus: bool = False) -> dict:
    picture = {"type": "lamps", "base": base, "rows": rows, "places": places, "style": style, "show_places": True}
    if plus:
        picture["plus"] = True
    return picture


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


VALUE_EX = example("z8.evaluate.prompt", {"b": 2, "e": 3}, 8, "z8.hint.example_value", {"b": 2, "e": 3, "v": 8})

GOOD = {
    "repeat": make("exp.repeated_mult.read", "z8.repeat.prompt", {"b": 3, "e": 4}, calc("mul", [3, 3, 3, 3]), [
        ("multiplied_base_by_exp", calc("mul", [3, 4])), ("added_base_exp_times", calc("add", [3, 3, 3, 3])),
        ("swapped_base_exp", calc("mul", [4, 4, 4])), ("off_by_one_exponent", calc("mul", [3, 3, 3, 3, 3]))],
        visual=tower(3, 4, False), model=tower(3, 4, True),
        ex=example("z8.repeat.prompt", {"b": 2, "e": 3}, calc("mul", [2, 2, 2]), "z8.hint.example_repeat", {"b": 2, "e": 3})),
    "evaluate": make("exp.evaluate.small", "z8.evaluate.prompt_tower", {"b": 3, "e": 4}, 81, [
        ("multiplied_base_by_exp", 12), ("off_by_one_exponent", 243), ("off_by_one_exponent", 27), ("swapped_base_exp", 64)],
        visual=tower(3, 4, False), model=tower(3, 4, True), ex=VALUE_EX),
    "square": make("exp.square.numbers", "z8.square.prompt_array", {"n": 7}, 49, [
        ("doubled", 14), ("off_by_one_square", 64), ("off_by_one_square", 36)],
        visual={"type": "array", "rows": 7, "cols": 7}, model={"type": "array", "rows": 7, "cols": 7, "outline_rows": True},
        ex=example("z8.square.prompt", {"n": 4}, 16, "z8.hint.example_square", {"n": 4, "v": 16})),
    "cube": make("exp.cube.numbers", "z8.cube.prompt_blocks", {"n": 3}, 27, [("tripled", 9)],
                 visual={"type": "cube_blocks", "n": 3}, model={"type": "cube_blocks", "n": 3},
                 ex=example("z8.cube.prompt", {"n": 2}, 8, "z8.hint.example_cube", {"n": 2, "v": 8})),
    "root": make("root.square.perfect", "z8.root.prompt", {"n": 144}, 12, [
        ("halved", 72), ("off_by_one_root", 13), ("off_by_one_root", 11)],
        visual={"type": "notation", "form": "root", "n": 144}, model={"type": "notation", "form": "root", "n": 144},
        representation="abstract",
        ex=example("z8.root.prompt", {"n": 9}, 3, "z8.hint.example_root", {"r": 3, "n": 9})),
    "ride": make("exp.powers_of_two.list", "z8.two.prompt_ride", {"n": 32}, 5, [
        ("off_by_one_exponent", 6), ("off_by_one_exponent", 4)],
        meta={"tower": {"base": 2, "floors": 10, "start": 0}}, model=tower(2, 5, True),
        ex=example("z8.two.prompt_ride", {"n": 8}, 3, "z8.hint.example_floor", {"k": 3, "n": 8})),
    "two": make("exp.powers_of_two.list", "z8.evaluate.prompt", {"b": 2, "e": 5}, 32, [
        ("off_by_one_exponent", 64), ("off_by_one_exponent", 16), ("added_two", 18)],
        visual=card(2, 5), meta={"pad_digits": 4}, model=tower(2, 5, True), representation="abstract", ex=VALUE_EX),
    "ten": make("exp.powers_of_ten.list", "z8.evaluate.prompt", {"b": 10, "e": 3}, 1000, [
        ("off_by_one_exponent", 10000), ("counted_digits_not_zeros", 100), ("multiplied_base_by_exp", 30)],
        visual=card(10, 3), meta={"pad_digits": 7}, model=tower(10, 3, True),
        ex=example("z8.evaluate.prompt", {"b": 10, "e": 2}, 100, "z8.hint.example_value", {"b": 10, "e": 2, "v": 100})),
    "zero": make("exp.zero_one.rules", "z8.evaluate.prompt", {"b": 7, "e": 0}, 1, [
        ("zero_power_is_zero", 0), ("added_base_and_exp", 7)],
        visual=card(7, 0), model=tower(7, 0, True),
        ex=example("z8.evaluate.prompt", {"b": 5, "e": 0}, 1, "z8.hint.example_zero", {"b": 5})),
    "bin_read": make("base.binary.to_decimal", "z8.binary.prompt_lamps", {}, 13, [
        ("read_as_decimal_digits", 1101), ("reversed_bits", 11), ("dropped_leading_place", 5)],
        visual=lamps(2, [[1, 1, 0, 1]], 4, "lamps"), model=lamps(2, [[1, 1, 0, 1]], 4, "lamps"),
        ex=example("z8.binary.prompt_lamps", {}, 5, "z8.hint.example_binary", {"n": 5})),
    "bin_make": make("base.binary.from_decimal", "z8.binary.prompt_make", {"n": 13}, num(2, [1, 1, 0, 1]), [
        ("reversed_bits", num(2, [1, 0, 1, 1])), ("greedy_skipped_place", num(2, [1, 1, 1])), ("dropped_leading_place", num(2, [1, 0, 1]))],
        meta={"base_pad": {"base": 2, "places": 6}, "vault_lock": {"base": 2, "places": 6}}, model=lamps(2, [[0, 0, 1, 1, 0, 1]], 6, "lamps"),
        ex=example("z8.binary.prompt_make", {"n": 6}, num(2, [1, 1, 0]), "z8.hint.example_binary_make", {"n": 6, "s": 110})),
    "bin_add": make("base.binary.add", "z8.binary.prompt_add", {}, num(2, [1, 0, 0, 0]), [
        ("forgot_carry", num(2, [1, 1, 0])), ("carried_as_decimal", num(2, [1, 1, 2]))],
        visual=lamps(2, [[1, 0, 1], [1, 1]], 6, "digits", True),
        meta={"base_pad": {"base": 2, "places": 6}, "sum": {"a": 5, "b": 3}},
        model=lamps(2, [[1, 0, 1], [1, 1], [1, 0, 0, 0]], 6, "digits", True),
        ex=example("z8.binary.prompt_add", {}, num(2, [1, 1, 0]), "z8.hint.example_binary_add", {"a": 3, "b": 3, "n": 6, "s": 110})),
    "base_read": make("base.other.to_decimal", "z8.base.prompt_read", {"b": 5}, 13, [
        ("read_as_decimal_digits", 23), ("used_base_two", 7)],
        visual=lamps(5, [[2, 3]], 2, "dials"), model=lamps(5, [[2, 3]], 2, "dials"),
        ex=example("z8.base.prompt_read", {"b": 3}, 5, "z8.hint.example_base", {"b": 3, "n": 5})),
    "base_make": make("base.other.from_decimal", "z8.base.prompt_pick", {"n": 25, "b": 4}, num(4, [1, 2, 1]), [
        ("dropped_leading_place", num(4, [2, 1]))],
        visual=lamps(4, [[0, 0, 0, 0]], 4, "dials"), meta={"base_pad": {"base": 4, "places": 4}},
        model=lamps(4, [[0, 1, 2, 1]], 4, "dials"), representation="pictorial",
        ex=example("z8.base.prompt_make", {"n": 9, "b": 3}, num(3, [1, 0, 0]), "z8.hint.example_base_make", {"n": 9, "b": 3, "s": 100})),
    "sci_read": make("sci.notation.read", "z8.sci.prompt_read", {}, 340000, [
        ("off_by_one_exponent", 34000), ("counted_digits_not_shift", 3400000)],
        visual={"type": "notation", "form": "sci", "mantissa": 34, "scale": 1, "exp": 5}, meta={"pad_digits": 7},
        model={"type": "notation", "form": "sci", "mantissa": 34, "scale": 1, "exp": 5},
        ex=example("z8.sci.prompt_read", {}, 2100, "z8.hint.example_sci_read", {"m": {"mantissa": 21, "scale": 1}, "e": 3, "n": 2100})),
    "sci_write": make("sci.notation.write", "z8.sci.prompt_write", {"n": 340000}, sci(34, 1, 5), [
        ("mantissa_not_normalized", sci(34, 0, 4)), ("off_by_one_exponent", sci(34, 1, 6)), ("off_by_one_exponent", sci(34, 1, 4))],
        meta={"sci_pad": {"max_exp": 6}}, model={"type": "notation", "form": "sci", "mantissa": 34, "scale": 1, "exp": 5},
        ex=example("z8.sci.prompt_write", {"n": 52}, sci(52, 1, 1), "z8.hint.example_sci_write", {"n": 52, "m": {"mantissa": 52, "scale": 1}, "e": 1})),
    "lever": make("lever.counterweight.balance", "z8.lever.prompt", {"w": 8, "d": 2, "r": 4}, 4, [
        ("matched_weight_only", 8), ("added_distance", 6), ("swapped_distances", 16)],
        visual={"type": "lever", "left": {"w": 8, "d": 2}, "right": {"w": 0, "d": 4}, "tilt": "unknown"},
        representation="pictorial",
        model={"type": "lever", "left": {"w": 8, "d": 2}, "right": {"w": 0, "d": 4}, "tilt": "unknown", "products": True},
        ex=example("z8.lever.prompt", {"w": 3, "d": 4, "r": 2}, 6, "z8.hint.example_lever", {"w": 3, "d": 4, "p": 12, "x": 6, "r": 2})),
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
    ("repeat", _set(["answer"], calc("mul", [3, 3, 3])), "one copy short"),
    ("repeat", _set(["distractors", 1, "value"], calc("mul", [3, 3, 3, 3])), "a wrong answer equal to the answer"),
    ("evaluate", _set(["answer"], 64), "swapped base and exponent"),
    ("evaluate", _set(["distractors", 3, "value"], 81), "swapped equal to the answer"),
    ("evaluate", _set(["visual"], tower(3, 4, True)), "the tower gives the answer away"),
    ("square", _set(["answer"], 14), "doubled"),
    ("square", _set(["prompt_params", "n"], 12), "a square too big to draw as gems"),
    ("cube", _set(["answer"], 9), "squared, not cubed"),
    ("root", _set(["prompt_params", "n"], 140), "not a perfect square"),
    ("root", _set(["answer"], 72), "halved"),
    ("ride", _set(["answer"], 6), "the wrong floor"),
    ("ride", _set(["meta", "tower", "floors"], 4), "the tower is too short"),
    ("two", _set(["distractors", 2, "value"], 10), "added_two is not 2^(e-1) + 2"),
    ("ten", _set(["answer"], 10000), "one zero too many"),
    ("ten", _set(["meta", "pad_digits"], 3), "the pad cannot hold a million"),
    ("zero", _set(["answer"], 0), "a power of zero is not zero"),
    ("bin_read", _set(["answer"], 11), "read right to left"),
    ("bin_read", _set(["visual", "rows"], [[1, 2, 0, 1]]), "a 2 in binary"),
    ("bin_make", _set(["answer"], num(2, [1, 0, 1, 1])), "reversed bits"),
    ("bin_make", _set(["answer"], num(2, [0, 1, 1, 0, 1])), "a leading zero"),
    ("bin_make", _set(["meta", "vault_lock", "places"], 3), "the lock is too short"),
    ("bin_add", _set(["answer"], num(2, [1, 1, 0])), "forgot to carry"),
    ("bin_add", _set(["meta", "sum", "b"], 2), "no carry at all"),
    ("base_read", _set(["answer"], 23), "read as base ten"),
    ("base_make", _set(["answer"], num(4, [1, 2, 2])), "wrong base-4 digits"),
    ("base_make", _set(["distractors", 0, "misconception"], "reversed_bits"), "a name the skill does not list"),
    ("sci_read", _set(["answer"], 3400000), "zeros after the digits"),
    ("sci_read", _set(["visual", "mantissa"], 340), "card not normalized"),
    ("sci_write", _set(["answer"], sci(34, 0, 4)), "an unnormalized answer"),
    ("sci_write", _set(["answer"], sci(34, 1, 4)), "wrong power of ten"),
    ("sci_write", _set(["meta", "sci_pad", "max_exp"], 3), "the pad's power is too small"),
    ("lever", _set(["answer"], 8), "matched the weight"),
    ("lever", _set(["prompt_params", "r"], 2), "the same distance on both sides"),
    ("lever", _set(["visual", "tilt"], "level"), "a tilt that is not checked"),
]


@pytest.mark.parametrize("name,change,why", TAMPERS, ids=[t[2] for t in TAMPERS])
def test_tampered_problems_fail(name: str, change, why: str) -> None:
    assert errors_of(tampered(name, change)) != [], why


def test_every_zone_8_skill_has_a_checker_and_a_hand_written_problem() -> None:
    assert len(ZONE8) == 16
    assert {problem["skill_id"] for problem in GOOD.values()} == set(ZONE8)
    for skill_id in ZONE8:
        assert SKILLS[skill_id]["generator"] in run.CHECKERS


def test_the_independent_base_helpers() -> None:
    assert bases.to_base(13, 2) == [1, 1, 0, 1]
    assert bases.to_base(13, 5) == [2, 3]
    assert bases.to_base(0, 3) == [0]
    assert bases.read([1, 1, 0, 1], 2) == 13
    assert bases.strip([0, 0, 1, 0]) == [1, 0]


def test_scientific_notation_is_exact_and_judged_by_form() -> None:
    assert sci_notation.value(34, 1, 5) == 340000
    assert sci_notation.as_int(sci_notation.value(34, 1, 0)) is None  # 3.4 is not whole
    assert common.is_normalized_sci(sci(34, 1, 5))
    assert not common.is_normalized_sci(sci(34, 0, 4))
    assert not common.is_normalized_sci(sci(30, 1, 4))  # a trailing zero after the point
    assert not common.same_answer(sci(34, 0, 4), sci(34, 1, 5))


def test_zone8_pictures_are_checked() -> None:
    assert common.check_visual(tower(2, 11, True), "v") != []
    assert common.check_visual({"type": "notation", "form": "root", "n": 10}, "v") != []
    assert common.check_visual({"type": "cube_blocks", "n": 9}, "v") != []
    assert common.check_visual(lamps(2, [[1, 0, 1, 1]], 3, "lamps"), "v") != []
    assert common.check_visual({"type": "lever", "left": {"w": 4, "d": 2}, "right": {"w": 2, "d": 2}, "tilt": "level"}, "v") != []
    assert common.check_visual({"type": "lever", "left": {"w": 4, "d": 2}, "right": {"w": 2, "d": 4}, "tilt": "level"}, "v") == []
