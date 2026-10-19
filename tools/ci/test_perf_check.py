"""pytest: the static performance checks catch what they claim to, and the repository passes."""
from __future__ import annotations

from pathlib import Path

import perf_check as perf


def make_tree(tmp_path: Path, files: dict[str, str | bytes]) -> Path:
    for relative, content in files.items():
        path = tmp_path / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        if isinstance(content, bytes):
            path.write_bytes(content)
        else:
            path.write_text(content, encoding="utf-8")
    return tmp_path


def test_the_repository_passes() -> None:
    assert perf.main(["--root", str(perf.ROOT)]) == 0


def test_allocations_in_process_are_found() -> None:
    source = (
        "func _ready() -> void:\n"
        "\tvar fine: Array = []\n"
        "\n"
        "func _process(delta: float) -> void:\n"
        "\tposition.x += delta\n"
        "\tvar points := PackedVector2Array()\n"
        "\tvar label := \"%d\" % frame # formats a string every frame\n"
        "\tvar node := Node.new()\n"
        "\n"
        "func after() -> void:\n"
        "\tvar also_fine: Dictionary = {}\n"
    )
    assert [number for number, _ in perf.hot_path_allocations(source)] == [6, 7, 8]


def test_physics_process_counts_and_comments_do_not() -> None:
    source = "func _physics_process(_delta: float) -> void:\n\t# var x = []\n\tvar y := []\n"
    assert [number for number, _ in perf.hot_path_allocations(source)] == [3]


def test_a_draw_function_is_not_a_hot_path(tmp_path: Path) -> None:
    root = make_tree(tmp_path, {"scenes/a.gd": "func _draw() -> void:\n\tvar p := PackedVector2Array()\n"})
    assert perf.check_hot_paths(root) == []


# Rule 1b (peer review 02, section 4.5): a _draw that a tweened property's setter redraws.
TWEENED_ART = (
    "class_name Art\n"
    "extends Control\n"
    "\n"
    "var glow: float = 0.0:\n"
    "\tset(value):\n"
    "\t\tglow = value\n"
    "\t\tqueue_redraw()\n"
    "\n"
    "func _draw() -> void:\n"
    "\tvar box := StyleBoxFlat.new()\n"
    "\tdraw_colored_polygon(PackedVector2Array([Vector2.ZERO, size, Vector2(0, size.y)]), Color.WHITE)\n"
    "\tdraw_circle(size * 0.5, 4.0, Color(1, 1, 1, glow))\n"
)
TWEENER = "func light(art: Art) -> void:\n\tcreate_tween().tween_property(art, \"glow\", 1.0, 0.4)\n"


def test_a_draw_redrawn_by_a_tweened_setter_must_not_allocate(tmp_path: Path) -> None:
    root = make_tree(tmp_path, {"scenes/art.gd": TWEENED_ART, "scenes/host.gd": TWEENER})
    errors = perf.check_hot_paths(root)
    assert [error.split(":")[1] for error in errors] == ["10", "11"]
    assert all("tweened setter" in error for error in errors)


def test_a_redrawing_setter_nobody_tweens_may_allocate_in_draw(tmp_path: Path) -> None:
    root = make_tree(tmp_path, {"scenes/art.gd": TWEENED_ART, "scenes/host.gd": "func light(art: Art) -> void:\n\tart.glow = 1.0\n"})
    assert perf.check_hot_paths(root) == []


def test_a_named_setter_counts_too() -> None:
    source = (
        "@export var tilt: float = 0.0: set = _set_tilt\n"
        "\n"
        "func _set_tilt(value: float) -> void:\n"
        "\ttilt = value\n"
        "\tqueue_redraw()\n"
    )
    assert perf.redrawing_setters(source) == {"tilt"}
    assert perf.redrawing_setters("var tilt: float = 0.0:\n\tset(value):\n\t\ttilt = value\n") == set()


def test_tweened_properties_are_read_from_tween_property_calls() -> None:
    sources = ['tween.tween_property(self, "glow", 1.0, 0.2)', 'fade.tween_property(_rect, "color:a", 0.0, 1.0)']
    assert perf.tweened_properties(sources) == {"glow", "color"}


def test_a_member_array_filled_in_place_passes() -> None:
    source = TWEENED_ART.replace(
        "\tvar box := StyleBoxFlat.new()\n\tdraw_colored_polygon(PackedVector2Array([Vector2.ZERO, size, Vector2(0, size.y)]), Color.WHITE)\n",
        "\t_tri[1] = size\n\tdraw_colored_polygon(_tri, Color.WHITE)\n",
    )
    assert perf.draw_path_allocations(source, {"glow"}) == []


def test_audio_must_be_ogg(tmp_path: Path) -> None:
    root = make_tree(tmp_path, {"assets/sfx/a.ogg": b"x", "assets/sfx/b.wav": b"x"})
    assert perf.check_audio_format(root) == ["assets/sfx/b.wav: audio must be OGG"]


def test_the_budget_counts_only_exported_files(tmp_path: Path) -> None:
    root = make_tree(tmp_path, {
        "export_presets.cfg": 'exclude_filter="tools/*, *.md"\n',
        "assets/big.bin": b"x" * 2048,
        "tools/huge.bin": b"x" * 100_000,
        "notes.md": b"x" * 100_000,
        "build/game.apk": b"x" * 100_000,
    })
    assert perf.shipped_bytes(root) == 2048 + len('exclude_filter="tools/*, *.md"\n')
    assert perf.check_content_budget(root, budget_mb=0.001) == ["exported files are 0.0 MB, over the 0 MB content budget"]
    assert perf.check_content_budget(root) == []
