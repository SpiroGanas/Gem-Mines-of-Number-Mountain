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
