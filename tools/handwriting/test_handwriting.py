"""pytest for tools/handwriting. The numpy-only parts always run; the parts that need PyTorch or
the cached MNIST download are skipped when those are missing (CI installs only pytest)."""
import json
import random
import sys
from pathlib import Path

import numpy as np
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent))

import augment  # noqa: E402
import dataset  # noqa: E402
import export_weights  # noqa: E402
import model  # noqa: E402
import raster  # noqa: E402
import synth  # noqa: E402
import thin  # noqa: E402

try:
    import torch  # noqa: F401
    HAS_TORCH = True
except ImportError:
    HAS_TORCH = False

needs_torch = pytest.mark.skipif(not HAS_TORCH, reason="PyTorch is not installed (tools/handwriting/requirements.txt)")
needs_mnist = pytest.mark.skipif(dataset.mnist_path(download=False) is None, reason="MNIST is not cached (run train.py once)")


# --- raster ------------------------------------------------------------------------------------


def test_a_stroke_makes_a_centred_picture_in_zero_to_one():
    pic = raster.rasterize([[(0.2, 0.1), (0.8, 0.9)]], 300, 400)
    assert pic.shape == (28, 28)
    assert 0.0 <= pic.min() and pic.max() == 1.0
    ys, xs = np.mgrid[0:28, 0:28]
    cx = (pic * (xs + 0.5)).sum() / pic.sum()
    cy = (pic * (ys + 0.5)).sum() / pic.sum()
    assert abs(cx - 14) < 0.7 and abs(cy - 14) < 0.7


def test_a_dot_nothing_and_a_tiny_scribble_are_not_digits():
    assert raster.rasterize([[(0.5, 0.5)]], 300, 400) is None
    assert raster.rasterize([], 300, 400) is None
    assert raster.rasterize([[(0.5, 0.5), (0.52, 0.51)]], 300, 400) is None


def test_the_ink_is_scaled_to_twenty_pixels():
    pic = raster.rasterize([[(0.1, 0.1), (0.1, 0.9)]], 400, 400)  # a tall line
    rows = np.nonzero(pic.max(axis=1) > 0.5)[0]
    assert 19 <= rows.max() - rows.min() + 1 <= 23  # 20 px of ink plus the brush's edge


def test_sampling_steps_at_most_half_a_pixel():
    samples = raster.sample_polylines([[(0.0, 0.0), (10.0, 0.0)]])
    gaps = [abs(b[0] - a[0]) for a, b in zip(samples, samples[1:])]
    assert max(gaps) <= raster.STEP + 1e-9 and len(samples) == 21


def test_the_brush_is_full_in_the_core_and_gone_at_its_radius():
    pic = raster.stamp([(14.0, 14.0)])
    assert pic[13, 13] == pytest.approx(1.0)  # pixel centre (13.5, 13.5) is 0.707 from the sample
    assert pic[14, 16] == 0.0  # centre (16.5, 14.5): 2.55 away


def test_the_same_strokes_always_give_the_same_picture():
    strokes, bw, bh = synth.make_sample(4, random.Random(5))
    assert np.array_equal(raster.rasterize(strokes, bw, bh), raster.rasterize(strokes, bw, bh))


# --- synth, thinning, augmentation -------------------------------------------------------------


def test_every_digit_template_rasterizes_to_ink():
    rng = random.Random(1)
    for digit in range(10):
        for mirrored in (False, True):
            strokes, bw, bh = synth.make_sample(digit, rng, mirrored)
            pic = raster.rasterize(strokes, bw, bh)
            assert pic is not None and pic.sum() > 40


def test_mirroring_flips_the_picture_sideways():
    a = raster.rasterize([[(0.2, 0.2), (0.8, 0.2), (0.8, 0.9)]], 300, 300)
    b = raster.rasterize([[(0.8, 0.2), (0.2, 0.2), (0.2, 0.9)]], 300, 300)
    assert np.allclose(a, b[:, ::-1], atol=0.02)


def test_thinning_a_thick_bar_leaves_a_one_pixel_line():
    img = np.zeros((1, 28, 28))
    img[0, 10:15, 4:24] = 1.0
    skeleton = thin.thin(img)[0]
    assert 1 <= skeleton.sum() <= 30
    assert skeleton.sum(axis=0).max() <= 2  # about one pixel thick everywhere
    assert thin.skeleton_points(skeleton).shape[1] == 2


def test_augmenting_with_the_same_seed_repeats_exactly():
    pts = np.array([[10.5, 4.5], [10.5, 14.5], [10.5, 24.5], [16.5, 24.5]])
    a = augment.render_points(augment.augment_points(pts, np.random.default_rng(3), False), np.random.default_rng(4))
    b = augment.render_points(augment.augment_points(pts, np.random.default_rng(3), False), np.random.default_rng(4))
    assert np.array_equal(a, b) and a.sum() > 20


