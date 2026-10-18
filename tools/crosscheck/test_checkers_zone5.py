"""pytest: the Zone 5 checkers (sieve, divisibility rules, prime recipes, who is right) accept correct
problems and catch every kind of wrong one.

Each valid problem is written out by hand from the skill definitions (never produced by the GDScript
generators), then tampered with. If a checker stopped checking something, a tamper would pass.
"""
from __future__ import annotations

import copy

import pytest
import run
from checkers import numbers

SKILLS = {skill["id"]: skill for skill in run.load_skills()}
ALLOWED = run.allowed_misconceptions()
YES_NO = {"true": "ui.common.yes", "false": "ui.common.no"}
ZONE5 = sorted(skill_id for skill_id, skill in SKILLS.items() if skill["zone"] == 5)


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


EVENS_TO_30 = list(range(4, 31, 2))
# Multiples of 3 on a 30 grid: 1 and the even composites are crossed already; 9, 15, 21 and 27 are new.
MULTIPLES_3 = sorted([1] + EVENS_TO_30 + [9, 15, 21, 27])
COMPOSITES_50 = [4, 6, 8, 9, 10, 12, 14, 15, 16, 18, 20, 21, 22, 24, 25, 26, 27, 28, 30, 32, 33, 34, 35, 36, 38, 39, 40, 42, 44, 45, 46, 48, 49, 50]
# With q = 3 every composite but 25, 35 and 49 is crossed already.
LEFT_Q3 = [25, 35, 49]
RECIPE_30 = example("z5.tree.prompt", {"n": 30}, [2, 3, 5], "z5.hint.example_recipe_3", {"n": 30, "a": 2, "b": 3, "c": 5})


def without(values: list[int], gone: int) -> list[int]:
    return [value for value in values if value != gone]


