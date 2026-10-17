"""How well does the network read? Reports top-1 accuracy, the mirrored flag and the
confirmation-threshold trade-off on several test sets.

Test sets (each is reported separately; only the last is the bar that matters):
  mnist_raw        the 10,000 MNIST test pictures as scanned
  mnist_skeleton   the same digits thinned and re-stamped with the game's brush (no mirroring)
  synthetic        procedural line-drawn digits sent through the real rasterizer (synth.py)
  private          Charlie's captured digits (private/handwriting/), if the folder exists; the
                   plan's 97% target is measured here, with the confirmation prompt on

Threshold sweep: for each confidence cut-off, `confirm` is the share of readings that would ask
"Did you write N?" and `false_wrong` is the share of ALL readings that are confidently wrong
(above the cut-off, so nothing asks) -- the number to keep near zero.

    python tools/handwriting/evaluate.py [--weights assets/handwriting/digit_net.json]
"""
from __future__ import annotations

import argparse
import json
import random
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))

import augment  # noqa: E402
import dataset  # noqa: E402
import export_weights  # noqa: E402
import model  # noqa: E402
import raster  # noqa: E402
import synth  # noqa: E402
import thin  # noqa: E402

THRESHOLDS = (0.5, 0.7, 0.8, 0.85, 0.9, 0.95, 0.98)


def predict(weights, pictures: np.ndarray):
    logits = model.forward(weights, pictures)
    probs = model.softmax(logits[:, :10])
    digits = probs.argmax(axis=1)
    conf = probs.max(axis=1)
    mirrored = 1.0 / (1.0 + np.exp(-logits[:, 10]))
    return digits, conf, mirrored


def sweep(labels: np.ndarray, digits: np.ndarray, conf: np.ndarray) -> list[dict]:
    rows = []
    n = len(labels)
    for t in THRESHOLDS:
        sure = conf >= t
        rows.append({"threshold": t, "confirm": round(float((~sure).mean()), 4),
                     "false_wrong": round(float((sure & (digits != labels)).sum() / n), 4)})
    return rows


def score(weights, pictures, labels, mirrored_truth=None, mirrored_mask=None) -> dict:
    digits, conf, mirrored = predict(weights, pictures)
    result = {"n": int(len(labels)), "top1": round(float((digits == labels).mean()), 4), "sweep": sweep(labels, digits, conf)}
    if mirrored_truth is not None:
        use = mirrored_mask > 0
        result["mirrored_accuracy"] = round(float(((mirrored[use] >= 0.5) == (mirrored_truth[use] > 0.5)).mean()), 4) if use.any() else None
    return result


def synthetic_set(per_class: int, seed: int, mirrored: bool = False):
    rng = random.Random(seed)
    pictures, labels = [], []
    for digit in range(10):
        for _ in range(per_class):
            strokes, bw, bh = synth.make_sample(digit, rng, mirrored)
            pic = raster.rasterize(strokes, bw, bh)
            if pic is not None:
                pictures.append(pic)
                labels.append(digit)
    return np.stack(pictures), np.array(labels)


def private_set():
    samples = dataset.load_private()
    if samples is None:
        return None
    pictures, labels = [], []
    for s in samples:
        box = s.get("box", [1, 1])
        pic = raster.rasterize([[tuple(p) for p in stroke] for stroke in s["strokes"]], box[0], box[1])
        if pic is not None:
            pictures.append(pic)
            labels.append(int(s["label"]))
    return (np.stack(pictures), np.array(labels)) if pictures else None


def evaluate(weights, per_class_synthetic: int = 200, seed: int = 9001) -> dict:
    report = {}
    loaded = dataset.load_mnist(download=False)
    if loaded is not None:
        (_, _), (x_test, y_test) = loaded
        report["mnist_raw"] = score(weights, x_test, y_test)
        skeletons = thin.thin(x_test)
        points = [thin.skeleton_points(s) for s in skeletons]
        pics, ys, ms, mask = augment.make_set(x_test, points, y_test, seed, processes=4, mirror_chance=0.0, skeleton_share=1.0)
        report["mnist_skeleton"] = score(weights, pics, ys)
        pics, ys, ms, mask = augment.make_set(x_test, points, y_test, seed + 1, processes=4, mirror_chance=1.0, skeleton_share=1.0)
        report["mnist_skeleton_mirrored"] = score(weights, pics, ys, ms, mask)
    pics, labels = synthetic_set(per_class_synthetic, seed)
    report["synthetic"] = score(weights, pics, labels)
    pics, labels = synthetic_set(per_class_synthetic // 2, seed + 2, mirrored=True)
    report["synthetic_mirrored"] = score(weights, pics, labels)
    private = private_set()
    if private is not None:
        report["private"] = score(weights, *private)
    return report


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--weights", type=Path, default=export_weights.DEFAULT_PATH)
    ap.add_argument("--json", action="store_true", help="print the full report as JSON")
    args = ap.parse_args(argv)
    weights, doc = export_weights.read(args.weights)
    report = evaluate(weights)
    if args.json:
        print(json.dumps(report, indent=1))
    else:
        for name, r in report.items():
            print(f"{name:26} n={r['n']:6}  top-1 {100 * r['top1']:.2f}%" + (f"  mirrored flag {100 * r['mirrored_accuracy']:.1f}%" if r.get("mirrored_accuracy") is not None else ""))
            for row in r["sweep"]:
                if row["threshold"] in (0.8, 0.9, 0.95):
                    print(f"{'':26}   confidence >= {row['threshold']}: asks {100 * row['confirm']:.1f}%, confidently wrong {100 * row['false_wrong']:.2f}%")
        if "private" not in report:
            print("private: no captured digits in private/handwriting/ yet (the 97% bar is measured there)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
