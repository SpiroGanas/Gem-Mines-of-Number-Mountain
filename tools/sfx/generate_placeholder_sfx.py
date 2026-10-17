"""Synthesizes the placeholder sound effects (Sprint 4) and encodes them as OGG Vorbis.

Run:  python tools/sfx/generate_placeholder_sfx.py [--out assets/sfx/placeholder]

Build-time only; nothing here ships in the game. Standard library only (math, random, wave)
plus the `ffmpeg` command for the OGG step. Output is deterministic: the same code always
writes the same samples. Every sound is short, soft and never startling (GDD section 8);
the "soft_miss" sound for a not-quite answer is neutral, never a buzzer.

These are project-made stand-ins. Sprint 10 replaces them with a licensed CC0 pack
(see assets/CREDITS.md).
"""
from __future__ import annotations

import argparse
import math
import random
import shutil
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

SAMPLE_RATE = 44100
PEAK = 0.55          # headroom: nothing louder than about -5 dBFS
FADE_SECONDS = 0.006  # fade in/out so no sound starts or ends with a click

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUT = ROOT / "assets" / "sfx" / "placeholder"


def _silence(seconds: float) -> list[float]:
    return [0.0] * int(SAMPLE_RATE * seconds)


def _tone(freq: float, seconds: float, decay: float, vibrato: float = 0.0) -> list[float]:
    """A sine tone with an exponential decay (higher decay = shorter ring)."""
    count = int(SAMPLE_RATE * seconds)
    samples = []
    for i in range(count):
        t = i / SAMPLE_RATE
        wobble = 1.0 + vibrato * math.sin(2 * math.pi * 6.0 * t)
        samples.append(math.sin(2 * math.pi * freq * wobble * t) * math.exp(-decay * t))
    return samples


def _noise(rng: random.Random, seconds: float, decay: float, smooth: float) -> list[float]:
    """Low-passed noise with a decay. `smooth` near 1 is darker (more low-pass)."""
    count = int(SAMPLE_RATE * seconds)
    samples = []
    state = 0.0
    for i in range(count):
        state = smooth * state + (1.0 - smooth) * rng.uniform(-1.0, 1.0)
        samples.append(state * math.exp(-decay * (i / SAMPLE_RATE)))
    return samples


def _mix(*layers: list[float]) -> list[float]:
    length = max(len(layer) for layer in layers)
    mixed = [0.0] * length
    for layer in layers:
        for i, value in enumerate(layer):
            mixed[i] += value
    return mixed


def _delay(layer: list[float], seconds: float) -> list[float]:
    return _silence(seconds) + layer


def _finish(samples: list[float], gain: float = 1.0) -> list[float]:
    """Apply short fades at both ends, then normalize so the loudest sample is PEAK * gain."""
    fade = max(int(SAMPLE_RATE * FADE_SECONDS), 1)
    out = list(samples)
    for i in range(min(fade, len(out))):
        ramp = i / fade
        out[i] *= ramp
        out[-1 - i] *= ramp
    top = max(abs(s) for s in out) or 1.0
    scale = PEAK * gain / top
    return [s * scale for s in out]


def synthesize(name: str) -> list[float]:
    """The samples (floats in -1..1, mono, 44.1 kHz) for one named sound."""
    rng = random.Random(f"gem-mines:{name}")  # string seed: stable across runs and platforms
    if name == "tap":
        return _finish(_tone(660, 0.06, 55))
    if name == "select":
        return _finish(_mix(_tone(520, 0.12, 22), _delay(_tone(780, 0.12, 22), 0.05)))
    if name == "place":
        return _finish(_mix(_tone(400, 0.07, 60), _noise(rng, 0.03, 90, 0.7)))
    if name == "wobble":
        return _finish(_mix(_tone(110, 0.26, 9, vibrato=0.04), _noise(rng, 0.26, 10, 0.93)))
    if name == "crack":
        return _finish(_mix(_noise(rng, 0.11, 30, 0.55), _tone(80, 0.24, 14), _delay(_noise(rng, 0.05, 60, 0.5), 0.06)))
    if name == "gem":
        return _finish(_mix(_tone(880, 0.16, 16), _delay(_tone(1175, 0.16, 16), 0.07), _delay(_tone(1568, 0.22, 14), 0.14)))
    if name == "coin":
        return _finish(_mix(_tone(988, 0.1, 22), _delay(_tone(1319, 0.2, 14), 0.07)))
    if name == "soft_miss":
        # Neutral and gentle: one low, round tone that fades. Not a buzzer, not a sad slide.
        return _finish(_tone(294, 0.22, 11, vibrato=0.01), gain=0.6)
    if name == "fanfare":
        return _finish(_mix(_tone(523, 0.3, 7), _delay(_tone(659, 0.3, 7), 0.12), _delay(_tone(784, 0.5, 6), 0.24)))
    raise KeyError(name)


SOUND_NAMES = ("tap", "select", "place", "wobble", "crack", "gem", "coin", "soft_miss", "fanfare")


def write_wav(path: Path, samples: list[float]) -> None:
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        handle.writeframes(b"".join(int(max(-1.0, min(1.0, s)) * 32767).to_bytes(2, "little", signed=True) for s in samples))


def encode_ogg(wav_path: Path, ogg_path: Path) -> None:
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav_path), "-c:a", "libvorbis", "-q:a", "4", str(ogg_path)],
        check=True,
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args(argv)
    if shutil.which("ffmpeg") is None:
        print("ffmpeg is required to write OGG files", file=sys.stderr)
        return 1
    args.out.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        for name in SOUND_NAMES:
            wav_path = Path(tmp) / f"{name}.wav"
            write_wav(wav_path, synthesize(name))
            encode_ogg(wav_path, args.out / f"{name}.ogg")
            print("wrote", args.out / f"{name}.ogg")
    return 0


if __name__ == "__main__":
    sys.exit(main())
