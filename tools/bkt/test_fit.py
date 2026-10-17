"""Tests for tools/bkt/fit.py: synthetic learners with known parameters must be recovered."""
import json
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import fit  # noqa: E402


def simulate(true: dict, learners: int, length: int, seed: int) -> list[list[bool]]:
    rng = random.Random(seed)
    sequences = []
    for _ in range(learners):
        known = rng.random() < true["prior"]
        seq = []
        for _ in range(length):
            right_chance = 1.0 - true["slip"] if known else true["guess"]
            seq.append(rng.random() < right_chance)
            if not known and rng.random() < true["learn"]:
                known = True
        sequences.append(seq)
    return sequences


DEFAULT = {"prior": 0.3, "learn": 0.2, "guess": 0.2, "slip": 0.1}


def test_recovers_known_parameters_within_005():
    for true in (
        {"prior": 0.30, "learn": 0.20, "guess": 0.20, "slip": 0.10},
        {"prior": 0.15, "learn": 0.35, "guess": 0.10, "slip": 0.08},
        {"prior": 0.40, "learn": 0.10, "guess": 0.25, "slip": 0.15},
    ):
        seqs = simulate(true, learners=2000, length=30, seed=7)
        got = fit.fit_sequences(seqs, DEFAULT, prior_strength=0.0)
        for key in fit.PARAM_KEYS:
            assert abs(got[key] - true[key]) <= 0.05, (key, true, got)
        assert got["n"] == 2000 * 30


def test_forward_backward_posteriors_are_probabilities():
    gamma, xi, ll = fit._forward_backward([True, False, True, True], DEFAULT)
    assert len(gamma) == 4 and len(xi) == 3
    for g0, g1 in gamma:
        assert abs(g0 + g1 - 1.0) < 1e-9
    assert all(0.0 <= x <= 1.0 for x in xi)
    assert ll < 0


def test_prior_strength_pulls_a_short_log_toward_defaults():
    # one child, one short run: with a strong pull the fit stays near the defaults
    seq = [[True] * 20]
    free = fit.fit_sequences(seq, DEFAULT, prior_strength=0.0)
    pulled = fit.fit_sequences(seq, DEFAULT, prior_strength=200.0)
    assert abs(pulled["slip"] - DEFAULT["slip"]) < abs(free["slip"] - DEFAULT["slip"]) + 1e-9
    assert abs(pulled["guess"] - DEFAULT["guess"]) < 0.08


def test_values_stay_inside_bounds():
    got = fit.fit_sequences([[False] * 40, [True] * 40], DEFAULT, prior_strength=0.0)
    for key in fit.PARAM_KEYS:
        lo, hi = fit.BOUNDS[key]
        assert lo <= got[key] <= hi


def test_only_first_tries_count():
    attempts = [
        {"ts": "2026-01-01T10:00:02Z", "skill_id": "a", "correct": True, "hints_used": 0},
        {"ts": "2026-01-01T10:00:01Z", "skill_id": "a", "correct": False, "hints_used": 0},
        {"ts": "2026-01-01T10:00:03Z", "skill_id": "a", "correct": True, "hints_used": 1},
        {"ts": "2026-01-01T10:00:04Z", "skill_id": "a", "correct": False, "hints_used": 0, "low_confidence_rejected": True},
        {"ts": "2026-01-01T10:00:05Z", "skill_id": "a", "correct": False, "hints_used": 0, "outcome": "rejected_recognition"},
        {"ts": "2026-01-01T10:00:06Z", "skill_id": "b", "correct": True, "hints_used": 0},
    ]
    assert fit.first_try_sequences(attempts) == {"a": [False, True], "b": [True]}


def test_load_attempts_reads_bundles_and_jsonl(tmp_path):
    entry = {"ts": "2026-01-01T10:00:00Z", "skill_id": "a", "correct": True, "hints_used": 0}
    bundle = tmp_path / "bundle.json"
    bundle.write_text(json.dumps({"format": "gem-mines-progress", "bundle_version": 1, "profile": {}, "attempts": [entry]}))
    jsonl = tmp_path / "attempts.jsonl"
    jsonl.write_text(json.dumps(entry) + "\n\nnot json\n" + json.dumps(entry) + "\n")
    assert fit.load_attempts(bundle) == [entry]
    assert fit.load_attempts(jsonl) == [entry, entry]


def test_skill_types_read_the_real_curriculum():
    types = fit.skill_types()
    assert "count.write.numeral" in types
    assert set(types.values()) <= {"default", "fact", "procedure", "concept"}


def test_main_writes_the_fitted_file_with_sample_counts(tmp_path, capsys):
    true = {"prior": 0.3, "learn": 0.2, "guess": 0.2, "slip": 0.1}
    seq = simulate(true, 1, 60, seed=3)[0]
    attempts = [{"ts": f"2026-01-01T10:{i // 60:02d}:{i % 60:02d}Z", "skill_id": "count.write.numeral",
                 "correct": c, "hints_used": 0} for i, c in enumerate(seq)]
    attempts += [{"ts": f"2026-01-02T10:00:{i:02d}Z", "skill_id": "cmp.to_20.more_less", "correct": True, "hints_used": 0}
                 for i in range(5)]
    log = tmp_path / "attempts.jsonl"
    log.write_text("\n".join(json.dumps(a) for a in attempts))
    out = tmp_path / "fitted.json"
    assert fit.main([str(log), "--out", str(out), "--date", "2027-02-02"]) == 0
    data = json.loads(out.read_text())
    assert data["schema_version"] == 1 and data["fit_date"] == "2027-02-02"
    assert data["skills"]["count.write.numeral"]["n"] == 60
    assert data["skills"]["cmp.to_20.more_less"]["n"] == 5
    assert "wrote" in capsys.readouterr().out


def test_an_empty_log_is_an_error(tmp_path):
    log = tmp_path / "empty.jsonl"
    log.write_text("")
    assert fit.main([str(log), "--out", str(tmp_path / "x.json")]) == 2