def test_mirrored_labels_keep_the_digit_and_only_sensitive_digits_carry_the_flag():
    img = np.zeros((28, 28))
    img[5:23, 12:16] = 1.0
    pts = thin.skeleton_points(thin.thin(img[None])[0])
    _, label, mirrored, mask = augment.one(0, img, pts, 1, 1, mirror_chance=1.0)
    assert (label, mask) == (1, 0.0)  # 1 looks the same mirrored
    _, label, mirrored, mask = augment.one(0, img, pts, 7, 1, mirror_chance=1.0)
    assert (label, mirrored, mask) == (7, 1.0, 1.0)
    _, label, mirrored, mask = augment.one(0, img, pts, 7, 1, mirror_chance=0.0)
    assert (label, mirrored, mask) == (7, 0.0, 1.0)


# --- datasets ----------------------------------------------------------------------------------


def test_private_digits_are_optional(tmp_path):
    assert dataset.load_private(tmp_path / "missing") is None
    assert dataset.load_private(tmp_path) is None
    (tmp_path / "a.json").write_text(json.dumps({"label": 4, "box": [100, 100], "strokes": [[[0.1, 0.1], [0.9, 0.9]]]}))
    (tmp_path / "b.json").write_text("not json")
    (tmp_path / "c.json").write_text(json.dumps({"label": "x", "strokes": []}))
    samples = dataset.load_private(tmp_path)
    assert len(samples) == 1 and samples[0]["label"] == 4


def test_the_real_private_folder_is_never_read_by_this_suite():
    # the suite only passes explicit temp folders; the default folder is gitignored
    assert dataset.PRIVATE.parts[-2:] == ("private", "handwriting")


# --- model and export --------------------------------------------------------------------------


def _random_weights(seed=0):
    rng = np.random.default_rng(seed)
    return {name: (rng.normal(0, 0.2, size=shape)).astype(np.float32) for name, shape in model.LAYER_SHAPES.items()}


def test_export_round_trip_is_exact(tmp_path):
    weights = _random_weights()
    path = tmp_path / "net.json"
    export_weights.write(weights, path, metrics={"x": 1})
    back, doc = export_weights.read(path)
    assert doc["metrics"] == {"x": 1}
    for name in weights:
        assert np.array_equal(weights[name], back[name])


def test_export_rejects_a_wrong_shape(tmp_path):
    weights = _random_weights()
    weights["fc1_w"] = weights["fc1_w"][:10]
    with pytest.raises(ValueError):
        export_weights.write(weights, tmp_path / "bad.json")


def test_forward_gives_eleven_logits_and_a_valid_reading():
    weights = _random_weights(1)
    pic = raster.rasterize([[(0.2, 0.1), (0.8, 0.9)]], 300, 400)
    logits = model.forward(weights, pic[None])
    assert logits.shape == (1, 11)
    reading = model.read(weights, pic)
    assert 0 <= reading["digit"] <= 9 and 0.1 <= reading["confidence"] <= 1.0
    assert isinstance(reading["mirrored"], bool)


@needs_torch
def test_numpy_forward_matches_pytorch():
    import torch
    net = model.build_torch_model()
    weights = model.torch_weights(net)
    pics = np.random.default_rng(2).random((5, 28, 28)).astype(np.float32)
    with torch.no_grad():
        expected = net(torch.from_numpy(pics)[:, None]).numpy()
    assert np.allclose(model.forward(weights, pics), expected, atol=1e-4)


@needs_torch
def test_the_network_is_small():
    net = model.build_torch_model()
    params = sum(p.numel() for p in net.parameters())
    assert params < 100_000  # under 400 KB as float32; the plan allows 1 MB


@needs_torch
@needs_mnist
def test_the_shipped_network_clears_the_ci_bar_on_mnist():
    if not export_weights.DEFAULT_PATH.exists():
        pytest.skip("no trained network yet")
    weights, _ = export_weights.read()
    (_, _), (x_test, y_test) = dataset.load_mnist(download=False)
    digits = model.forward(weights, x_test[:2000])[:, :10].argmax(axis=1)
    assert (digits == y_test[:2000]).mean() >= 0.95


def test_the_shipped_weights_file_is_a_valid_digit_net():
    if not export_weights.DEFAULT_PATH.exists():
        pytest.skip("no trained network yet")
    weights, doc = export_weights.read()
    assert set(weights) == set(model.LAYER_NAMES)
    assert export_weights.DEFAULT_PATH.stat().st_size < 700_000
    assert doc["trained"]["data"].endswith("no private digits")
