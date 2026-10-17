"""pytest: curriculum data is valid (P1-S02-03).

Two kinds of tests: the real repository data must pass every check, and the checks
themselves must catch deliberately broken data (so a green run means something).
"""
from __future__ import annotations

import copy
from pathlib import Path

import curriculum_check as cc
import pytest

# ---------------------------------------------------------------------------
# The real data
# ---------------------------------------------------------------------------


def test_repository_curriculum_has_no_problems() -> None:
    assert cc.check_all() == []


def test_all_twelve_zones_exist_with_expected_status() -> None:
    zones = {data["zone"]: data["status"] for _, data in cc.load_zone_files()}
    assert sorted(zones) == list(range(1, 13))
    assert all(zones[z] == "detailed" for z in (1, 2, 3))


def test_mvp_zones_hold_about_45_skills() -> None:
    count = sum(len(d["skills"]) for _, d in cc.load_zone_files() if d["zone"] <= 3)
    assert 40 <= count <= 50


def test_skill_ids_are_unique_across_all_zones() -> None:
    ids = [s["id"] for _, d in cc.load_zone_files() for s in d["skills"]]
    assert len(ids) == len(set(ids))


def test_whole_map_is_close_to_the_planned_180_skills() -> None:
    total = sum(len(d["skills"]) for _, d in cc.load_zone_files())
    assert 160 <= total <= 200


def test_every_zone_1_skill_chain_starts_from_counting() -> None:
    """Every Zone 1-3 skill is reachable from a root skill (no orphaned islands)."""
    skills = {s["id"]: s for _, d in cc.load_zone_files() if d["status"] == "detailed" for s in d["skills"]}
    roots = {sid for sid, s in skills.items() if not s["prereqs"]}
    assert roots == {"count.to_20.objects"}


# ---------------------------------------------------------------------------
# The checks themselves
# ---------------------------------------------------------------------------


def _good_skill(**overrides: object) -> dict:
    skill = {
        "id": "a.b.c", "name": "A skill", "prereqs": [], "generator": "CountingGenerator",
        "params": {}, "representations": ["concrete"], "answer_modes": ["tap"], "terms": [],
        "bkt_type": "default", "is_fact_skill": False, "misconceptions": ["off_by_one"],
    }
    skill.update(overrides)
    return skill


def _zone_file(skills: list[dict], zone: int = 1) -> tuple:
    name = f"z{zone:02d}_test.json"
    data = {"zone": zone, "zone_id": f"z{zone:02d}_test", "name": "Test", "status": "detailed", "skills": skills}
    return Path(name), data


def _errors_for(skills: list[dict], vocabulary: dict | None = None) -> list[str]:
    return cc.check_skill_map(
        [_zone_file(skills)], vocabulary or {}, {"off_by_one": "x"},
        {"default": {}, "fact": {}, "procedure": {}, "concept": {}},
    )


def _without_missing_zone_noise(errors: list[str]) -> list[str]:
    return [e for e in errors if not e.startswith("skill map: missing zone files")]


def test_find_cycle_returns_none_for_a_dag() -> None:
    assert cc.find_cycle({"a": [], "b": ["a"], "c": ["a", "b"]}) is None


def test_find_cycle_reports_the_cycle() -> None:
    cycle = cc.find_cycle({"a": ["c"], "b": ["a"], "c": ["b"]})
    assert cycle is not None and cycle[0] == cycle[-1]
    assert set(cycle) == {"a", "b", "c"}


def test_find_cycle_catches_a_self_loop() -> None:
    assert cc.find_cycle({"a": ["a"]}) == ["a", "a"]


def test_good_synthetic_skill_passes() -> None:
    assert _without_missing_zone_noise(_errors_for([_good_skill()])) == []


@pytest.mark.parametrize(
    ("override", "fragment"),
    [
        ({"id": "NotAnId"}, "topic.subtopic.action"),
        ({"generator": "NopeGenerator"}, "unknown generator"),
        ({"prereqs": ["a.b.c"]}, "itself as a prerequisite"),
        ({"prereqs": ["x.y.z"]}, "does not exist"),
        ({"representations": ["magic"]}, "unknown values"),
        ({"answer_modes": []}, "non-empty list"),
        ({"answer_modes": ["tap", "tap"]}, "without duplicates"),
        ({"terms": ["ghost"]}, "not in vocabulary.json"),
        ({"bkt_type": "weird"}, "bkt_type must be one of"),
        ({"is_fact_skill": True}, "fact skills must use bkt_type"),
        ({"misconceptions": ["made_up"]}, "not in misconceptions.json"),
        ({"misconceptions": []}, "non-empty list of names"),
        ({"name": " "}, "name must be"),
    ],
)
def test_check_skill_map_catches_bad_skills(override: dict, fragment: str) -> None:
    errors = _without_missing_zone_noise(_errors_for([_good_skill(**override)]))
    assert any(fragment in e for e in errors), errors


