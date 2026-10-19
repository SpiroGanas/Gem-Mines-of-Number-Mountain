"""pytest: the placeholder music loops are calm, quiet, loop cleanly and are deterministic."""
from __future__ import annotations

import generate_placeholder_music as music
import pytest


@pytest.mark.parametrize("name", music.TRACK_NAMES)
def test_each_loop_has_headroom_and_a_sensible_length(name: str) -> None:
    samples = music.synthesize(name)
    seconds = len(samples) / music.SAMPLE_RATE
    assert 15 <= seconds <= 40
    assert max(abs(s) for s in samples) <= music.PEAK + 1e-9


@pytest.mark.parametrize("name", music.TRACK_NAMES)
def test_the_loop_point_is_silent_so_it_never_clicks(name: str) -> None:
    samples = music.synthesize(name)
    assert abs(samples[0]) < 0.02
    assert max(abs(s) for s in samples[-200:]) < 0.05


@pytest.mark.parametrize("name", music.TRACK_NAMES)
def test_the_tempo_is_calm_and_synthesis_is_deterministic(name: str) -> None:
    assert music.TRACKS[name]["bpm"] <= 80 # never urgent
    assert music.synthesize(name)[:2000] == music.synthesize(name)[:2000]


def test_every_zone_group_and_the_build_site_has_a_loop() -> None:
    assert {"hub", "mine", "mine_z4", "mine_z5", "build"} <= set(music.TRACK_NAMES)


@pytest.mark.parametrize("name", music.TRACK_NAMES)
def test_chords_cover_the_melody_so_the_loop_has_no_gap(name: str) -> None:
    track = music.TRACKS[name]
    assert len(track["chords"]) * 4 == len(track["melody"])


def test_prime_caverns_bells_ring_only_on_prime_beats() -> None:
    primes = {2, 3, 5, 7, 11, 13}
    for index, note in enumerate(music.TRACKS["mine_z5"]["melody"]):
        if note is not None:
            assert index % 16 in primes


def test_crystal_shards_bells_ring_only_on_the_even_beats() -> None:
    for index, note in enumerate(music.TRACKS["mine_z7"]["melody"]):
        if note is not None:
            assert index % 2 == 0


def test_the_loops_are_different_tunes() -> None:
    melodies = [tuple(music.TRACKS[name]["melody"]) for name in music.TRACK_NAMES]
    assert len(set(melodies)) == len(melodies)


def test_the_loudnorm_filter_uses_the_measured_values_and_a_linear_gain() -> None:
    measured = {"input_i": "-27.1", "input_tp": "-9.0", "input_lra": "4.2", "input_thresh": "-37.5", "target_offset": "0.3"}
    text = music.loudnorm_filter(measured)
    assert "linear=true" in text and "measured_I=-27.1" in text and f"I={music.TARGET_LUFS}" in text
