"""Writes the fixtures the GDScript tests compare against (run after retraining).

    python tools/handwriting/make_fixtures.py

tests/handwriting/fixtures/raster_cases.json   strokes -> 28x28 picture, made by raster.py
tests/handwriting/fixtures/net_cases.json      picture -> logits and reading, made by the numpy
                                               forward pass over assets/handwriting/digit_net.json
Coordinates are rounded to 6 decimals so both languages start from exactly the same numbers.
"""
from __future__ import annotations

import json
import random
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))

import export_weights  # noqa: E402
import model  # noqa: E402
import raster  # noqa: E402
import synth  # noqa: E402

OUT = Path(__file__).resolve().parents[2] / "tests" / "handwriting" / "fixtures"


def _round_strokes(strokes):
    return [[[round(x, 6), round(y, 6)] for x, y in s] for s in strokes]


def raster_cases() -> list[dict]:
    rng = random.Random(77)
    cases = []
    for digit in (0, 1, 2, 3, 4, 5, 6, 7, 8, 9):
        strokes, bw, bh = synth.make_sample(digit, rng)
        cases.append({"name": f"synthetic_{digit}", "strokes": _round_strokes(strokes), "box": [round(bw, 3), round(bh, 3)]})
    strokes, bw, bh = synth.make_sample(3, rng, mirrored=True)
    cases.append({"name": "synthetic_3_mirrored", "strokes": _round_strokes(strokes), "box": [round(bw, 3), round(bh, 3)]})
    cases.append({"name": "tall_thin_one", "strokes": [[[0.5, 0.1], [0.5, 0.9]]], "box": [200.0, 400.0]})
    cases.append({"name": "single_point_plus_line", "strokes": [[[0.3, 0.3]], [[0.2, 0.2], [0.8, 0.85]]], "box": [300.0, 300.0]})
    cases.append({"name": "dot_is_no_digit", "strokes": [[[0.5, 0.5]]], "box": [300.0, 400.0]})
    cases.append({"name": "tiny_scribble_is_no_digit", "strokes": [[[0.5, 0.5], [0.52, 0.51], [0.5, 0.53]]], "box": [300.0, 400.0]})
    cases.append({"name": "no_strokes", "strokes": [], "box": [300.0, 400.0]})
    cases.append({"name": "empty_stroke_ignored", "strokes": [[], [[0.2, 0.9], [0.8, 0.1]]], "box": [240.0, 360.0]})
    for case in cases:
        strokes = [[tuple(p) for p in s] for s in case["strokes"]]
        picture = raster.rasterize(strokes, case["box"][0], case["box"][1])
        case["expected"] = None if picture is None else [round(float(v), 6) for v in picture.ravel()]
    return cases


def net_cases(weights) -> list[dict]:
    rng = random.Random(4242)
    cases = []
    for digit in range(10):
        for mirrored in (False,) if digit in (0, 1, 8) else (False, True):
            strokes, bw, bh = synth.make_sample(digit, rng, mirrored)
            strokes = [[tuple(p) for p in s] for s in _round_strokes(strokes)]
            picture = raster.rasterize(strokes, round(bw, 3), round(bh, 3))
            logits = model.forward(weights, picture[None])[0]
            reading = model.read(weights, picture)
            cases.append({"name": f"synthetic_{digit}{'_mirrored' if mirrored else ''}",
                          "strokes": [[list(p) for p in s] for s in strokes], "box": [round(bw, 3), round(bh, 3)],
                          "logits": [round(float(v), 6) for v in logits], "reading": {k: (round(v, 6) if isinstance(v, float) else v) for k, v in reading.items()}})
    return cases


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "raster_cases.json").write_text(json.dumps({"cases": raster_cases()}, separators=(",", ":")) + "\n", encoding="utf-8")
    print(f"wrote {OUT / 'raster_cases.json'}")
    if export_weights.DEFAULT_PATH.exists():
        weights, _ = export_weights.read()
        (OUT / "net_cases.json").write_text(json.dumps({"cases": net_cases(weights)}, separators=(",", ":")) + "\n", encoding="utf-8")
        print(f"wrote {OUT / 'net_cases.json'}")
    else:
        print("no assets/handwriting/digit_net.json yet; train first for net_cases.json")
    return 0


if __name__ == "__main__":
    sys.exit(main())
