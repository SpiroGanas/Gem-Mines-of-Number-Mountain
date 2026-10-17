"""Turns pen strokes into the 28x28 picture the digit network reads.

THIS FILE AND scripts/input/stroke_raster.gd MUST STAY IDENTICAL IN BEHAVIOUR. The network is
trained on pictures made here and runs in the game on pictures made by the GDScript twin. The
test fixture tests/handwriting/fixtures/raster_cases.json is written by this file
(`python tools/handwriting/make_fixtures.py`) and checked by the GDScript tests.

Input: strokes as lists of (x, y) points normalized to the digit box (0..1, y down), plus the box
size in pixels (so a tall, narrow box does not squash the digit). Steps:

  1. points -> box pixels; bounding box of all ink; a dot or scribble smaller than
     MIN_EXTENT of the box is "no digit" (returns None)
  2. scale so the longer side of the ink is TARGET (20) pixels, centred on the 28x28 grid
     (the MNIST convention: a 20x20 digit in a 28x28 frame)
  3. sample the strokes every STEP pixels; shift so the centre of mass of the samples is at the
     middle of the grid (the other MNIST convention)
  4. stamp a soft round brush on every sample; a pixel keeps the strongest stamp (max)

Pixel (ix, iy) covers [ix, ix+1) x [iy, iy+1) in grid coordinates and its centre is (ix+.5, iy+.5).
"""
from __future__ import annotations

import math

import numpy as np

GRID = 28
TARGET = 20.0
CENTER = GRID / 2.0
STEP = 0.5
# Brush: full ink inside BRUSH_CORE, fading to nothing at BRUSH_RADIUS (grid pixels).
BRUSH_CORE = 0.9
BRUSH_RADIUS = 1.9
# Ink whose longer side is under this fraction of the box's shorter side is not a digit.
MIN_EXTENT = 0.2

Strokes = list  # list[list[tuple[float, float]]]


def blank() -> np.ndarray:
    return np.zeros((GRID, GRID), dtype=np.float64)


def ink_size(strokes: Strokes, box_w: float, box_h: float):
    """((min_x, min_y, max_x, max_y) in box pixels, or None when there is no ink)."""
    xs = [p[0] * box_w for s in strokes for p in s]
    ys = [p[1] * box_h for s in strokes for p in s]
    if not xs:
        return None
    return min(xs), min(ys), max(xs), max(ys)


def fit_to_grid(strokes: Strokes, box_w: float, box_h: float):
    """Strokes as grid-pixel polylines scaled to TARGET and centred, or None for 'no digit'."""
    box = ink_size(strokes, box_w, box_h)
    if box is None:
        return None
    min_x, min_y, max_x, max_y = box
    size = max(max_x - min_x, max_y - min_y)
    if size < MIN_EXTENT * min(box_w, box_h):
        return None
    scale = TARGET / size
    mid_x, mid_y = (min_x + max_x) / 2.0, (min_y + max_y) / 2.0
    return [[((p[0] * box_w - mid_x) * scale + CENTER, (p[1] * box_h - mid_y) * scale + CENTER) for p in s]
            for s in strokes if s]


def sample_polylines(polylines) -> list:
    """Points along the polylines, one every STEP pixels (a one-point stroke is one sample)."""
    samples = []
    for line in polylines:
        for i in range(len(line) - 1):
            x0, y0 = line[i]
            x1, y1 = line[i + 1]
            n = max(1, math.ceil(math.hypot(x1 - x0, y1 - y0) / STEP))
            for k in range(n):
                t = k / n
                samples.append((x0 + (x1 - x0) * t, y0 + (y1 - y0) * t))
        samples.append(line[-1])
    return samples


def stamp(samples, brush_core: float = BRUSH_CORE, brush_radius: float = BRUSH_RADIUS) -> np.ndarray:
    """The 28x28 picture of a soft brush stamped on every sample point (vectorized)."""
    image = blank()
    if len(samples) == 0:
        return image
    pts = np.asarray(samples, dtype=np.float64)
    centers = (np.arange(GRID, dtype=np.float64) + 0.5)
    cx, cy = np.meshgrid(centers, centers)  # cx[iy, ix]
    flat = np.stack([cx.ravel(), cy.ravel()], axis=1)
    # Process in chunks so a long scribble does not build a huge matrix.
    out = np.zeros(GRID * GRID, dtype=np.float64)
    for start in range(0, len(pts), 256):
        chunk = pts[start:start + 256]
        d = np.sqrt(((chunk[:, None, :] - flat[None, :, :]) ** 2).sum(axis=2))
        v = np.clip((brush_radius - d) / (brush_radius - brush_core), 0.0, 1.0)
        out = np.maximum(out, v.max(axis=0))
    return out.reshape(GRID, GRID)


def center_of_mass_shift(samples):
    """(dx, dy) that moves the centroid of `samples` to the middle of the grid."""
    n = len(samples)
    mx = sum(p[0] for p in samples) / n
    my = sum(p[1] for p in samples) / n
    return CENTER - mx, CENTER - my


def render_samples(samples, brush_core: float = BRUSH_CORE, brush_radius: float = BRUSH_RADIUS) -> np.ndarray:
    """Step 3-4 for samples already on the grid: centre of mass to the middle, then stamp."""
    if len(samples) == 0:
        return blank()
    dx, dy = center_of_mass_shift(samples)
    return stamp([(x + dx, y + dy) for x, y in samples], brush_core, brush_radius)


def rasterize(strokes: Strokes, box_w: float, box_h: float):
    """The 28x28 float picture (0..1) of the strokes, or None when there is no digit to read."""
    polylines = fit_to_grid(strokes, box_w, box_h)
    if polylines is None:
        return None
    return render_samples(sample_polylines(polylines))
