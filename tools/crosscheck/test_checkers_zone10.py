"""pytest: the Zone 10 checkers (clock arithmetic, mixing tables and groups, why the divisibility rules work)
accept correct problems and catch every kind of wrong one.

Each valid problem is written out by hand from the skill definitions (never produced by the GDScript
generators), then tampered with. If a checker stopped checking something, a tamper would pass.
"""
from __future__ import annotations

import copy

import run
from checkers import common

SKILLS = {skill["id"]: skill for skill in run.load_skills()}
ALLOWED = run.allowed_misconceptions()
YES_NO = {"true": "ui.common.yes", "false": "ui.common.no"}


def track(n, start, steps, direction, show_stop, also=None, orbit=False):
    picture = {"type": "clock_track", "n": n, "start": start, "steps": steps, "direction": direction, "show_stop": show_stop}
    if also is not None:
        picture["also"] = also
    if orbit:
        picture["orbit"] = True
    return picture


def cayley(n, op, wrap, blank=None, ring=None, focus="", row=-1):
    picture = {"type": "cayley", "n": n, "op": op, "wrap": wrap}
    if blank:
        picture["blank"] = blank
    if ring:
        picture["ring"] = ring
    if focus:
        picture["focus"] = focus
    if row >= 0:
        picture["row"] = row
    return picture


def example(prompt_line, prompt_params, answer, answer_line, answer_params):
    return {"prompt_line_id": prompt_line, "prompt_params": prompt_params, "answer": answer,
            "answer_line_id": answer_line, "answer_params": answer_params}


