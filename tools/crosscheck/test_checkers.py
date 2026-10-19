"""pytest: the independent checkers accept correct problems and catch every kind of wrong one.

Valid problems are written out by hand here (never produced by the GDScript generators), then
tampered with. If a checker stopped checking something, one of these would stop failing.
"""
from __future__ import annotations

import copy
import json
import os
import shutil
from pathlib import Path

import pytest
import run
from checkers import common, counting, place_value

SKILLS = {skill["id"]: skill for skill in run.load_skills()}
ALLOWED = run.allowed_misconceptions()


def piles(*numbers: int) -> dict:
    return {"type": "gem_piles", "piles": [{"hundreds": n // 100, "tens": n // 10 % 10, "ones": n % 10} for n in numbers]}


def line(low: int, high: int, every: int, markers=(), blanks=()) -> dict:
    return {"type": "number_line", "min": low, "max": high, "labeled_every": every, "markers": list(markers), "blanks": list(blanks)}


def make(skill_id: str, params: dict, prompt_line: str, prompt_params: dict, answer, distractors, visual=None, meta=None, model=None, representation=None, seed=1) -> dict:
    skill = SKILLS[skill_id]
    visual = visual or {}
    return {
        "skill_id": skill_id, "seed": seed,
        "representation": representation or skill["representations"][0],
        "prompt_line_id": prompt_line, "prompt_params": prompt_params,
        "answer": answer, "answer_modes": skill["answer_modes"],
        "distractors": [{"value": value, "misconception": name} for name, value in distractors],
        "visual": visual,
        "hint_steps": [
            {"kind": "repeat_highlight", "line_id": prompt_line, "params": prompt_params, "visual": {}, "highlight": list(prompt_params)},
            {"kind": "visual_model", "line_id": "bolt.hint.show_model", "params": {}, "visual": model or piles(34)},
            {"kind": "worked_example", "line_id": "bolt.hint.worked_example", "params": {}, "visual": {},
             "example": {"prompt_line_id": prompt_line, "prompt_params": {k: v + 1 for k, v in prompt_params.items()}, "answer": answer,
                         "answer_line_id": "z1.hint.example_number", "answer_params": {"answer": 1}}},
            {"kind": "easier_problem", "line_id": "bolt.hint.easier", "params": {}, "visual": {}, "easier_params": {"difficulty": -1}},
        ],
        "params": dict(params), "meta": meta or {},
    }


def good_problems() -> dict[str, dict]:
    """One correct problem per generator mode, built by hand from the definitions in the plan."""
    return {
        "objects": make("count.to_20.objects", {"mode": "objects", "min": 1, "max": 20}, "z1.count.prompt_objects", {}, 7,
                        [("off_by_one", 6), ("off_by_one", 8), ("double_counted", 9)], visual=piles(7),
                        model={"type": "ten_frame", "count": 7, "frames": 1}),
        "read": make("count.to_120.read", {"mode": "read", "min": 21, "max": 120}, "z1.count.prompt_read_line", {}, 47,
                     [("digit_swap", 74), ("off_by_one", 46), ("off_by_one", 48)], visual=line(30, 60, 10, [47])),
        "next": make("count.to_120.next", {"mode": "next", "min": 1, "max": 119}, "z1.count.prompt_next", {"a": 38, "b": 39}, 40,
                     [("off_by_one", 39), ("off_by_one", 41), ("decade_skip", 30)], model=line(30, 50, 10, [38, 39])),
        "between": make("count.to_120.between", {"mode": "between", "min": 1, "max": 120}, "z1.count.prompt_between", {"a": 47, "b": 49}, 48,
                        [("off_by_one", 47), ("off_by_one", 49)], model=line(40, 50, 10, [47, 49])),
        "strip": make("count.to_120.fill_strip", {"mode": "strip", "len": 5, "blanks": 2, "max": 120}, "z1.count.prompt_strip", {}, [61, 63],
                      [("off_by_one", [62, 64]), ("decade_skip", [71, 63])], visual=line(60, 64, 1, [], [61, 63]), model=line(60, 64, 1, [], [63])),
        "write": make("count.write.numeral", {"mode": "write", "min": 11, "max": 120}, "z1.count.prompt_write_piles", {}, 34,
                      [("digit_swap", 43)], visual=piles(34), representation="concrete"),
        "more_less": make("cmp.to_20.more_less", {"mode": "more_less", "max": 20}, "z1.cmp.prompt_more", {}, 1,
                          [("picked_smaller", 0)], visual=piles(5, 9), meta={"ask": "more", "tap_target": "pile"}, model=line(0, 20, 5, [5, 9])),
        "symbols": make("cmp.to_100.symbols", {"mode": "symbols", "max": 100}, "z1.cmp.prompt_symbol", {"a": 47, "b": 52}, "<",
                        [(("compared_ones_first"), ">"), ("thought_equal", "=")], meta={"conflict": True}, model=line(40, 60, 10, [47, 52])),
        "order": make("cmp.to_100.order3", {"mode": "order", "n": 3, "max": 100}, "z1.cmp.order_least_first", {}, [12, 35, 71],
                      [("reversed_order", [71, 35, 12]), ("compared_ones_first", [71, 12, 35])], visual=piles(35, 71, 12),
                      meta={"direction": "least_first", "numbers": [35, 71, 12]}, model=line(10, 80, 10, [35, 71, 12])),
        "build": make("pv.tens_ones.build", {"mode": "build", "min": 11, "max": 99}, "z1.dig.prompt_build_number", {"n": 34},
                      {"tens": 3, "ones": 4}, [("digit_swap", {"tens": 4, "ones": 3}), ("counted_tens_as_ones", {"tens": 0, "ones": 7})],
                      meta={"tools": ["ten", "one"]}),
        "read_concrete": make("pv.tens_ones.read", {"mode": "read", "min": 11, "max": 99}, "z1.pv.prompt_read_piles", {}, 34,
                              [("digit_swap", 43), ("counted_bars_as_ones", 7)], visual=piles(34), representation="concrete"),
        "expanded": make("pv.tens_ones.expanded", {"mode": "expanded", "min": 11, "max": 99}, "z1.pv.prompt_expanded", {"n": 34}, [30, 4],
                         [("digit_value_as_digit", [3, 4]), ("digit_swap", [40, 3])]),
        "digit_value": make("pv.tens_ones.digit_value", {"mode": "digit_value", "min": 11, "max": 99}, "z1.pv.prompt_digit_value", {"n": 34, "digit": 3}, 30,
                            [("digit_value_as_digit", 3), ("wrong_place", 4)], meta={"place": "tens"}),
        "ten_more": make("pv.tens.ten_more_less", {"mode": "ten_more_less", "min": 10, "max": 110}, "z1.pv.prompt_ten_more", {"n": 34}, 44,
                         [("changed_ones", 35), ("off_by_one", 45), ("off_by_one", 43)], visual=piles(34), meta={"direction": "more"}),
        "build_hundred": make("pv.hundred.intro", {"mode": "build_hundred", "min": 100, "max": 120}, "z1.pv.prompt_build_hundred", {"n": 113},
                              {"hundreds": 1, "tens": 1, "ones": 3},
                              [("counted_tens_as_ones", {"hundreds": 1, "tens": 0, "ones": 4}), ("digit_swap", {"hundreds": 1, "tens": 3, "ones": 1})],
                              meta={"tools": ["hundred", "ten", "one"]}),
        "trade_ten": make("pv.regroup.trade_ten", {"mode": "ones_to_ten", "max_tens": 8, "min_ones": 10, "max_ones": 19}, "z1.regroup.prompt_trade_ten",
                          {"tens": 3, "ones": 13}, {"tens": 4, "ones": 3},
                          [("forgot_regroup", {"tens": 3, "ones": 13}), ("traded_wrong_count", {"tens": 4, "ones": 4}), ("traded_wrong_count", {"tens": 4, "ones": 2})],
                          visual=piles(43), meta={"start": {"tens": 3, "ones": 13}}),
        "untrade": make("pv.regroup.untrade", {"mode": "ten_to_ones", "max_tens": 9, "max_ones": 9}, "z1.regroup.prompt_untrade",
                        {"tens": 4, "ones": 2}, {"tens": 3, "ones": 12},
                        [("forgot_regroup", {"tens": 4, "ones": 2}), ("traded_wrong_count", {"tens": 3, "ones": 11}), ("traded_wrong_count", {"tens": 3, "ones": 13})],
                        visual=piles(42), meta={"start": {"tens": 4, "ones": 2}}),
    }


def verdict(problem: dict, skill_id: str | None = None) -> list[str]:
    """Check `problem` against the skill it is supposed to be for (default: the one it names)."""
    return run.check_problem(problem, SKILLS[skill_id or problem["skill_id"]], ALLOWED)


# The two hand-made regroup piles use "tens" up to 4 and ones past 9, so their `piles` visual is built by hand.
def _fix_regroup_visuals(problems: dict[str, dict]) -> None:
    problems["trade_ten"]["visual"] = {"type": "gem_piles", "piles": [{"hundreds": 0, "tens": 3, "ones": 13}]}
    problems["untrade"]["visual"] = {"type": "gem_piles", "piles": [{"hundreds": 0, "tens": 4, "ones": 2}]}


GOOD = good_problems()
_fix_regroup_visuals(GOOD)


@pytest.mark.parametrize("name", sorted(GOOD))
def test_a_correct_problem_passes(name: str) -> None:
    assert verdict(copy.deepcopy(GOOD[name])) == []


def tamper(name: str, edit) -> list[str]:
    problem = copy.deepcopy(GOOD[name])
    edit(problem)
    return verdict(problem)


TAMPERS = [
    ("objects", lambda p: p.__setitem__("answer", 8), "do not add up"),
    ("objects", lambda p: p["distractors"][2].__setitem__("value", 12), "double_counted"),
    ("read", lambda p: p["visual"].__setitem__("markers", [48]), "arrow"),
    ("read", lambda p: p["distractors"][0].__setitem__("value", 47 + 1), "digit_swap"),
    ("next", lambda p: p.__setitem__("answer", 41), "not the number after"),
    ("next", lambda p: p["distractors"][2].__setitem__("value", 50), "decade_skip"),
    ("between", lambda p: p.__setitem__("answer", 47), "not between"),
    ("strip", lambda p: p.__setitem__("answer", [63, 61]), "in order"),
    ("strip", lambda p: p["visual"].__setitem__("blanks", [60, 63]), "match the answer"),
    ("strip", lambda p: p["distractors"][0].__setitem__("value", [62, 65]), "off_by_one"),
    ("strip", lambda p: (p.__setitem__("answer", [61, 64]), p["visual"].__setitem__("blanks", [61, 64])), "first or last"),
    ("write", lambda p: p.__setitem__("answer", 35), "do not add up"),
    ("more_less", lambda p: p.__setitem__("answer", 0), "should be pile 1"),
    ("more_less", lambda p: p["meta"].__setitem__("ask", "fewer"), "should be pile 0"),
    ("more_less", lambda p: p["visual"]["piles"][1].__setitem__("ones", 5), "different sizes"),
    ("symbols", lambda p: p.__setitem__("answer", ">"), "need"),
    ("symbols", lambda p: p["meta"].__setitem__("conflict", False), "conflict flag"),
    ("symbols", lambda p: p["distractors"][0].__setitem__("misconception", "reversed_symbol"), "wrong misconception name"),
    ("order", lambda p: p.__setitem__("answer", [71, 35, 12]), "expected"),
    ("order", lambda p: p["meta"].__setitem__("numbers", [12, 35, 71]), "do not match"),
    ("order", lambda p: p["distractors"][1].__setitem__("value", [12, 35, 71]), "compared_ones_first"),
    ("build", lambda p: p.__setitem__("answer", {"tens": 4, "ones": 3}), "tens and"),
    ("build", lambda p: p["distractors"][1].__setitem__("value", {"tens": 0, "ones": 8}), "counted_tens_as_ones"),
    ("read_concrete", lambda p: p.__setitem__("answer", 43), "do not add up"),
    ("expanded", lambda p: p.__setitem__("answer", [3, 4]), "30"),
    ("digit_value", lambda p: p.__setitem__("answer", 3), "worth"),
    ("digit_value", lambda p: p["meta"].__setitem__("place", "ones"), "worth"),
    ("ten_more", lambda p: p.__setitem__("answer", 24), "ten more than"),
    ("ten_more", lambda p: p["meta"].__setitem__("direction", "less"), "ten less"),
    ("build_hundred", lambda p: p.__setitem__("answer", {"hundreds": 1, "tens": 3, "ones": 1}), "hundred"),
    ("trade_ten", lambda p: p.__setitem__("answer", {"tens": 4, "ones": 4}), "changed the total"),
    ("trade_ten", lambda p: p["distractors"].pop(0), "forgot_regroup"),
    ("trade_ten", lambda p: p["distractors"][1].__setitem__("value", {"tens": 4, "ones": 3}), "equals the answer"),
    ("untrade", lambda p: p.__setitem__("answer", {"tens": 3, "ones": 11}), "changed the total"),
    ("untrade", lambda p: p["distractors"][1].__setitem__("value", {"tens": 3, "ones": 12 + 0}), "equals the answer"),
]


@pytest.mark.parametrize(("name", "edit", "fragment"), TAMPERS, ids=[f"{n}-{i}" for i, (n, _, _) in enumerate(TAMPERS)])
def test_a_wrong_problem_is_caught(name: str, edit, fragment: str) -> None:
    errors = tamper(name, edit)
    assert errors, "the tampered problem was accepted"
    assert any(fragment in error for error in errors), errors


# --- Generic structure checks --------------------------------------------------------------


@pytest.mark.parametrize(
    ("edit", "fragment"),
    [
        (lambda p: p.pop("meta"), "missing keys"),
        (lambda p: p.__setitem__("skill_id", "other.skill.id"), "skill_id"),
        (lambda p: p.__setitem__("representation", "magic"), "representation"),
        (lambda p: p.__setitem__("answer_modes", ["keyboard"]), "answer_modes"),
        (lambda p: p["prompt_params"].__setitem__("x", 1.5), "whole number"),
        (lambda p: p["distractors"].append({"value": 99, "misconception": "made_up_name"}), "unknown misconception"),
        (lambda p: p["distractors"].append({"value": 99, "misconception": "forgot_regroup"}), "not listed for the skill"),
        (lambda p: p["distractors"].append(dict(p["distractors"][0])), "duplicate distractor"),
        (lambda p: p["distractors"].clear(), "at least one distractor"),
        (lambda p: p["hint_steps"].pop(), "hint rungs"),
        (lambda p: p["hint_steps"][1].__setitem__("visual", {}), "no visual model"),
        (lambda p: p["hint_steps"][3]["easier_params"].__setitem__("difficulty", 0), "difficulty"),
        (lambda p: p["hint_steps"][2].pop("example"), "worked example"),
        (lambda p: p["hint_steps"][0].__setitem__("line_id", "z1.cmp.prompt_more"), "rung 1"),
        (lambda p: p["hint_steps"][1].__setitem__("visual", {"type": "hologram"}), "unknown visual type"),
    ],
)
def test_structure_problems_are_caught(edit, fragment: str) -> None:
    problem = copy.deepcopy(GOOD["objects"])
    edit(problem)
    errors = verdict(problem, "count.to_20.objects")
    assert any(fragment in error for error in errors), errors


def test_visual_checks() -> None:
    assert common.check_visual({}, "v") == []
    assert common.check_visual(line(5, 3, 1), "v")
    assert common.check_visual(line(0, 10, 1, markers=[11]), "v")
    assert common.check_visual({"type": "ten_frame", "count": 12, "frames": 1}, "v")
    assert common.check_visual({"type": "gem_piles", "piles": [{"hundreds": 0, "tens": -1, "ones": 0}]}, "v")
    assert common.check_visual({"type": "gem_piles", "piles": []}, "v")


def test_the_digit_swap_helper_is_string_based_and_correct() -> None:
    assert counting.swap_last_two_digits(34) == 43
    assert counting.swap_last_two_digits(107) == 170
    assert counting.swap_last_two_digits(40) == 4
    assert counting.swap_last_two_digits(7) == 7
    assert place_value.check is not None


def test_an_unknown_mode_is_reported_not_raised() -> None:
    problem = copy.deepcopy(GOOD["objects"])
    problem["params"]["mode"] = "juggling"
    assert any("unknown counting mode" in error for error in verdict(problem))


def test_a_malformed_export_is_a_failure_not_a_crash() -> None:
    problem = copy.deepcopy(GOOD["between"])
    del problem["prompt_params"]["a"]
    assert any("could not read" in error for error in verdict(problem))


# --- Runner ----------------------------------------------------------------------------------


def test_runner_knows_the_skills_and_misconceptions() -> None:
    # Counted per zone, so a later zone joining the skill map does not change the Phase 1-2 numbers.
    assert sum(1 for skill in SKILLS.values() if skill["zone"] <= 5) == 72 # Zones 1-5
    assert sum(1 for skill in SKILLS.values() if skill["zone"] == 6) == 14 # Zone 6 (Phase 4), with the two fraction previews
    assert sum(1 for skill in SKILLS.values() if skill["zone"] == 7) == 18 # Zone 7 (Phase 4)
    assert len(ALLOWED) >= 70
    assert len(ALLOWED) == 132 # 70 through Zone 5, 32 from Zone 6, 30 more from Zone 7
    assert {skill["generator"] for skill in SKILLS.values()} == set(run.CHECKERS) # every generator has a checker


def test_check_file_prefixes_failures_with_skill_and_seed(tmp_path: Path) -> None:
    bad = copy.deepcopy(GOOD["next"])
    bad["seed"] = 4242
    bad["answer"] = 99
    path = tmp_path / "next.jsonl"
    path.write_text(json.dumps(GOOD["next"]) + "\n" + json.dumps(bad) + "\n", encoding="utf-8")
    count, messages = run.check_file(path, SKILLS["count.to_120.next"], ALLOWED)
    assert count == 2
    assert messages and all(message.startswith("count.to_120.next seed 4242:") for message in messages)


def test_main_needs_a_godot_binary(monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> None:
    monkeypatch.delenv("GODOT", raising=False)
    monkeypatch.delenv("GODOT_BIN", raising=False)
    assert run.main(["--all"]) == 2
    assert "GODOT" in capsys.readouterr().err


def test_main_rejects_an_unknown_skill(capsys: pytest.CaptureFixture[str]) -> None:
    assert run.main(["--skill", "no.such.skill", "--godot", "/bin/true"]) == 2


def test_a_generator_the_exporter_has_not_got_is_skipped(monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str], tmp_path: Path) -> None:
    # Every generator of Zones 1-4 is built, so the skip path (for skills of later zones) is driven directly.
    monkeypatch.setattr(run, "export", lambda *args: run.EXIT_NOT_BUILT)
    assert run.main(["--skill", "add.to_10.sums", "--n", "5", "--godot", "/bin/true", "--out", str(tmp_path)]) == 0
    assert "skip   add.to_10.sums" in capsys.readouterr().out


# --- End to end (needs the Godot binary: set GODOT, as CI does) -------------------------------

GODOT = os.environ.get("GODOT") or os.environ.get("GODOT_BIN")
needs_godot = pytest.mark.skipif(not GODOT or not shutil.which(GODOT) and not Path(GODOT or "").exists(), reason="set GODOT to the Godot 4.7.2 executable")


@needs_godot
def test_end_to_end_one_skill(tmp_path: Path) -> None:
    assert run.main(["--skill", "pv.tens_ones.build", "--n", "300", "--godot", GODOT, "--out", str(tmp_path)]) == 0


@needs_godot
def test_end_to_end_every_skill(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    assert run.main(["--all", "--n", "120", "--godot", GODOT, "--out", str(tmp_path)]) == 0
    output = capsys.readouterr().out
    assert output.count("ok     ") == len(run.load_skills()) # every detailed skill (72 with Zone 5)
    assert "generator not built yet" not in output


def test_the_range_guard_catches_a_too_large_answer() -> None:
    # `not 1 <= first and answer <= 120` once parsed as `(first < 1) and ...`, so this never fired.
    problem = copy.deepcopy(GOOD["next"])
    problem["prompt_params"] = {"a": 198, "b": 199}
    problem["answer"] = 200
    assert any("within 1 to 120" in error for error in verdict(problem))


def test_difficulty_reaches_the_exporter_and_names_the_file(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    seen: list[tuple[str, int]] = []

    def fake_export(godot: str, skill_id: str, n: int, seed: int, out: Path, difficulty: int = 0) -> int:
        seen.append((out.name, difficulty))
        out.write_text(json.dumps(GOOD["next"]) + "\n", encoding="utf-8")
        return 0

    monkeypatch.setattr(run, "export", fake_export)
    assert run.main(["--skill", "count.to_120.next", "--n", "1", "--godot", "/bin/true", "--out", str(tmp_path), "--difficulty", "-1"]) == 0
    assert seen == [("count.to_120.next.d-1.jsonl", -1)]
