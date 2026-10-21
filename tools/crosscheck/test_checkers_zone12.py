"""pytest: the Zone 12 checkers (starter proofs, guided proofs, number rings, the mysteries) accept correct problems and
catch every kind of wrong one. Each valid problem is written out by hand (never produced by the GDScript generators), then
tampered with. If a checker stopped checking something, a tamper would pass."""
from __future__ import annotations

import copy

import run
from checkers import common, mystery, number_sets, proof_steps

SKILLS = {skill["id"]: skill for skill in run.load_skills()}
ALLOWED = run.allowed_misconceptions()
YES_NO = {"true": "ui.common.yes", "false": "ui.common.no"}


def make(skill_id, prompt_line, prompt_params, answer, distractors, *, visual=None, meta=None, model=None, ex=None, representation=None):
    skill = SKILLS[skill_id]
    return {
        "skill_id": skill_id, "seed": 1, "representation": representation or skill["representations"][0],
        "prompt_line_id": prompt_line, "prompt_params": prompt_params, "answer": answer, "answer_modes": skill["answer_modes"],
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


def example(prompt_line, prompt_params, answer, answer_line, answer_params):
    return {"prompt_line_id": prompt_line, "prompt_params": prompt_params, "answer": answer,
            "answer_line_id": answer_line, "answer_params": answer_params}


def full(problem):
    skill = SKILLS[problem["skill_id"]]
    return common.check_structure(problem, skill, ALLOWED) + run.CHECKERS[skill["generator"]](problem)


def cards(lines, order=None):
    order = order or list(range(len(lines)))
    return [{"line_id": lines[i], "n": shown + 1} for shown, i in enumerate(order)]


def statements(lines, order=None, lit=0, arrows=False):
    picture = {"type": "statements", "cards": cards(lines, order)}
    if lit:
        picture["lit"] = lit
    if arrows:
        picture["arrows"] = True
    return picture


EVEN = [f"z12.mini.even_plus_even.{i}" for i in range(1, 5)]
GOOD_PARTS = make("proof.parts.identify", "z12.proof.prompt_assumption", {}, 3,
                  [("picked_conclusion_as_assumption", 2), ("picked_middle_step", 1), ("picked_middle_step", 4)],
                  visual=statements(EVEN, [2, 3, 0, 1]), meta={"chain": "even_plus_even", "starts": True, "order": [2, 3, 0, 1]},
                  model=statements(EVEN, None, 1, True),
                  ex=example("z12.proof.prompt_assumption", {}, 2, "z12.hint.example_parts_assumption", {"n": 2}))
GOOD_ORDER = make("proof.order.chain", "z12.proof.prompt_order", {}, [2, 4, 1, 3],
                  [("reversed_chain", [3, 1, 4, 2]), ("swapped_two_steps", [4, 2, 1, 3]), ("swapped_two_steps", [2, 1, 4, 3]), ("swapped_two_steps", [2, 4, 3, 1])],
                  visual=statements(EVEN, [2, 0, 3, 1]), meta={"chain": "even_plus_even", "order": [2, 0, 3, 1],
                                                                  "tile_board": {"tiles": [1, 2, 3, 4], "slots": 4, "ordered": True}},
                  model=statements(EVEN, None, 0, True),
                  ex=example("z12.proof.prompt_order", {}, [2, 1, 3], "z12.hint.example_order", {"n": 2}))
GOOD_JUSTIFY = make("proof.justify.step", "z12.proof.prompt_justify", {"k": 2}, "meaning",
                    [("mixed_up_reason", "assume"), ("mixed_up_reason", "arithmetic"), ("mixed_up_reason", "previous")],
                    visual=statements(EVEN, None, 2), meta={"chain": "even_plus_even", "label_lines": {r: f"z12.why.{r}" for r in proof_steps.REASONS}},
                    model=statements(EVEN, None, 2, True),
                    ex=example("z12.proof.prompt_justify", {"k": 1}, "assume", "z12.hint.example_justify_assume", {"k": 1}))
SEVEN = [f"z12.mini.seven_even.{i}" for i in range(1, 5)]
GOOD_CLASH = make("proof.contradiction.recognize", "z12.proof.prompt_contradiction", {}, 3,
                  [("missed_contradiction", 2), ("missed_contradiction", 4)], visual=statements(SEVEN), meta={"set": "seven_even"},
                  model=statements(SEVEN, None, 3, True),
                  ex=example("z12.proof.prompt_contradiction", {}, 3, "z12.hint.example_contradiction", {"k": 3}))


def card(form, a, **extra):
    return dict({"type": "number_card", "form": form, "a": a}, **extra)


def ring_problem(skill_id, mode, picture, answer, distractors, ex):
    model = dict(picture, rings=True, lit=number_sets.ring(picture))
    line = {"integer": "z12.sets.prompt_integer", "rational": "z12.sets.prompt_rational", "real": "z12.sets.prompt_real"}[mode]
    meta = {"label_lines": YES_NO} if mode != "real" else {"label_lines": {"integer": "z12.sets.ring_integer", "rational": "z12.sets.ring_rational", "real": "z12.sets.ring_real"}}
    return make(skill_id, line, {}, answer, distractors, visual=picture, meta=meta, model=model, ex=ex)


GOOD_RING = ring_problem("sets.real.classify", "real", card("decimal", 75, scale=2), "rational",
                         [("fraction_is_integer", "integer"), ("decimal_not_rational", "real")],
                         example("z12.sets.prompt_real", {}, "real", "z12.hint.example_set_real", {}))
GOOD_INT = ring_problem("sets.integer.classify", "integer", card("root", 4), True, [("root_never_integer", False)],
                        example("z12.sets.prompt_integer", {}, False, "z12.hint.example_integer_no", {}))
GOOD_RAT = ring_problem("sets.rational.classify", "rational", card("root", 2), False, [("sqrt_always_rational", True)],
                        example("z12.sets.prompt_rational", {}, True, "z12.hint.example_rational_yes", {}))


def line(n):
    return [{"type": "number_line", "min": 0, "max": -(-n // 10) * 10, "labeled_every": 10, "markers": [n], "blanks": []}][0]


GOOD_GOLDBACH = make("mystery.goldbach.find_pair", "z12.mystery.prompt_goldbach", {"n": 20}, "3 + 17",
                     [("used_composite", "1 + 19"), ("sum_off", "5 + 17")], meta={"pairs": ["3 + 17", "7 + 13"]},
                     visual=line(20), model=line(20), representation="pictorial",
                     ex=example("z12.mystery.prompt_goldbach", {"n": 10}, "3 + 7", "z12.hint.example_goldbach", {"p": 3, "q": 7, "n": 10}))
# The larger twin is named before the cousin prime (peer review 05: after 10 they are both 13).
GOOD_TWIN = make("mystery.twin.next_pair", "z12.mystery.prompt_twin", {"p": 20}, 29,
                 [("gave_larger_prime", 31), ("gap_not_two", 37), ("not_both_prime", 21)], meta={"pad_digits": 3},
                 visual={"type": "number_line", "min": 20, "max": 40, "labeled_every": 10, "markers": [20], "blanks": []},
                 model={"type": "number_line", "min": 20, "max": 40, "labeled_every": 10, "markers": [20, 29, 31], "blanks": []},
                 representation="pictorial",
                 ex=example("z12.mystery.prompt_twin", {"p": 5}, 11, "z12.hint.example_twin", {"q": 11, "r": 13}))

ALL_GOOD = [GOOD_PARTS, GOOD_ORDER, GOOD_JUSTIFY, GOOD_CLASH, GOOD_RING, GOOD_INT, GOOD_RAT, GOOD_GOLDBACH, GOOD_TWIN]


def test_hand_written_problems_pass() -> None:
    for problem in ALL_GOOD:
        assert full(problem) == [], (problem["skill_id"], full(problem))


def tampered(problem, mutate):
    clone = copy.deepcopy(problem)
    mutate(clone)
    return full(clone)


def test_every_tamper_is_caught() -> None:
    cases = [
        (GOOD_PARTS, lambda p: p.update(answer=1)),
        (GOOD_PARTS, lambda p: p["visual"]["cards"].reverse()),
        (GOOD_ORDER, lambda p: p.update(answer=[1, 2, 3, 4])),
        (GOOD_ORDER, lambda p: p["meta"]["tile_board"].update(slots=3)),
        (GOOD_JUSTIFY, lambda p: p.update(answer="assume")),
        (GOOD_JUSTIFY, lambda p: p["visual"].update(lit=1)),
        (GOOD_CLASH, lambda p: p.update(answer=2)),
        (GOOD_RING, lambda p: p.update(answer="integer")),
        (GOOD_RING, lambda p: p["hint_steps"][1]["visual"].update(lit="real")),
        (GOOD_INT, lambda p: p.update(answer=False)),
        (GOOD_RAT, lambda p: p.update(answer=True)),
        (GOOD_GOLDBACH, lambda p: p.update(answer="3 + 15")),
        (GOOD_GOLDBACH, lambda p: p["distractors"].append({"value": "7 + 13", "misconception": "sum_off"})),
        (GOOD_GOLDBACH, lambda p: p["meta"].update(pairs=["3 + 17"])),
        (GOOD_TWIN, lambda p: p.update(answer=31)),
        (GOOD_TWIN, lambda p: p["distractors"][0].update(value=39)),
    ]
    for problem, mutate in cases:
        assert tampered(problem, mutate), (problem["skill_id"], mutate)


def test_the_picture_validators_reject_bad_cards_and_numbers() -> None:
    assert common.check_visual({"type": "statements", "cards": [{"line_id": "a", "n": 1}, {"line_id": "b", "n": 3}]}, "v")
    assert common.check_visual({"type": "statements", "cards": [{"line_id": "a", "n": n} for n in range(1, 10)]}, "v")
    assert common.check_visual({"type": "statements", "cards": [{"line_id": "a", "n": 1}], "lit": 2}, "v")
    assert common.check_visual({"type": "number_card", "form": "frac", "a": 1, "b": 20}, "v")
    assert common.check_visual({"type": "number_card", "form": "decimal", "a": 5, "scale": 4}, "v")
    assert common.check_visual({"type": "number_card", "form": "root", "a": 1}, "v")
    assert common.check_visual({"type": "number_card", "form": "weird", "a": 1}, "v")
    assert not common.check_visual({"type": "number_card", "form": "root", "a": 2, "rings": True, "lit": "real"}, "v")


def test_the_guided_proof_files_are_sound() -> None:
    for proof in proof_steps.PROOFS.values():
        assert proof_steps.check_proof_file(proof) == [], proof["id"]
    euclid = proof_steps.PROOFS["proof.euclid.infinite_primes"]
    orders = proof_steps.valid_orders(euclid)
    assert len(orders) > 1
    assert [s["id"] for s in euclid["steps"]] in orders
    assert len(proof_steps.valid_orders(proof_steps.PROOFS["proof.sqrt2.irrational"])) == 1
    broken = copy.deepcopy(euclid)
    broken["steps"][1]["depends_on"] = ["s7"]
    assert proof_steps.check_proof_file(broken)


def test_a_guided_proof_problem_is_checked_against_the_file() -> None:
    proof = proof_steps.PROOFS["proof.sqrt2.irrational"]
    model = {"type": "statements", "cards": [{"line_id": s["line_id"], "n": i + 1} for i, s in enumerate(proof["steps"])], "arrows": True}
    practice = proof_steps.PROOFS["proof.practice.even_plus_even"]
    problem = make("proof.sqrt2.irrational", "z12.proof.prompt_build", {}, proof["id"], [], meta={"proof_builder": {"proof_id": proof["id"]}}, model=model,
                   ex=example(practice["intro_line_id"], {}, practice["id"], "z12.hint.example_guided", {}))
    problem["params"]["proof_id"] = proof["id"]
    assert full(problem) == []
    wrong = copy.deepcopy(problem)
    wrong["answer"] = "proof.euclid.infinite_primes"
    assert full(wrong)


def test_the_mystery_helpers_agree_with_hand_lists() -> None:
    assert mystery.pairs(20) == [(3, 17), (7, 13)]
    assert mystery.pairs(4) == [(2, 2)]
    assert all(mystery.pairs(n) for n in range(4, 101, 2))
    twins = [q for q in range(2, 230) if mystery.PRIME[q] and mystery.PRIME[q + 2]]
    assert twins == [3, 5, 11, 17, 29, 41, 59, 71, 101, 107, 137, 149, 179, 191, 197, 227]