GOOD = {
    "sieve_multiples": make("sieve.mark.multiples_of", "z5.sieve.prompt_multiples", {"p": 3, "size": 30}, MULTIPLES_3,
                            [("crossed_p_itself", sorted(MULTIPLES_3 + [3])), ("missed_p_squared", without(MULTIPLES_3, 9)),
                             ("missed_last_multiple", without(MULTIPLES_3, 27))],
                            meta={"sieve_grid": {"size": 30, "cols": 10, "precrossed": [1] + EVENS_TO_30}},
                            model=numbers.hops(10, 3),
                            example=example("z5.sieve.prompt_multiples", {"p": 2, "size": 30}, [], "z5.hint.example_sieve_multiples", {"p": 2, "a": 4, "b": 6, "c": 8})),
    "sieve_primes": make("sieve.find.primes_to_50", "z5.sieve.prompt_primes", {"size": 50, "q": 3}, [1] + COMPOSITES_50,
                         [("one_is_prime", COMPOSITES_50), ("square_is_prime", [1] + without(COMPOSITES_50, 49)),
                          ("odd_means_prime", [1] + without(COMPOSITES_50, 35)), ("crossed_p_itself", sorted([1, 5] + COMPOSITES_50))],
                         meta={"sieve_grid": {"size": 50, "cols": 10, "precrossed": [n for n in COMPOSITES_50 if n not in LEFT_Q3]}},
                         model=numbers.array_picture(7, 7, True),
                         example=example("z5.sieve.prompt_primes", {"size": 50, "q": 2}, [], "z5.hint.example_sieve_primes", {"n": 9, "a": 3, "b": 3})),
    "div_3_9": make("div.rule.3_9", "z5.div.prompt", {"n": 126, "d": 9}, True, [("last_digit_only_for_3", False)],
                    meta={"label_lines": YES_NO}, representation="pictorial",
                    visual={"type": "digits", "digits": [1, 2, 6], "focus": "sum"}, model={"type": "digits", "digits": [1, 2, 6], "focus": "sum"},
                    example=example("z5.div.prompt", {"n": 50, "d": 3}, False, "z5.hint.example_div_no", {"n": 50, "d": 3, "q": 16, "r": 2})),
    "div_mixed_127": make("div.rule.mixed", "z5.div.prompt", {"n": 127, "d": 9}, False, [("no_check_made", True)],
                          meta={"label_lines": YES_NO}, model={"type": "digits", "digits": [1, 2, 7], "focus": "sum"},
                          example=example("z5.div.prompt", {"n": 20, "d": 4}, True, "z5.hint.example_div_yes", {"n": 20, "d": 4, "q": 5})),
    "div_10": make("div.rule.2_5_10", "z5.div.prompt", {"n": 85, "d": 10}, False, [("mixed_up_5_and_10", True)],
                   meta={"label_lines": YES_NO}, representation="abstract", model={"type": "digits", "digits": [8, 5], "focus": "last"},
                   example=example("z5.div.prompt", {"n": 40, "d": 5}, True, "z5.hint.example_div_yes", {"n": 40, "d": 5, "q": 8})),
    "tree": make("pf.tree.build", "z5.tree.prompt", {"n": 12}, [2, 2, 3],
                 [("stopped_at_composite", [3, 4]), ("missing_repeated_factor", [2, 3])],
                 meta={"factor_tree": {"value": 12}}, model=numbers.array_picture(2, 6, True), example=RECIPE_30),
    "write_prime": make("pf.list.write", "z5.pf.prompt_write", {"n": 127}, [127],
                        [("product_mismatch", [131]), ("one_is_prime", [1, 127])],
                        meta={"array_label": "product"}, representation="pictorial", visual=numbers.hops(1, 127), model=numbers.hops(1, 127),
                        example=example("z5.pf.prompt_write", {"n": 12}, [2, 2, 3], "z5.hint.example_recipe_3", {"n": 12, "a": 2, "b": 2, "c": 3})),
    "check": make("pf.check.equal_products", "z5.pf.prompt_check_2", {"n": 12, "a": 3, "b": 4}, False, [("stopped_at_composite", True)],
                  meta={"label_lines": YES_NO, "candidate": [3, 4]}, model=numbers.array_picture(2, 6, True),
                  example=example("z5.pf.prompt_check_3", {"n": 18, "a": 2, "b": 3, "c": 3}, True, "z5.hint.example_recipe_3", {"n": 18, "a": 2, "b": 3, "c": 3})),
    "fta": make("pf.fta.unique", "z5.fta.prompt", {"n": 24}, [2, 2, 2, 3],
                [("tree_with_composite_leaf", [2, 3, 4]), ("product_mismatch", [2, 2, 2, 5])],
                meta={"array_label": "product"}, model=numbers.hops(2, 12), example=example("z5.fta.prompt", {"n": 30}, [2, 3, 5], "z5.hint.example_recipe_3", {"n": 30, "a": 2, "b": 3, "c": 5})),
}


def verdict(problem: dict) -> list[str]:
    return run.check_problem(problem, SKILLS[problem["skill_id"]], ALLOWED)


@pytest.mark.parametrize("name", sorted(GOOD))
def test_a_correct_problem_passes(name: str) -> None:
    assert verdict(copy.deepcopy(GOOD[name])) == []


def test_every_zone_5_skill_has_a_checker() -> None:
    assert len(ZONE5) == 11
    for skill_id in ZONE5:
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


