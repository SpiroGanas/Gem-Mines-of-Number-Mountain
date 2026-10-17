"""Training pictures for the digit network: MNIST re-drawn the way the game draws strokes.

Two kinds, mixed by `make_set`:
  * skeleton pictures: the MNIST digit thinned to a one-pixel skeleton (thin.py), wobbled, slanted,
    rotated, scaled and (sometimes) mirrored as points, then fitted and stamped with the same
    brush as the game (raster.py). These look like the game's strokes.
  * raw pictures: the MNIST picture itself with a small shift, so thick scanned strokes still read.

A mirrored digit is labelled with the digit the child MEANT (a backwards 3 is a 3) and a second
target says it was mirrored. Digits 0, 1 and 8 look the same mirrored, so they carry no mirrored
target (mask 0). Everything is driven by a numpy Generator, so a seed repeats a set exactly.
"""
from __future__ import annotations

import math

import numpy as np

import raster

MIRROR_SENSITIVE = (2, 3, 4, 5, 6, 7, 9)


def augment_points(points: np.ndarray, rng: np.random.Generator, mirror: bool) -> np.ndarray:
    """Randomly deform grid points (m, 2) around their centre."""
    p = points - points.mean(axis=0)
    angle = math.radians(rng.uniform(-15, 15))
    shear = rng.uniform(-0.3, 0.3)
    sx, sy = rng.uniform(0.75, 1.25), rng.uniform(0.8, 1.2)
    p = p * np.array([sx, sy])
    p[:, 0] += shear * p[:, 1]
    c, s = math.cos(angle), math.sin(angle)
    p = p @ np.array([[c, s], [-s, c]])
    # low-frequency wobble: a slow sideways and up/down drift along the digit
    freq, phase = rng.uniform(0.15, 0.5, size=2), rng.uniform(0, 2 * math.pi, size=2)
    amp = rng.uniform(0.0, 1.2)
    p[:, 0] += amp * np.sin(freq[0] * p[:, 1] + phase[0])
    p[:, 1] += amp * np.sin(freq[1] * p[:, 0] + phase[1])
    p += rng.normal(0, 0.12, size=p.shape)
    if mirror:
        p[:, 0] = -p[:, 0]
    return p


def render_points(points: np.ndarray, rng: np.random.Generator | None = None) -> np.ndarray | None:
    """Fit points to the 20-pixel digit frame like raster.fit_to_grid, then centre and stamp."""
    lo, hi = points.min(axis=0), points.max(axis=0)
    size = float((hi - lo).max())
    if size < 1e-6:
        return None
    scale = raster.TARGET / size
    fitted = (points - (lo + hi) / 2.0) * scale + raster.CENTER
    core = raster.BRUSH_CORE if rng is None else rng.uniform(0.75, 1.15)
    radius = raster.BRUSH_RADIUS if rng is None else core + rng.uniform(0.85, 1.1)
    return raster.render_samples(fitted, core, radius)


def shift_raw(image: np.ndarray, rng: np.random.Generator) -> np.ndarray:
    dx, dy = rng.integers(-2, 3, size=2)
    out = np.zeros_like(image)
    src = image[max(0, -dy):28 - max(0, dy), max(0, -dx):28 - max(0, dx)]
    out[max(0, dy):max(0, dy) + src.shape[0], max(0, dx):max(0, dx) + src.shape[1]] = src
    return out


def one(index: int, image: np.ndarray, points: np.ndarray, label: int, seed: int,
        mirror_chance: float = 0.15, skeleton_share: float = 0.8):
    """(picture, label, mirrored target, mirrored mask) for one MNIST digit."""
    rng = np.random.default_rng([seed, index])
    mirror = bool(label in MIRROR_SENSITIVE and rng.random() < mirror_chance)
    if rng.random() < skeleton_share and len(points) >= 3:
        picture = render_points(augment_points(points, rng, mirror), rng)
    else:
        picture = None
    if picture is None:
        picture = shift_raw(image[:, ::-1] if mirror else image, rng)
    return picture, label, float(mirror), float(label in MIRROR_SENSITIVE)


def _work(args):
    return one(*args)


def make_set(images: np.ndarray, points: list, labels: np.ndarray, seed: int, processes: int = 4,
             mirror_chance: float = 0.15, skeleton_share: float = 0.8):
    """Pictures (N, 28, 28) float32, labels (N,), mirrored targets (N,), masks (N,)."""
    jobs = [(i, images[i], points[i], int(labels[i]), seed, mirror_chance, skeleton_share) for i in range(len(images))]
    if processes > 1:
        import multiprocessing as mp
        with mp.get_context("fork").Pool(processes) as pool:
            results = pool.map(_work, jobs, chunksize=512)
    else:
        results = [_work(j) for j in jobs]
    x = np.stack([r[0] for r in results]).astype(np.float32)
    y = np.array([r[1] for r in results], dtype=np.int64)
    m = np.array([r[2] for r in results], dtype=np.float32)
    mask = np.array([r[3] for r in results], dtype=np.float32)
    return x, y, m, mask
