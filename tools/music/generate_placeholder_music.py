"""Synthesizes the placeholder music loops (Sprint 10) and encodes them as OGG Vorbis.

Run:  python tools/music/generate_placeholder_music.py [--out assets/music/placeholder]

Build-time only; nothing here ships in the game except the OGG files it writes. Standard library
plus the `ffmpeg` command, like tools/sfx/. Deterministic: the same code always writes the same
samples. The direction (GDD section 8): calm, looping, low-key, never urgent. Each track is a slow
pentatonic melody over soft sustained chords; every note dies away before the loop point, so the
loop never clicks. The game sets `loop` on the streams when it plays them.
"""
from __future__ import annotations

import argparse
import math
import shutil
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

SAMPLE_RATE = 22050
PEAK = 0.45
ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUT = ROOT / "assets" / "music" / "placeholder"

# MIDI note numbers. Melodies are 16 beats of (note or None for a rest); chords last 4 beats.
TRACKS = {
    "hub": {
        "bpm": 72,
        "melody": [72, None, 76, 79, 81, None, 79, 76, 74, None, 72, 74, 76, None, None, None] * 2,
        "chords": [[48, 55, 64], [45, 52, 60], [41, 48, 57], [43, 50, 59]] * 2,
    },
    "mine": {
        "bpm": 66,
        "melody": [69, None, 72, None, 74, 76, None, 74, 72, None, 69, None, 67, None, None, None] * 2,
        "chords": [[45, 52, 60], [41, 48, 57], [43, 50, 59], [40, 47, 55]] * 2,
    },
}
TRACK_NAMES = tuple(TRACKS)


def frequency(note: int) -> float:
    return 440.0 * 2 ** ((note - 69) / 12)


def _add(buffer: list[float], start: int, samples: list[float]) -> None:
    for i, value in enumerate(samples):
        if start + i < len(buffer):
            buffer[start + i] += value


def _bell(freq: float, seconds: float, level: float) -> list[float]:
    """A soft mallet note: sine plus a quiet octave, quick attack, long decay."""
    count = int(SAMPLE_RATE * seconds)
    attack = int(SAMPLE_RATE * 0.01)
    out = []
    for i in range(count):
        t = i / SAMPLE_RATE
        env = (i / attack if i < attack else 1.0) * math.exp(-3.2 * t)
        out.append(level * env * (math.sin(2 * math.pi * freq * t) + 0.25 * math.sin(4 * math.pi * freq * t)))
    return out


def _pad(freqs: list[float], seconds: float, level: float) -> list[float]:
    """A chord that swells in and fades out within its own length."""
    count = int(SAMPLE_RATE * seconds)
    out = []
    for i in range(count):
        t = i / SAMPLE_RATE
        env = math.sin(math.pi * i / count) ** 2
        out.append(level * env * sum(math.sin(2 * math.pi * f * t) for f in freqs) / len(freqs))
    return out


def synthesize(name: str) -> list[float]:
    track = TRACKS[name]
    beat = 60.0 / track["bpm"]
    beats = len(track["melody"])
    total = int(SAMPLE_RATE * beat * beats)
    buffer = [0.0] * total
    for index, chord in enumerate(track["chords"]):
        _add(buffer, int(SAMPLE_RATE * beat * 4 * index), _pad([frequency(n) for n in chord], beat * 4, 0.5))
    for index, note in enumerate(track["melody"]):
        if note is None:
            continue
        # A note never rings past the end of the loop.
        length = min(beat * 3, (beats - index) * beat)
        _add(buffer, int(SAMPLE_RATE * beat * index), _bell(frequency(note), length, 0.6))
    top = max(abs(s) for s in buffer) or 1.0
    return [s * PEAK / top for s in buffer]


def write_wav(path: Path, samples: list[float]) -> None:
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        handle.writeframes(b"".join(int(max(-1.0, min(1.0, s)) * 32767).to_bytes(2, "little", signed=True) for s in samples))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args(argv)
    if shutil.which("ffmpeg") is None:
        print("ffmpeg is required to write OGG files", file=sys.stderr)
        return 1
    args.out.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        for name in TRACK_NAMES:
            wav_path = Path(tmp) / f"{name}.wav"
            write_wav(wav_path, synthesize(name))
            out = args.out / f"{name}.ogg"
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav_path), "-c:a", "libvorbis", "-q:a", "2", str(out)], check=True)
            print("wrote", out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
