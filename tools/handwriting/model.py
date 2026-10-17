"""The digit network: definition (PyTorch) and a numpy reference forward pass.

    28x28 picture -> conv3x3(1->C1)+ReLU -> maxpool2 -> conv3x3(C1->C2)+ReLU -> maxpool2
                  -> flatten (C2 x 7 x 7, channel-major) -> dense(C2*49->H)+ReLU -> dense(H->11)
    (C1, C2, H) = DEFAULT_WIDTHS (8, 16, 64) unless train.py is given other widths; the exported file
    records the widths and the GDScript network reads them from it.

The 11 outputs are 10 digit logits and 1 "mirrored" logit (sigmoid). The game runs the same
network in GDScript (scripts/input/digit_net.gd) from the weights export_weights.py writes; the
numpy forward below is the middle link that tests both ends against.

PyTorch is imported lazily so the numpy half works (and is tested) on machines without it.
"""
from __future__ import annotations

import numpy as np

OUTPUTS = 11
DEFAULT_WIDTHS = (8, 16, 64)  # conv1 channels, conv2 channels, hidden units


def layer_shapes(widths=DEFAULT_WIDTHS) -> dict[str, tuple]:
    c1, c2, hidden = widths
    return {
        "conv1_w": (c1, 1, 3, 3), "conv1_b": (c1,),
        "conv2_w": (c2, c1, 3, 3), "conv2_b": (c2,),
        "fc1_w": (hidden, c2 * 7 * 7), "fc1_b": (hidden,),
        "head_w": (OUTPUTS, hidden), "head_b": (OUTPUTS,),
    }


LAYER_SHAPES = layer_shapes()
LAYER_NAMES = tuple(LAYER_SHAPES)


def widths_of(weights: dict[str, np.ndarray]) -> tuple[int, int, int]:
    """(conv1, conv2, hidden) channel counts of a weights dict."""
    return int(weights["conv1_b"].shape[0]), int(weights["conv2_b"].shape[0]), int(weights["fc1_b"].shape[0])


def build_torch_model(widths=DEFAULT_WIDTHS):
    import torch.nn as nn
    CONV1, CONV2, HIDDEN = widths

    class DigitNet(nn.Module):
        def __init__(self) -> None:
            super().__init__()
            self.conv1 = nn.Conv2d(1, CONV1, 3, padding=1)
            self.conv2 = nn.Conv2d(CONV1, CONV2, 3, padding=1)
            self.fc1 = nn.Linear(CONV2 * 7 * 7, HIDDEN)
            self.head = nn.Linear(HIDDEN, OUTPUTS)
            self.pool = nn.MaxPool2d(2)
            self.act = nn.ReLU()

        def forward(self, x):
            x = self.pool(self.act(self.conv1(x)))
            x = self.pool(self.act(self.conv2(x)))
            x = self.act(self.fc1(x.flatten(1)))
            return self.head(x)

    return DigitNet()


def torch_weights(model) -> dict[str, np.ndarray]:
    sd = {k: v.detach().cpu().numpy().astype(np.float32) for k, v in model.state_dict().items()}
    return {"conv1_w": sd["conv1.weight"], "conv1_b": sd["conv1.bias"], "conv2_w": sd["conv2.weight"],
            "conv2_b": sd["conv2.bias"], "fc1_w": sd["fc1.weight"], "fc1_b": sd["fc1.bias"],
            "head_w": sd["head.weight"], "head_b": sd["head.bias"]}


def _conv3x3(x: np.ndarray, w: np.ndarray, b: np.ndarray) -> np.ndarray:
    """x (N, C, H, W), w (K, C, 3, 3), zero padding 1, stride 1."""
    n, c, h, wd = x.shape
    padded = np.pad(x, ((0, 0), (0, 0), (1, 1), (1, 1)))
    out = np.zeros((n, w.shape[0], h, wd), dtype=np.float64)
    for dy in range(3):
        for dx in range(3):
            patch = padded[:, :, dy:dy + h, dx:dx + wd]
            out += np.einsum("nchw,kc->nkhw", patch, w[:, :, dy, dx].astype(np.float64))
    return out + b.astype(np.float64)[None, :, None, None]


def _pool2(x: np.ndarray) -> np.ndarray:
    n, c, h, w = x.shape
    return x.reshape(n, c, h // 2, 2, w // 2, 2).max(axis=(3, 5))


def forward(weights: dict[str, np.ndarray], images: np.ndarray) -> np.ndarray:
    """Logits (N, 11) for pictures (N, 28, 28) or (N, 1, 28, 28), in float64."""
    x = np.asarray(images, dtype=np.float64)
    if x.ndim == 3:
        x = x[:, None, :, :]
    x = _pool2(np.maximum(_conv3x3(x, weights["conv1_w"], weights["conv1_b"]), 0.0))
    x = _pool2(np.maximum(_conv3x3(x, weights["conv2_w"], weights["conv2_b"]), 0.0))
    x = x.reshape(x.shape[0], -1)
    x = np.maximum(x @ weights["fc1_w"].astype(np.float64).T + weights["fc1_b"].astype(np.float64), 0.0)
    return x @ weights["head_w"].astype(np.float64).T + weights["head_b"].astype(np.float64)


def softmax(logits: np.ndarray) -> np.ndarray:
    z = logits - logits.max(axis=-1, keepdims=True)
    e = np.exp(z)
    return e / e.sum(axis=-1, keepdims=True)


def read(weights: dict[str, np.ndarray], image: np.ndarray) -> dict:
    """What the game reads from one picture: {digit, confidence, mirrored, mirrored_confidence}."""
    logits = forward(weights, image[None])[0]
    probs = softmax(logits[:10])
    digit = int(probs.argmax())
    mirrored_p = float(1.0 / (1.0 + np.exp(-logits[10])))
    return {"digit": digit, "confidence": float(probs[digit]), "mirrored": mirrored_p >= 0.5, "mirrored_confidence": mirrored_p}
