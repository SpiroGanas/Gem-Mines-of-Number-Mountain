"""Synthesizes the game's music loops (Sprint 10, per-zone loops Sprint 20) as OGG Vorbis.

Run:  python tools/music/generate_placeholder_music.py [--out assets/music/placeholder]

Build-time only; nothing here ships in the game except the OGG files it writes. Standard library
plus the `ffmpeg` command, like tools/sfx/. Deterministic: the same code always writes the same
samples. The direction (GDD section 8): calm, looping, low-key, never urgent. Each track is a slow
pentatonic melody over soft sustained chords; every note dies away before the loop point, so the
loop never clicks. The game sets `loop` on the streams when it plays them.

Sprint 20 (Spiro: no artist or licensed music, synthesize per zone) adds one loop per zone group
and one for the build site. Which screen plays which file:

    hub.ogg      workshop hub, museum, garage, settings (Sprint 10)
    mine.ogg     the mine in Zones 1-3 (Sprint 10; the "mine_z1_3" loop)
    mine_z4.ogg  the mine in Zone 4, Factor Workshop: a busy little mallet tune, like a workbench
    mine_z5.ogg  the mine in Zone 5, Prime Caverns: high crystal bells that ring only on prime
                 beats (2, 3, 5, 7, 11, 13 of each 16) over slow, spacious chords
    mine_z6.ogg  the mine in Zone 6, Gear Works (Phase 4): two interlocking figures, one every 3 beats
                 and one every 4, that meet on beat 12 (their least common multiple), over steady chords
    build.ogg    the build site and the crafting bench: a short, bright, steady loop
    mine_z7.ogg  the mine in Zone 7, Crystal Shards (Phase 4): glassy bells that ring only on the
                 halves, quarters and eighths of each 16 beats, like a crystal split into shards
    mine_z9.ogg  the mine in Zone 9, Pattern Grotto (Phase 4): bells only on the Fibonacci beats
                 (1, 2, 3, 5, 8, 13) of each 16 over slow chords

Every loop is loudness-normalized to TARGET_LUFS with ffmpeg's two-pass `loudnorm` filter (one
linear gain, so the dynamics are untouched), so a cross-fade between screens never jumps in volume.
"""
from __future__ import annotations

import argparse
import json
import math
import shutil
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

