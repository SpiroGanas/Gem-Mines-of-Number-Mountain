"""Independent re-derivation of the FactFamilyGenerator problems (skills eq.fact_family.build and
eq.inverse.check).

Every fact is a string such as "8 - 3 = 5". This module parses each one and does the arithmetic
itself. The family is found by trying every order of the three numbers with + and -, and a
fact "checks" another when it is a true fact of the same three numbers that uses the other
operation.
"""
from __future__ import annotations

import itertools
import re

from .common import sort_key

# Exactly "x + y = z" or "x - y = z": ASCII hyphen-minus, one space around each sign.
_FACT = re.compile(r"(\d+) ([+-]) (\d+) = (\d+)")
_OTHER = {"+": "-", "-": "+"}
Fact = tuple[int, str, int, int]


def parse(value: object) -> Fact | None:
    """(x, op, y, z) for a fact string written exactly as the game shows it, else None."""
    if not isinstance(value, str):
        return None
    match = _FACT.fullmatch(value)
    if match is None:
        return None
    return int(match.group(1)), match.group(2), int(match.group(3)), int(match.group(4))


def holds(fact: Fact) -> bool:
    x, op, y, z = fact
    return (x + y if op == "+" else x - y) == z


def text(x: int, op: str, y: int, z: int) -> str:
    return f"{x} {op} {y} = {z}"


def family_of(numbers: tuple[int, int, int]) -> set[str]:
    """Every true fact that uses each of the three numbers once."""
    return {text(x, op, y, z) for x, y, z in itertools.permutations(numbers) for op in "+-" if holds((x, op, y, z))}


def classify(tile: str, family: set[str]) -> str | None:
    """Which named mistake a false tile is, judged by what one change turns it into."""
    fact = parse(tile)
    if fact is None or holds(fact):
        return None
    x, op, y, z = fact
    if op == "-" and text(y, op, x, z) in family:
        return "swapped_minuend"  # a part minus the whole: swapping the two numbers fixes it
    if text(x, _OTHER[op], y, z) in family:
        return "wrong_operation"  # the other sign fixes it
    return None


def repaired(tile: str, kind: str) -> str:
    x, op, y, z = parse(tile)  # type: ignore[misc]
    return text(y, op, x, z) if kind == "swapped_minuend" else text(x, _OTHER[op], y, z)


def numbers(fact: Fact) -> list[int]:
    """The three numbers a fact uses, smallest first."""
    return sorted((fact[0], fact[2], fact[3]))


def checks(option: Fact, shown: Fact) -> bool:
    """True when `option` checks `shown` with the inverse operation."""
    return option[1] != shown[1] and holds(option) and numbers(option) == numbers(shown)


def check(problem: dict) -> list[str]:
    mode = problem["params"]["mode"]
    handler = {"build": _build, "inverse_check": _inverse_check}.get(mode)
    if handler is None:
        return [f"unknown fact family mode {mode!r}"]
    return handler(problem)


def _three_numbers(problem: dict) -> tuple[list[str], int, int, int]:
    errors: list[str] = []
    params = problem["prompt_params"]
    if set(params) != {"a", "b", "c"}:
        errors.append(f"prompt params should be a, b and c, got {sorted(params)}")
    a, b, c = params["a"], params["b"], params["c"]
    if a < 1 or b < 1 or a == b:
        errors.append(f"the parts {a} and {b} must be two different numbers of at least 1")
    if c != a + b:
        errors.append(f"{a} and {b} make {a + b}, not {c}")
    if c > problem["params"]["max"]:
        errors.append(f"the whole {c} is over the skill's max {problem['params']['max']}")
    if problem["visual"]:
        errors.append("an abstract fact problem draws no picture")
    return errors, a, b, c


