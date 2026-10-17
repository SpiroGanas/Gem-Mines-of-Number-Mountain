"""pytest: the shared structure checks for the visuals and input meta added for Zones 2 and 3
(balance, array, groups, pairs, ten-frame second color, number-line jumps, tile boards, the array
builder and word labels). Values are written by hand; none come from the GDScript generators."""
from __future__ import annotations

import pytest
from checkers import common


@pytest.mark.parametrize("visual", [
    {"type": "balance", "left": [3, 4], "right": [5, 2], "tilt": "level"},
    {"type": "balance", "left": [9], "right": [4, 4], "tilt": "left"},
    {"type": "balance", "left": [3, 4], "right": [8], "tilt": "right"},
    {"type": "balance", "left": [3, 4], "right": [8], "tilt": "unknown"},
    {"type": "array", "rows": 3, "cols": 4},
    {"type": "groups", "groups": 2, "size": 5},
    {"type": "pairs", "count": 7, "show_pairs": True},
    {"type": "ten_frame", "count": 8, "second": 5, "frames": 2},
    {"type": "number_line", "min": 0, "max": 20, "labeled_every": 5, "markers": [], "blanks": [], "jumps": [{"from": 8, "to": 13}]},
])
def test_well_formed_visuals_pass(visual: dict) -> None:
    assert common.check_visual(visual, "v") == []


@pytest.mark.parametrize("visual", [
    {"type": "balance", "left": [3, 4], "right": [5, 2], "tilt": "left"},   # 7 = 7 is level
    {"type": "balance", "left": [], "right": [5], "tilt": "unknown"},
    {"type": "balance", "left": [3, -1], "right": [2], "tilt": "unknown"},
    {"type": "balance", "left": [3], "right": [3], "tilt": "sideways"},
    {"type": "array", "rows": 0, "cols": 4},
    {"type": "array", "rows": 3, "cols": 11},
    {"type": "groups", "groups": 2, "size": 0},
    {"type": "pairs", "count": 41},
    {"type": "ten_frame", "count": 8, "second": 5, "frames": 1},
    {"type": "number_line", "min": 0, "max": 20, "labeled_every": 5, "markers": [], "blanks": [], "jumps": [{"from": 18, "to": 23}]},
])
def test_broken_visuals_are_caught(visual: dict) -> None:
    assert common.check_visual(visual, "v") != []


def _problem(answer, distractors, meta) -> dict:
    return {"answer": answer, "distractors": [{"value": v, "misconception": "x"} for v in distractors], "meta": meta}


def test_a_tile_board_answer_must_use_tiles_on_the_board() -> None:
    meta = {"tile_board": {"tiles": [61, 62, 63, 64], "slots": 2, "ordered": True}}
    assert common.check_input_meta(_problem([61, 63], [[62, 64]], meta)) == []
    assert common.check_input_meta(_problem([61, 65], [], meta)) != []      # no 65 tile
    assert common.check_input_meta(_problem([61], [], meta)) != []          # wrong slot count


def test_an_unordered_tile_answer_is_kept_sorted() -> None:
    meta = {"tile_board": {"tiles": ["3 + 5 = 8", "5 + 3 = 8", "8 - 3 = 5", "8 - 5 = 3", "3 - 8 = 5"], "slots": 4, "ordered": False}}
    good = sorted(["3 + 5 = 8", "5 + 3 = 8", "8 - 3 = 5", "8 - 5 = 3"])
    assert common.check_input_meta(_problem(good, [], meta)) == []
    assert common.check_input_meta(_problem(list(reversed(good)), [], meta)) != []


def test_tiles_may_not_repeat_and_must_fit_the_screen() -> None:
    assert common.check_input_meta(_problem([1, 1], [], {"tile_board": {"tiles": [1, 1], "slots": 2}})) != []
    assert common.check_input_meta(_problem([1, 2], [], {"tile_board": {"tiles": list(range(1, 10)), "slots": 2}})) != []


def test_array_builder_answers_fit_the_builder() -> None:
    meta = {"array_builder": {"max_rows": 5, "max_cols": 5}}
    assert common.check_input_meta(_problem({"rows": 3, "cols": 4}, [{"rows": 4, "cols": 3}], meta)) == []
    assert common.check_input_meta(_problem({"rows": 6, "cols": 4}, [], meta)) != []


def test_word_labels_cover_every_option() -> None:
    meta = {"label_lines": {"true": "ui.answer.true", "false": "ui.answer.false"}}
    assert common.check_input_meta(_problem(True, [False], meta)) == []
    assert common.check_input_meta(_problem("even", ["odd"], meta)) != []
    assert common.label_key(True) == "true" and common.label_key(12) == "12"