SAMPLE_RATE = 22050
PEAK = 0.45
# Integrated loudness of every loop (EBU R128), under the sound effects so music never covers them.
TARGET_LUFS = -20.0
TRUE_PEAK = -3.0
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
    # Zone 4, Factor Workshop: D dorian, a stepping mallet tune.
    "mine_z4": {
        "bpm": 70,
        "melody": [62, 65, 69, None, 67, 65, 64, None, 62, None, 64, 65, 67, None, None, None,
                   69, None, 67, 65, 64, None, 65, 67, 69, None, 72, 69, 67, None, None, None],
        "chords": [[38, 45, 53], [43, 50, 59], [41, 48, 57], [45, 52, 60],
                   [38, 45, 53], [36, 43, 52], [43, 50, 59], [38, 45, 57]],
    },
    # Zone 5, Prime Caverns: E minor pentatonic bells only on the prime beats of each 16.
    "mine_z5": {
        "bpm": 60,
        "melody": [None, None, 76, 79, None, 83, None, 81, None, None, None, 79, None, 76, None, None,
                   None, None, 74, 76, None, 79, None, 76, None, None, None, 74, None, 71, None, None],
        "chords": [[40, 47, 55], [36, 43, 52], [43, 50, 59], [38, 45, 54],
                   [40, 47, 55], [36, 43, 52], [38, 45, 54], [40, 47, 59]],
    },
    # Zone 6, Gear Works: G major pentatonic. A low "gear" note every 3 beats and a high one every 4
    # beats line up only on the beats that are multiples of 12 (the least common multiple).
    "mine_z6": {
        "bpm": 68,
        "melody": [79, None, None, 67, 81, None, 67, None, 83, 67, None, None, 79, None, None, 67,
                   81, None, 67, None, 83, 67, None, None, 74, None, None, 67, 76, None, 67, None,
                   79, 67, None, None],
        "chords": [[43, 50, 59], [40, 47, 55], [36, 43, 52], [38, 45, 54], [43, 50, 59],
                   [40, 47, 55], [36, 43, 52], [38, 45, 54], [43, 50, 59]],
    },
    # Zone 7, Crystal Shards: A major pentatonic glass bells on the even beats only (the shards of 16).
    "mine_z7": {
        "bpm": 62,
        "melody": [81, None, 76, None, 78, None, None, None, 76, None, 73, None, 71, None, None, None,
                   73, None, 76, None, 81, None, 83, None, 78, None, 76, None, 73, None, None, None],
        "chords": [[45, 52, 61], [42, 49, 57], [38, 45, 54], [40, 47, 56],
                   [45, 52, 61], [38, 45, 57], [40, 47, 56], [45, 52, 64]],
    },
    # Zone 9, Pattern Grotto: D major pentatonic bells only on the Fibonacci beats (1, 2, 3, 5, 8, 13) of
    # each 16: a tune that grows like the sequence.
    "mine_z9": {
        "bpm": 64,
        "melody": [None, 74, 76, 78, None, 81, None, None, 83, None, None, None, None, 81, None, None,
                   None, 78, 76, 74, None, 76, None, None, 78, None, None, None, None, 74, None, None],
        "chords": [[38, 45, 54], [43, 50, 59], [47, 54, 62], [45, 52, 61],
                   [38, 45, 54], [43, 50, 59], [45, 52, 61], [38, 45, 57]],
    },
    # Build site and crafting bench: F major, bright and short (20 beats).
    "build": {
        "bpm": 76,
        "melody": [65, 69, 72, None, 69, None, 70, 72, 74, None, 72, 70, 69, None, 67, None, 65, None, None, None],
        "chords": [[41, 48, 57], [46, 53, 62], [48, 55, 64], [43, 50, 58], [41, 48, 57]],
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


def measure_loudness(wav_path: Path) -> dict[str, str]:
    """First loudnorm pass: ffmpeg measures the loop and prints its loudness as JSON."""
    result = subprocess.run(
        ["ffmpeg", "-hide_banner", "-i", str(wav_path), "-af", f"loudnorm=I={TARGET_LUFS}:TP={TRUE_PEAK}:LRA=11:print_format=json", "-f", "null", "-"],
        capture_output=True, text=True, check=True)
    text = result.stderr
    return json.loads(text[text.rindex("{"):text.rindex("}") + 1])


def loudnorm_filter(measured: dict[str, str]) -> str:
    """Second loudnorm pass: one linear gain to the target, so the loop's dynamics are untouched."""
    return (f"loudnorm=I={TARGET_LUFS}:TP={TRUE_PEAK}:LRA=11:linear=true"
            f":measured_I={measured['input_i']}:measured_TP={measured['input_tp']}"
            f":measured_LRA={measured['input_lra']}:measured_thresh={measured['input_thresh']}"
            f":offset={measured['target_offset']}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--track", action="append", choices=TRACK_NAMES,
                        help="write only this loop (repeatable); default: every loop")
    args = parser.parse_args(argv)
    if shutil.which("ffmpeg") is None:
        print("ffmpeg is required to write OGG files", file=sys.stderr)
        return 1
    args.out.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        for name in args.track or TRACK_NAMES:
            wav_path = Path(tmp) / f"{name}.wav"
            write_wav(wav_path, synthesize(name))
            out = args.out / f"{name}.ogg"
            loudnorm = loudnorm_filter(measure_loudness(wav_path))
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav_path), "-af", loudnorm, "-ar", str(SAMPLE_RATE), "-c:a", "libvorbis", "-q:a", "2", str(out)], check=True)
            print("wrote", out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
