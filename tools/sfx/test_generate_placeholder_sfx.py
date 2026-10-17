"""pytest: the placeholder sounds are short, soft, click-free and deterministic."""
from __future__ import annotations

import shutil
from pathlib import Path

import generate_placeholder_sfx as sfx
import pytest


@pytest.mark.parametrize("name", sfx.SOUND_NAMES)
def test_each_sound_is_short_and_has_headroom(name: str) -> None:
    samples = sfx.synthesize(name)
    seconds = len(samples) / sfx.SAMPLE_RATE
    assert 0.03 <= seconds <= 0.9, f"{name} is {seconds:.2f}s"
    peak = max(abs(s) for s in samples)
    assert peak <= sfx.PEAK + 1e-9, f"{name} peaks at {peak:.2f}"
    assert peak >= sfx.PEAK * 0.5, f"{name} is too quiet ({peak:.2f})"


@pytest.mark.parametrize("name", sfx.SOUND_NAMES)
def test_each_sound_starts_and_ends_at_silence_so_it_cannot_click(name: str) -> None:
    samples = sfx.synthesize(name)
    assert abs(samples[0]) < 0.01
    assert abs(samples[-1]) < 0.01


@pytest.mark.parametrize("name", sfx.SOUND_NAMES)
def test_synthesis_is_deterministic(name: str) -> None:
    assert sfx.synthesize(name) == sfx.synthesize(name)


def test_unknown_sound_is_an_error() -> None:
    with pytest.raises(KeyError):
        sfx.synthesize("nope")


def test_the_miss_sound_is_quieter_than_the_crack() -> None:
    def peak(name: str) -> float:
        return max(abs(s) for s in sfx.synthesize(name))

    assert peak("soft_miss") < peak("crack")


@pytest.mark.skipif(shutil.which("ffmpeg") is None, reason="ffmpeg not installed")
def test_main_writes_every_ogg_file(tmp_path: Path) -> None:
    assert sfx.main(["--out", str(tmp_path)]) == 0
    written = sorted(p.stem for p in tmp_path.glob("*.ogg"))
    assert written == sorted(sfx.SOUND_NAMES)
    assert all((tmp_path / f"{name}.ogg").read_bytes()[:4] == b"OggS" for name in sfx.SOUND_NAMES)
