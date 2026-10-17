"""Writes and reads the digit network's weights as the JSON file the game loads.

    assets/handwriting/digit_net.json
      {"format": "gem-mines-digit-net", "version": 1, "input": 28,
       "layers": {"conv1_w": {"shape": [8,1,3,3], "data": "<base64 of little-endian float32>"}, ...},
       "mirror_sensitive": [2,3,4,5,6,7,9], "metrics": {...}, "trained": {...}}

A .json file is exported with the game like the curriculum files (no export-filter change), and
base64 keeps the 52,000 numbers to about 280 KB. scripts/input/digit_net.gd decodes it with
Marshalls.base64_to_raw(...).to_float32_array().
"""
from __future__ import annotations

import base64
import json
from pathlib import Path

import numpy as np

import model

FORMAT = "gem-mines-digit-net"
VERSION = 1
DEFAULT_PATH = Path(__file__).resolve().parents[2] / "assets" / "handwriting" / "digit_net.json"


def encode(array: np.ndarray) -> dict:
    flat = np.ascontiguousarray(array, dtype="<f4")
    return {"shape": list(flat.shape), "data": base64.b64encode(flat.tobytes()).decode("ascii")}


def decode(entry: dict) -> np.ndarray:
    raw = base64.b64decode(entry["data"])
    return np.frombuffer(raw, dtype="<f4").reshape(entry["shape"]).copy()


def write(weights: dict[str, np.ndarray], path: Path = DEFAULT_PATH, metrics: dict | None = None,
          trained: dict | None = None) -> None:
    shapes = model.layer_shapes(model.widths_of(weights))
    for name, shape in shapes.items():
        if tuple(weights[name].shape) != shape:
            raise ValueError(f"{name} has shape {weights[name].shape}, expected {shape}")
    doc = {
        "format": FORMAT, "version": VERSION, "input": 28,
        "mirror_sensitive": [2, 3, 4, 5, 6, 7, 9],
        "widths": list(model.widths_of(weights)),
        "layers": {name: encode(weights[name]) for name in model.LAYER_NAMES},
        "metrics": metrics or {}, "trained": trained or {},
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(doc, indent=1, sort_keys=True) + "\n", encoding="utf-8")


def read(path: Path = DEFAULT_PATH) -> tuple[dict[str, np.ndarray], dict]:
    doc = json.loads(path.read_text(encoding="utf-8"))
    if doc.get("format") != FORMAT or int(doc.get("version", 0)) != VERSION:
        raise ValueError(f"{path} is not a {FORMAT} v{VERSION} file")
    weights = {name: decode(entry) for name, entry in doc["layers"].items()}
    return weights, doc