TAMPERS = [
    ("sieve_multiples", "answer keeps the prime", _set(["answer"], sorted(MULTIPLES_3 + [3]))),
    ("sieve_multiples", "answer misses a multiple", _set(["answer"], without(MULTIPLES_3, 15))),
    ("sieve_multiples", "precrossed loses a rock", _set(["meta", "sieve_grid", "precrossed"], [1] + EVENS_TO_30[1:])),
    ("sieve_multiples", "board un-crosses a precrossed rock", _distractor(1, without(MULTIPLES_3, 4))),
    ("sieve_multiples", "names swapped", _name(1, "missed_last_multiple")),
    ("sieve_multiples", "grid not ten wide", _set(["meta", "sieve_grid", "cols"], 6)),
    ("sieve_multiples", "a prime the skill does not use", _set(["prompt_params", "p"], 7)),
    ("sieve_multiples", "wrong hops", _set(["hint_steps", 1, "visual"], numbers.hops(10, 2))),
    ("sieve_primes", "1 left standing in the answer", _set(["answer"], COMPOSITES_50)),
    ("sieve_primes", "wrong square", _distractor(1, [1] + without(COMPOSITES_50, 25))),
    ("sieve_primes", "a square for odd_means_prime", _distractor(2, [1] + without(COMPOSITES_50, 25))),
    ("sieve_primes", "crosses the wrong prime", _distractor(3, sorted([1, 7] + COMPOSITES_50))),
    ("sieve_primes", "example with the same q", _set(["hint_steps", 2, "example", "prompt_params", "q"], 3)),
    ("div_3_9", "wrong answer", _set(["answer"], False)),
    ("div_3_9", "wrong mistake", _name(0, "three_means_nine")),
    ("div_3_9", "last-digit focus for 9", _set(["visual", "focus"], "last")),
    ("div_3_9", "example remainder", _set(["hint_steps", 2, "example", "answer_params", "r"], 1)),
    ("div_mixed_127", "rule mistake for an unrelated number", _name(0, "three_means_nine")),
    ("div_mixed_127", "abstract problem with a picture", _set(["visual"], {"type": "digits", "digits": [1, 2, 7], "focus": "sum"})),
    ("div_10", "plain mistake for 85 and 10", _name(0, "no_check_made")),
    ("div_10", "n below the skill's range", _set(["prompt_params", "n"], 5)),
    ("tree", "wrong recipe", _set(["answer"], [2, 6])),
    ("tree", "stopped board with a wrong product", _distractor(0, [3, 5])),
    ("tree", "missing board that keeps the repeat", _distractor(1, [2, 2, 3])),
    ("tree", "tree starts from another number", _set(["meta", "factor_tree", "value"], 18)),
    ("tree", "example states another recipe", _set(["hint_steps", 2, "example", "answer_params", "c"], 7)),
    ("write_prime", "abstract picture for a pictorial problem", _set(["visual"], {})),
    ("write_prime", "mismatch board that multiplies to n", _distractor(0, [127])),
    ("write_prime", "one board without the 1", _distractor(1, [127, 1])),
    ("write_prime", "sum labels", _set(["meta", "array_label"], "sum")),
    ("check", "the composite candidate called right", _set(["answer"], True)),
    ("check", "wrong mistake", _name(0, "product_mismatch")),
    ("check", "prompt names another candidate", _set(["prompt_params", "b"], 5)),
    ("check", "line for the wrong length", _set(["prompt_line_id"], "z5.pf.prompt_check_3")),
    ("fta", "leaf board with a wrong product", _distractor(0, [2, 3, 5])),
    ("fta", "mismatch board with the right product", _distractor(1, [2, 3, 4])),
    ("fta", "only two primes in n", _set(["prompt_params", "n"], 15)),
]


@pytest.mark.parametrize("name, what, tamper", TAMPERS, ids=[f"{name}: {what}" for name, what, _ in TAMPERS])
def test_a_tampered_problem_fails(name: str, what: str, tamper) -> None:
    problem = copy.deepcopy(GOOD[name])
    tamper(problem)
    assert verdict(problem), f"{name}: '{what}' was not caught"


def test_the_independent_recipe_helper() -> None:
    assert numbers.prime_recipe(1) == []
    assert numbers.prime_recipe(12) == [2, 2, 3]
    assert numbers.prime_recipe(127) == [127]
    assert numbers.prime_recipe(96) == [2, 2, 2, 2, 2, 3]
    assert numbers.multiply_all([2, 2, 3]) == 12
    assert numbers.digits_of(406) == [4, 0, 6]