def make(skill_id, prompt_line, prompt_params, answer, distractors, *, visual=None, meta=None, model=None, ex=None, representation=None):
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
    # 33 stops on a loop of 7 from 0: 33 = 4 laps of 7 and 5 more.
    "remainder": make("mod.remainder.find", "z10.mod.prompt_remainder_track", {"a": 33, "n": 7}, 5,
                      [("gave_quotient", 4), ("forgot_mod_wrap", 26), ("off_by_one", 6)],
                      visual=track(7, 0, 33, 1, False), model=track(7, 0, 33, 1, True), representation="pictorial",
                      ex=example("z10.mod.prompt_remainder_track", {"a": 20, "n": 6}, 2, "z10.hint.example_remainder", {"a": 20, "n": 6, "q": 3, "r": 2})),
    # Start at 2 on a loop of 5, ride 9: 2 + 9 = 11, round the loop to station 1.
    "stop": make("mod.track.stop", "z10.mod.prompt_stop", {"n": 5, "s": 2, "k": 9}, 1,
                 [("forgot_mod_wrap", 11), ("counted_start_station", 0)],
                 visual=track(5, 2, 9, 1, False), model=track(5, 2, 9, 1, True), representation="pictorial",
                 ex=example("z10.mod.prompt_stop", {"n": 4, "s": 1, "k": 6}, 3, "z10.hint.example_stop", {"s": 1, "k": 6, "n": 4, "r": 3})),
    # Start at 2 on a loop of 5, ride back 4: 2 - 4 = -2, wrap to station 3.
    "back": make("mod.track.backward", "z10.mod.prompt_back", {"n": 5, "s": 2, "k": 4}, 3,
                 [("negative_remainder", -2), ("went_forward_instead", 1)],
                 visual=track(5, 2, 4, -1, False), model=track(5, 2, 4, -1, True), representation="pictorial", meta={"signed": True},
                 ex=example("z10.mod.prompt_back", {"n": 6, "s": 1, "k": 3}, 4, "z10.hint.example_back", {"s": 1, "k": 3, "n": 6, "r": 4})),
    # 17 and 5 on a loop of 12 both land on 5.
    "congruent": make("mod.congruence.check", "z10.mod.prompt_congruent", {"n": 12, "a": 17, "b": 5}, True,
                      [("compared_raw_values", False)], visual=track(12, 0, 17, 1, False, 5), model=track(12, 0, 17, 1, True, 5),
                      meta={"label_lines": YES_NO}, representation="pictorial",
                      ex=example("z10.mod.prompt_congruent", {"n": 4, "a": 9, "b": 5}, True, "z10.hint.example_congruent_yes", {"a": 9, "b": 5, "r": 1})),
    "notation": make("mod.congruence.notation", "z10.mod.prompt_notation_loop", {}, 12,
                     [("swapped_mod_and_value", 41), ("swapped_mod_and_value", 29), ("swapped_mod_and_value", 5)],
                     visual={"type": "notation", "form": "congruence", "a": 41, "b": 29, "n": 12},
                     model={"type": "notation", "form": "congruence", "a": 41, "b": 29, "n": 12}, meta={"a": 41, "b": 29, "n": 12},
                     ex=example("z10.mod.prompt_notation_loop", {}, 12, "z10.hint.example_notation_loop", {"n": 12})),
    # Turn 5 then 4 on a dial of 7: 9 wraps to 2.
    "add": make("mod.add.wrap", "z10.mod.prompt_add", {"n": 7, "m": 6, "a": 5, "b": 4}, 2,
                [("forgot_mod_wrap", 9), ("subtracted_instead", 1)], model=track(7, 0, 9, 1, True), representation="abstract",
                ex=example("z10.mod.prompt_add", {"n": 5, "m": 4, "a": 3, "b": 4}, 2, "z10.hint.example_add", {"a": 3, "b": 4, "t": 7, "n": 5, "r": 2})),
    "mul": make("mod.mul.wrap", "z10.mod.prompt_mul", {"n": 8, "m": 7, "a": 3, "b": 6}, 2,
                [("forgot_mod_wrap", 18), ("added_instead", 1)], model=cayley(8, "mul", True, [], [3, 6]),
                visual=cayley(8, "mul", True, [3, 6], [3, 6]), representation="pictorial",
                ex=example("z10.mod.prompt_mul", {"n": 5, "m": 4, "a": 3, "b": 4}, 2, "z10.hint.example_mul", {"a": 3, "b": 4, "t": 12, "n": 5, "r": 2})),
    "identity": make("group.identity.find", "z10.group.prompt_identity_mul", {"n": 6}, 1,
                     [("picked_zero_for_mul", 0), ("picked_last_number", 5)], meta={"mixing_table": {"n": 6, "op": "mul"}},
                     model=cayley(6, "mul", True, focus="identity"),
                     ex=example("z10.group.prompt_identity_add", {"n": 4}, 0, "z10.hint.example_identity_add", {})),
    "inverse": make("group.inverse.find", "z10.group.prompt_inverse", {"a": 3, "n": 8}, 5,
                    [("gave_negative_raw", -3), ("gave_same_value", 3), ("gave_n_minus_one", 7)], meta={"signed": True},
                    visual=cayley(8, "add", True, row=3), model=cayley(8, "add", True, focus="identity", row=3), representation="pictorial",
                    ex=example("z10.group.prompt_inverse", {"a": 2, "n": 5}, 3, "z10.hint.example_inverse", {"a": 2, "b": 3})),
    # The adding table with the wrap left off has 4 + 4 = 8 in it, past the last number 8 - 1... for n = 5: 8 > 4.
    "closure": make("group.closure.verify", "z10.group.prompt_closure_add", {"m": 4}, False,
                    [("missed_value_ge_n", True)], visual=cayley(5, "add", False), model=cayley(5, "add", False),
                    meta={"label_lines": YES_NO, "biggest": 8},
                    ex=example("z10.group.prompt_closure_add", {"m": 3}, True, "z10.hint.example_closure_yes", {"m": 3})),
    # Row 3, column 4 of the adding table of 6: 3 + 4 = 7 wraps to 1.
    "table": make("group.table.complete", "z10.group.prompt_table", {}, 1,
                  [("forgot_mod_wrap", 7), ("copied_cell_above", 0)],
                  visual=cayley(6, "add", True, [3, 4], [3, 4]), model=cayley(6, "add", True, ring=[3, 4]),
                  meta={"table": {"n": 6, "op": "add", "r": 3, "c": 4}},
                  ex=example("z10.group.prompt_table", {}, 1, "z10.hint.example_table_add", {"r": 3, "c": 4, "t": 7, "n": 6, "x": 1})),
    # Jumps of 4 on a loop of 6: 0, 4, 2, 0 is 3 jumps.
    "cyclic": make("group.cyclic.generate", "z10.group.prompt_cyclic", {"n": 6, "g": 4}, 3,
                   [("stopped_early", 2), ("skipped_identity", 6), ("used_jump_size", 4)],
                   visual=track(6, 0, 4, 1, False, orbit=True), model=track(6, 0, 4, 1, True, orbit=True), representation="pictorial",
                   ex=example("z10.group.prompt_cyclic", {"n": 8, "g": 2}, 4, "z10.hint.example_cyclic", {"g": 2, "n": 8, "j": 4})),
    "digit_sum": make("div.rule.explain_3_9", "z10.div.prompt_digit_sum", {"a": 472, "b": 9, "s": 13}, 4,
                      [("used_last_digit", 2)],
                      visual={"type": "digits", "digits": [4, 7, 2], "focus": "sum"}, model={"type": "digits", "digits": [4, 7, 2], "focus": "sum"},
                      representation="pictorial",
                      ex=example("z10.div.prompt_digit_sum", {"a": 135, "b": 9, "s": 9}, 0, "z10.hint.example_digit_sum", {"a": 135, "s": 9, "r": 0, "b": 9})),
}
# 472 ÷ 9 leaves 4; its last digit 2 leaves 2 (used_last_digit); without the 2, 4 + 7 = 11 leaves 2 too (a repeat, dropped).