def test_check_skill_map_catches_duplicate_ids_and_unknown_keys() -> None:
    errors = _errors_for([_good_skill(), _good_skill()])
    assert any("duplicate skill id" in e for e in errors)
    extra = _good_skill()
    extra["surprise"] = 1
    assert any("keys must be exactly" in e for e in _errors_for([extra]))


def test_check_skill_map_catches_a_prerequisite_cycle() -> None:
    skills = [_good_skill(id="a.b.one", prereqs=["a.b.two"]), _good_skill(id="a.b.two", prereqs=["a.b.one"])]
    assert any("prerequisite cycle" in e for e in _errors_for(skills))


def test_check_skill_map_catches_a_term_used_before_it_is_introduced() -> None:
    vocab = {"later": {"zone": 3}}
    errors = _errors_for([_good_skill(terms=["later"])], vocab)
    assert any("introduced in zone 3" in e for e in errors)


def test_check_skill_map_catches_prerequisite_in_a_later_zone() -> None:
    early = _zone_file([_good_skill(id="a.b.early", prereqs=["a.b.late"])], zone=1)
    late = _zone_file([_good_skill(id="a.b.late")], zone=2)
    errors = cc.check_skill_map([early, late], {}, {"off_by_one": "x"}, {"default": {}, "fact": {}, "procedure": {}, "concept": {}})
    assert any("later zone" in e for e in errors)


def test_check_skill_map_requires_zone_file_name_to_match() -> None:
    path, data = _zone_file([_good_skill()])
    data["zone"] = 2
    errors = cc.check_skill_map([(path, data)], {}, {"off_by_one": "x"}, {"default": {}, "fact": {}, "procedure": {}, "concept": {}})
    assert any("does not match the file name prefix" in e for e in errors)


def test_outline_skills_may_only_carry_id_and_name() -> None:
    path, data = _zone_file([{"id": "a.b.c", "name": "Outline skill", "prereqs": []}])
    data["status"] = "outline"
    errors = cc.check_skill_map([(path, data)], {}, {}, {})
    assert any("keys must be exactly" in e for e in errors)


def test_bkt_defaults_checks_reject_bad_probabilities() -> None:
    bkt = copy.deepcopy(cc.load_bkt_defaults())
    assert cc.check_bkt_defaults(bkt) == []
    bkt["default"]["guess"] = 1.2
    assert any("default.guess" in e for e in cc.check_bkt_defaults(bkt))
    bkt = copy.deepcopy(cc.load_bkt_defaults())
    bkt["concept"]["guess"], bkt["concept"]["slip"] = 0.6, 0.5
    assert any("degenerate" in e for e in cc.check_bkt_defaults(bkt))
    bkt = copy.deepcopy(cc.load_bkt_defaults())
    del bkt["fact"]["fluency_ms"]
    assert any("fluency_ms" in e for e in cc.check_bkt_defaults(bkt))


def test_vocabulary_check_requires_lines_in_the_text_table() -> None:
    vocab = {"digit": {"zone": 1, "term_line_id": "vocab.digit.term", "definition_line_id": "vocab.digit.nope", "picture": None}}
    errors = cc.check_vocabulary(vocab, {"vocab.digit.term"})
    assert errors == ["vocabulary: 'digit'.definition_line_id 'vocab.digit.nope' is not in text/lines.csv"]


def test_misconception_names_must_be_snake_case_with_descriptions() -> None:
    errors = cc.check_misconceptions({"Bad Name": "ok", "good_name": ""})
    assert len(errors) == 2


def test_every_misconception_needs_bolts_hint_line() -> None:
    errors = cc.check_misconceptions({"digit_swap": "Swapped the digits.", "new_mistake": "Something new."}, {"bolt.misconception.digit_swap"})
    assert errors == ["misconceptions: 'new_mistake' has no hint line bolt.misconception.new_mistake in text/lines.csv"]
