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
