"""Zhang-Suen thinning, vectorized over a batch of binary images.

MNIST digits are thick scanned pen strokes. The game's strokes are thin lines stamped with a round
brush (raster.py). Thinning an MNIST digit to a one-pixel skeleton and re-stamping it with the
same brush gives training pictures that look like the game's, with MNIST's variety of shapes.
"""
from __future__ import annotations

import numpy as np


def _neighbours(img: np.ndarray):
    """The eight neighbours P2..P9 (clockwise from north) of every pixel, zero outside."""
    p = np.pad(img, ((0, 0), (1, 1), (1, 1)))
    n = p[:, :-2, 1:-1]
    ne = p[:, :-2, 2:]
    e = p[:, 1:-1, 2:]
    se = p[:, 2:, 2:]
    s = p[:, 2:, 1:-1]
    sw = p[:, 2:, :-2]
    w = p[:, 1:-1, :-2]
    nw = p[:, :-2, :-2]
    return n, ne, e, se, s, sw, w, nw


def _sub_iteration(img: np.ndarray, first: bool) -> np.ndarray:
    n, ne, e, se, s, sw, w, nw = _neighbours(img)
    seq = [n, ne, e, se, s, sw, w, nw, n]
    transitions = sum(((seq[i] == 0) & (seq[i + 1] == 1)).astype(np.int8) for i in range(8))
    count = sum(x.astype(np.int8) for x in (n, ne, e, se, s, sw, w, nw))
    if first:
        cond = ((n & e & s) == 0) & ((e & s & w) == 0)
    else:
        cond = ((n & e & w) == 0) & ((n & s & w) == 0)
    remove = img.astype(bool) & (count >= 2) & (count <= 6) & (transitions == 1) & cond
    return remove


def thin(images: np.ndarray, threshold: float = 0.5, max_iterations: int = 40) -> np.ndarray:
    """Boolean skeletons of `images` (N, H, W) with values 0..1."""
    img = (images >= threshold).astype(np.uint8)
    for _ in range(max_iterations):
        changed = False
        for first in (True, False):
            remove = _sub_iteration(img, first)
            if remove.any():
                img[remove] = 0
                changed = True
        if not changed:
            break
    return img.astype(bool)


def skeleton_points(skeleton: np.ndarray) -> np.ndarray:
    """Grid-coordinate (x, y) centres of the set pixels of one skeleton, shape (m, 2)."""
    ys, xs = np.nonzero(skeleton)
    return np.stack([xs + 0.5, ys + 0.5], axis=1).astype(np.float64)
