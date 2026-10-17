"""Procedural digit strokes: a stand-in for a stroke dataset (none is reachable at build time).

Each digit is a few hand-placed control points joined by a Catmull-Rom spline, then wobbled,
slanted, rotated, squashed and sampled sparsely like touch events. This tests the whole path from
strokes to answer (rasterizer + network) without any picture of a real child's writing. It is NOT
a stand-in for Charlie's digits: accuracy here only shows the plumbing works and that the network
copes with line-drawn digits. The real bar (97%) is measured on captured digits (private/).
"""
from __future__ import annotations

import math
import random

# Control points in a unit square, y down. One list per stroke.
TEMPLATES: dict[int, list[list[tuple[float, float]]]] = {
    0: [[(0.5, 0.05), (0.2, 0.2), (0.15, 0.5), (0.22, 0.8), (0.5, 0.95), (0.78, 0.8), (0.85, 0.5), (0.8, 0.2), (0.5, 0.05)]],
    1: [[(0.28, 0.3), (0.5, 0.1), (0.5, 0.5), (0.5, 0.92)]],
    2: [[(0.2, 0.28), (0.35, 0.1), (0.6, 0.08), (0.78, 0.25), (0.65, 0.5), (0.2, 0.88), (0.82, 0.88)]],
    3: [[(0.2, 0.15), (0.5, 0.06), (0.76, 0.2), (0.5, 0.46), (0.8, 0.65), (0.7, 0.86), (0.45, 0.94), (0.18, 0.85)]],
    4: [[(0.68, 0.08), (0.2, 0.62), (0.88, 0.62)], [(0.66, 0.1), (0.66, 0.93)]],
    5: [[(0.76, 0.1), (0.32, 0.1), (0.26, 0.45), (0.55, 0.4), (0.8, 0.58), (0.7, 0.85), (0.45, 0.93), (0.2, 0.85)]],
    6: [[(0.7, 0.08), (0.4, 0.28), (0.24, 0.6), (0.34, 0.88), (0.6, 0.92), (0.76, 0.72), (0.6, 0.5), (0.35, 0.55), (0.27, 0.66)]],
    7: [[(0.2, 0.12), (0.82, 0.12), (0.45, 0.92)]],
    8: [[(0.5, 0.5), (0.25, 0.3), (0.5, 0.08), (0.75, 0.3), (0.5, 0.5), (0.2, 0.72), (0.5, 0.94), (0.8, 0.72), (0.5, 0.5)]],
    9: [[(0.74, 0.36), (0.5, 0.08), (0.26, 0.3), (0.5, 0.52), (0.74, 0.36), (0.72, 0.62), (0.56, 0.93)]],
}


def _catmull_rom(points, per_segment: int = 12):
    pts = [points[0]] + list(points) + [points[-1]]
    out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[i + 1], pts[i + 2]
        for k in range(per_segment):
            t = k / per_segment
            t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * ((2 * p1[j]) + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t2
                                    + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t3) for j in (0, 1)))
    out.append(points[-1])
    return out


def make_sample(digit: int, rng: random.Random, mirrored: bool = False):
    """(strokes normalized to the box, box_w, box_h) for one wobbly digit."""
    box_w = rng.uniform(180, 340)
    box_h = rng.uniform(260, 440)
    rotation = math.radians(rng.uniform(-14, 14))
    slant = rng.uniform(-0.25, 0.25)
    squash_x = rng.uniform(0.65, 1.1)
    shift_x, shift_y = rng.uniform(-0.05, 0.05), rng.uniform(-0.04, 0.04)
    wobble = rng.uniform(0.01, 0.035)
    strokes = []
    for template in TEMPLATES[digit]:
        controls = [(x + rng.gauss(0, wobble), y + rng.gauss(0, wobble)) for x, y in template]
        curve = _catmull_rom(controls)
        # sparse, uneven samples like touch events
        kept = [curve[0]]
        for p in curve[1:-1]:
            if rng.random() < 0.55:
                kept.append(p)
        kept.append(curve[-1])
        stroke = []
        for x, y in kept:
            x, y = (x - 0.5) * squash_x, y - 0.5
            x += slant * y
            x, y = x * math.cos(rotation) - y * math.sin(rotation), x * math.sin(rotation) + y * math.cos(rotation)
            x = -x if mirrored else x
            nx = min(max(0.5 + x * 0.82 + shift_x + rng.gauss(0, 0.004), 0.0), 1.0)
            ny = min(max(0.5 + y * 0.82 + shift_y + rng.gauss(0, 0.004), 0.0), 1.0)
            stroke.append((nx, ny))
        strokes.append(stroke)
    return strokes, box_w, box_h
