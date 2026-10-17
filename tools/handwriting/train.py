"""Trains the digit network on MNIST re-drawn as game strokes and exports its weights.

    pip install -r tools/handwriting/requirements.txt     # numpy + PyTorch (build-time only)
    python tools/handwriting/train.py                     # writes assets/handwriting/digit_net.json

Steps: fetch MNIST (cached in build/handwriting/), thin every digit (cached), build `--sets`
independently augmented copies of the training set (augment.py), train with Adam and a cosine
schedule, evaluate (evaluate.py) and write the weights with the metrics. Charlie's captured digits
in private/handwriting/ are NEVER trained on here; they are only a test set. Fixed seeds: the same
command repeats the same network up to PyTorch's own floating-point order.
"""
from __future__ import annotations

import argparse
import datetime
import subprocess
import sys
import time
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))

import augment  # noqa: E402
import dataset  # noqa: E402
import evaluate  # noqa: E402
import export_weights  # noqa: E402
import model  # noqa: E402
import thin  # noqa: E402


def skeletons_for(images: np.ndarray, name: str):
    cache = dataset.CACHE / f"skeleton_{name}.npz"
    if cache.exists():
        with np.load(cache) as d:
            flat, offsets = d["points"], d["offsets"]
        return [flat[offsets[i]:offsets[i + 1]] for i in range(len(offsets) - 1)]
    skeletons = np.concatenate([thin.thin(images[i:i + 5000]) for i in range(0, len(images), 5000)])
    points = [thin.skeleton_points(s) for s in skeletons]
    offsets = np.cumsum([0] + [len(p) for p in points])
    dataset.CACHE.mkdir(parents=True, exist_ok=True)
    np.savez_compressed(cache, points=np.concatenate(points), offsets=offsets)
    return points


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--epochs", type=int, default=12)
    ap.add_argument("--sets", type=int, default=3, help="independently augmented copies of the 60,000 training digits")
    ap.add_argument("--seed", type=int, default=20270208)
    ap.add_argument("--batch", type=int, default=256)
    ap.add_argument("--lr", type=float, default=2e-3)
    ap.add_argument("--out", type=Path, default=export_weights.DEFAULT_PATH)
    ap.add_argument("--threads", type=int, default=4)
    ap.add_argument("--widths", type=int, nargs=3, default=list(model.DEFAULT_WIDTHS), metavar=("C1", "C2", "H"),
                    help="conv1 channels, conv2 channels, hidden units")
    args = ap.parse_args(argv)

    import torch
    import torch.nn.functional as F

    torch.manual_seed(args.seed)
    torch.set_num_threads(args.threads)
    (x_train, y_train), _ = dataset.load_mnist()
    t0 = time.time()
    points = skeletons_for(x_train, "train")
    print(f"skeletons ready ({time.time() - t0:.0f}s)")
    xs, ys, ms, masks = [], [], [], []
    for k in range(args.sets):
        x, y, m, mask = augment.make_set(x_train, points, y_train, args.seed + k, processes=args.threads)
        xs.append(x); ys.append(y); ms.append(m); masks.append(mask)
        print(f"augmented set {k + 1}/{args.sets} ({time.time() - t0:.0f}s)")
    X = torch.from_numpy(np.concatenate(xs))[:, None]
    Y = torch.from_numpy(np.concatenate(ys))
    M = torch.from_numpy(np.concatenate(ms))
    MASK = torch.from_numpy(np.concatenate(masks))

    net = model.build_torch_model(tuple(args.widths))
    opt = torch.optim.Adam(net.parameters(), lr=args.lr)
    steps = args.epochs * ((len(X) + args.batch - 1) // args.batch)
    sched = torch.optim.lr_scheduler.OneCycleLR(opt, max_lr=args.lr, total_steps=steps)
    gen = torch.Generator().manual_seed(args.seed)
    for epoch in range(args.epochs):
        net.train()
        order = torch.randperm(len(X), generator=gen)
        total = correct = 0
        loss_sum = 0.0
        for start in range(0, len(X), args.batch):
            idx = order[start:start + args.batch]
            out = net(X[idx])
            loss = F.cross_entropy(out[:, :10], Y[idx])
            bce = F.binary_cross_entropy_with_logits(out[:, 10], M[idx], reduction="none")
            loss = loss + 0.5 * (bce * MASK[idx]).sum() / MASK[idx].sum().clamp(min=1.0)
            opt.zero_grad()
            loss.backward()
            opt.step()
            sched.step()
            loss_sum += float(loss.detach()) * len(idx)
            correct += int((out[:, :10].argmax(1) == Y[idx]).sum())
            total += len(idx)
        print(f"epoch {epoch + 1:2}/{args.epochs}  loss {loss_sum / total:.4f}  train acc {100 * correct / total:.2f}%  ({time.time() - t0:.0f}s)")

    weights = model.torch_weights(net)
    report = evaluate.evaluate(weights)
    commit = subprocess.run(["git", "rev-parse", "--short", "HEAD"], capture_output=True, text=True, cwd=dataset.REPO).stdout.strip()
    export_weights.write(weights, args.out, metrics={k: {"n": v["n"], "top1": v["top1"], "sweep": v["sweep"],
                                                         **({"mirrored_accuracy": v["mirrored_accuracy"]} if v.get("mirrored_accuracy") is not None else {})}
                                                     for k, v in report.items()},
                         trained={"date": datetime.date.today().isoformat(), "seed": args.seed, "epochs": args.epochs,
                                  "sets": args.sets, "widths": list(args.widths), "commit": commit, "data": "MNIST (train split) re-drawn as strokes; no private digits"})
    for name, r in report.items():
        print(f"{name:26} top-1 {100 * r['top1']:.2f}%")
    print(f"wrote {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