def verdict(problem):
    return run.check_problem(problem, SKILLS[problem["skill_id"]], ALLOWED)


def test_every_zone_10_checker_is_registered() -> None:
    for skill in SKILLS.values():
        if skill["zone"] == 10:
            assert skill["generator"] in run.CHECKERS


def test_valid_problems_pass() -> None:
    for name, problem in GOOD.items():
        assert verdict(problem) == [], (name, verdict(problem))


def test_a_wrong_answer_is_caught() -> None:
    for name in ("remainder", "stop", "back", "add", "mul", "inverse", "table", "cyclic", "digit_sum"):
        problem = copy.deepcopy(GOOD[name])
        problem["answer"] += 1
        assert verdict(problem), name
    for name in ("congruent", "closure"):
        problem = copy.deepcopy(GOOD[name])
        problem["answer"] = not problem["answer"]
        assert verdict(problem), name


def test_a_wrong_distractor_is_caught() -> None:
    for name in ("remainder", "stop", "back", "add", "mul", "inverse", "table", "cyclic", "digit_sum"):
        problem = copy.deepcopy(GOOD[name])
        problem["distractors"][0]["value"] += 100
        assert verdict(problem), name


def test_a_misnamed_or_missing_distractor_is_caught() -> None:
    problem = copy.deepcopy(GOOD["stop"])
    problem["distractors"][0]["misconception"] = "counted_start_station"
    assert verdict(problem)
    problem = copy.deepcopy(GOOD["cyclic"])
    del problem["distractors"][-1]
    assert verdict(problem)


def test_a_picture_that_does_not_match_is_caught() -> None:
    for name in ("remainder", "stop", "back", "congruent", "mul", "inverse", "closure", "table", "cyclic", "digit_sum"):
        problem = copy.deepcopy(GOOD[name])
        problem["visual"]["n"] = problem["visual"].get("n", 4) + 1 if "n" in problem["visual"] else 4
        assert verdict(problem), name
    problem = copy.deepcopy(GOOD["stop"])
    problem["hint_steps"][1]["visual"]["show_stop"] = False
    assert verdict(problem)


def test_a_worked_example_that_does_not_add_up_is_caught() -> None:
    for name, key, value in (("stop", "r", 0), ("back", "r", 0), ("add", "r", 0), ("mul", "r", 0), ("cyclic", "j", 5), ("remainder", "q", 9)):
        problem = copy.deepcopy(GOOD[name])
        problem["hint_steps"][2]["example"]["answer_params"][key] = value
        assert verdict(problem), name


def test_prompt_numbers_out_of_the_skills_range_are_caught() -> None:
    problem = copy.deepcopy(GOOD["remainder"])
    problem["prompt_params"]["n"] = 13
    assert verdict(problem)
    problem = copy.deepcopy(GOOD["add"])
    problem["prompt_params"]["m"] = 7
    assert verdict(problem)


def test_the_notation_card_must_be_a_real_congruence() -> None:
    problem = copy.deepcopy(GOOD["notation"])
    problem["visual"]["b"] = 30
    problem["hint_steps"][1]["visual"]["b"] = 30
    problem["meta"]["b"] = 30
    assert verdict(problem)


def test_zone_10_pictures_must_be_drawable() -> None:
    assert common.check_visual(track(12, 11, 99, -1, True, 0, True), "v") == []
    assert common.check_visual(track(13, 0, 1, 1, True), "v")
    assert common.check_visual(track(5, 5, 1, 1, True), "v")
    assert common.check_visual(track(5, 0, 100, 1, True), "v")
    assert common.check_visual(cayley(12, "mul", True, [11, 11], [0, 0], "identity", 4), "v") == []
    assert common.check_visual(cayley(10, "add", False), "v")
    assert common.check_visual(cayley(5, "add", True, [5, 0]), "v")
    assert common.check_visual({"type": "digits", "digits": [1, 2, 3, 4], "focus": "last_three"}, "v") == []


def test_zone_10_inputs_must_be_able_to_give_the_answer() -> None:
    problem = copy.deepcopy(GOOD["stop"])
    problem["meta"]["circular_track"] = {"n": 5, "start": 2, "steps": 9, "direction": 1}
    assert common.check_input_meta(dict(problem, answer=7)) # no station 7 on a loop of 5
    problem = copy.deepcopy(GOOD["add"])
    problem["meta"]["clock_lock"] = {"n": 7, "turns": []}
    assert common.check_input_meta(problem)
