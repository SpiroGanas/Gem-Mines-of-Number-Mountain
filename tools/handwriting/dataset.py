"""Datasets for the digit network. Nothing here ships in the game.

* MNIST (60,000 train / 10,000 test) is fetched at build time from a public mirror and cached in
  build/handwriting/ (gitignored). Its sha256 is pinned below.
* Charlie's own digits live in private/handwriting/ (gitignored, never committed, never uploaded,
  never read by CI). `load_private` returns None when the folder is absent, so every pipeline
  step runs without them. Each file is one capture written by the debug capture screen:
      {"label": 7, "device": "pen"|"touch"|"mouse", "box": [w, h], "strokes": [[[x, y], ...], ...]}
  with x and y normalized to the box (0..1).
"""
from __future__ import annotations

import hashlib
import json
import urllib.request
from pathlib import Path

import numpy as np

REPO = Path(__file__).resolve().parents[2]
CACHE = REPO / "build" / "handwriting"
PRIVATE = REPO / "private" / "handwriting"
MNIST_URL = "https://storage.googleapis.com/tensorflow/tf-keras-datasets/mnist.npz"
MNIST_SHA256 = "731c5ac602752760c8e48fbffcf8c3b850d9dc2a2aedcf2cc48468fc17b673d1"


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def mnist_path(download: bool = True) -> Path | None:
    """The cached mnist.npz, downloading it (and checking the pinned hash) when missing."""
    path = CACHE / "mnist.npz"
    if not path.exists():
        if not download:
            return None
        CACHE.mkdir(parents=True, exist_ok=True)
        tmp = path.with_suffix(".part")
        urllib.request.urlretrieve(MNIST_URL, tmp)
        tmp.replace(path)
    if _sha256(path) != MNIST_SHA256:
        raise RuntimeError(f"{path} does not match the pinned sha256; delete it and retry")
    return path


def load_mnist(download: bool = True):
    """((x_train, y_train), (x_test, y_test)) with images as float64 0..1, shape (N, 28, 28)."""
    path = mnist_path(download)
    if path is None:
        return None
    with np.load(path) as data:
        return ((data["x_train"].astype(np.float64) / 255.0, data["y_train"].astype(np.int64)),
                (data["x_test"].astype(np.float64) / 255.0, data["y_test"].astype(np.int64)))


def load_private(folder: Path = PRIVATE):
    """Captured strokes from `folder` as a list of dicts, or None when the folder is absent/empty."""
    if not folder.is_dir():
        return None
    samples = []
    for path in sorted(folder.glob("*.json")):
        try:
            sample = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        if isinstance(sample, dict) and isinstance(sample.get("strokes"), list) and isinstance(sample.get("label"), int):
            samples.append(sample)
    return samples or None