def _build(problem: dict) -> list[str]:
    errors, a, b, c = _three_numbers(problem)
    if problem["prompt_line_id"] != "z2.eq.prompt_fact_family":
        errors.append("the prompt line should be z2.eq.prompt_fact_family")
    family = family_of((a, b, c))
    answer = problem["answer"]
    if not isinstance(answer, list) or len(answer) != 4 or set(answer) != family:
        errors.append(f"the answer should be the four facts {sorted(family)}, got {answer!r}")
    elif answer != sorted(answer, key=sort_key):
        errors.append("the fact family answer is not kept sorted")

    board = problem["meta"].get("tile_board")
    if not isinstance(board, dict):
        return errors + ["a fact family needs a tile board"]
    if board.get("slots") != 4 or board.get("ordered") is not False:
        errors.append("the tile board should have 4 unordered slots")
    tiles = board.get("tiles", [])
    for tile in tiles:
        if parse(tile) is None:
            errors.append(f"tile {tile!r} is not a fact in the exact format 'x + y = z'")
    if errors:
        return errors
    if len(tiles) != 6 or len(set(tiles)) != 6:
        errors.append(f"the board should hold 6 different tiles, got {tiles!r}")
    true_tiles = {tile for tile in tiles if holds(parse(tile))}  # type: ignore[arg-type]
    if true_tiles != family:
        errors.append(f"the true tiles {sorted(true_tiles)} should be exactly the family {sorted(family)}")
    kinds = {tile: classify(tile, family) for tile in tiles if tile not in family}
    if sorted(map(str, kinds.values())) != ["swapped_minuend", "wrong_operation"]:
        errors.append(f"the two wrong tiles should be one swapped_minuend and one wrong_operation, got {kinds}")

    names = sorted(entry["misconception"] for entry in problem["distractors"])
    if names != ["swapped_minuend", "wrong_operation"]:
        errors.append(f"the wrong answers should be named swapped_minuend and wrong_operation, got {names}")
    for entry in problem["distractors"]:
        value = entry["value"]
        if not isinstance(value, list) or len(value) != 4:
            errors.append(f"wrong answer {value!r} should be four facts")
            continue
        if value != sorted(value, key=sort_key):
            errors.append(f"wrong answer {value!r} is not kept sorted")
        extra = [item for item in value if item not in family]
        missing = sorted(family - set(value))
        if len(extra) != 1 or len(missing) != 1:
            errors.append(f"wrong answer {value!r} should swap exactly one true fact for a wrong tile")
            continue
        kind = kinds.get(extra[0])
        if kind != entry["misconception"]:
            errors.append(f"{extra[0]!r} is a {kind} tile, but the wrong answer is named {entry['misconception']}")
        elif repaired(extra[0], kind) != missing[0]:
            errors.append(f"{extra[0]!r} should stand where {repaired(extra[0], kind)!r} belongs, not {missing[0]!r}")

    model = problem["hint_steps"][1]["visual"]
    if model != {"type": "ten_frame", "count": a, "second": b, "frames": 2}:
        errors.append(f"the hint should show {a} and {b} in two ten-frames, got {model}")
    example = problem["hint_steps"][2]["example"]
    shown = example["prompt_params"]
    example_family = family_of((shown["a"], shown["b"], shown["c"]))
    if shown["a"] + shown["b"] != shown["c"] or example["answer"] != sorted(example_family, key=sort_key):
        errors.append("the worked example is not a correct fact family")
    listed = str(example["answer_params"].get("list", "")).split("; ")
    if example["answer_line_id"] != "z2.hint.example_family" or len(listed) != 4 or set(listed) != example_family:
        errors.append(f"the worked example should list its four facts, got {example['answer_params']}")
    return errors


def _inverse_check(problem: dict) -> list[str]:
    errors, a, b, c = _three_numbers(problem)
    line = problem["prompt_line_id"]
    shown = _shown(line, a, b, c)
    if shown is None:
        return errors + [f"unknown inverse-check prompt {line!r}"]
    # The check undoes the fact: start from its result, use the other sign with the same number.
    undo = text(shown[3], _OTHER[shown[1]], shown[2], shown[0])
    if problem["answer"] != undo:
        errors.append(f"{text(*shown)!r} is undone by {undo!r}, not {problem['answer']!r}")
    options = [problem["answer"]] + [entry["value"] for entry in problem["distractors"]]
    for option in options:
        fact = parse(option)
        if fact is None:
            errors.append(f"option {option!r} is not a fact in the exact format 'x + y = z'")
        elif not holds(fact):
            errors.append(f"option {option!r} is not a true fact (every button shows a true fact)")
        elif option == text(*shown):
            errors.append(f"option {option!r} is the shown fact itself")
    if errors:
        return errors
    checking = [option for option in options if checks(parse(option), shown)]  # type: ignore[arg-type]
    if checking != [problem["answer"]]:
        errors.append(f"exactly one option may check {text(*shown)!r}; these do: {checking}")
    if any(entry["misconception"] != "wrong_operation" for entry in problem["distractors"]):
        errors.append("every wrong option is named wrong_operation")
    turned = text(b, "+", a, c) if shown[1] == "+" else text(c, "-", a, b)  # same sign, other fact of the family
    added_again = text(c, "+", b, c + b)  # adds b to the whole
    if sorted(entry["value"] for entry in problem["distractors"]) != sorted([turned, added_again]):
        errors.append(f"the wrong options should be {turned!r} and {added_again!r}")

    model = problem["hint_steps"][1]["visual"]
    jump = {"from": c, "to": a} if shown[1] == "+" else {"from": a, "to": c}  # take b away again, or add it back
    if model.get("type") != "number_line" or model.get("jumps") != [jump] or not {a, c} <= set(model.get("markers", [])):
        errors.append(f"the hint should jump {jump} on a number line marking {a} and {c}, got {model}")
    example = problem["hint_steps"][2]["example"]
    shown_example = _shown(example["prompt_line_id"], example["prompt_params"]["a"], example["prompt_params"]["b"], example["prompt_params"]["c"])
    if shown_example is None or example["answer"] != text(shown_example[3], _OTHER[shown_example[1]], shown_example[2], shown_example[0]):
        errors.append("the worked example's answer does not undo its fact")
    if example["answer_line_id"] != "z2.hint.example_check" or example["answer_params"].get("fact") != example["answer"]:
        errors.append(f"the worked example should state its answer fact, got {example['answer_params']}")
    return errors


def _shown(line: str, a: int, b: int, c: int) -> Fact | None:
    """The fact the prompt shows: a + b = c, or c - b = a."""
    if line == "z2.eq.prompt_inverse_add":
        return a, "+", b, c
    if line == "z2.eq.prompt_inverse_sub":
        return c, "-", b, a
    return None
